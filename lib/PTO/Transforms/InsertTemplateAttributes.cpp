// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under the terms and conditions of
// CANN Open Software License Agreement Version 2.0 (the "License").
// Please refer to the License for details. You may not use this file except in compliance with the License.
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
// See LICENSE in the root of the software repository for the full text of the License.

#include "PTO/IR/PTO.h"
#include "PTO/Transforms/Passes.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/Pass.h"

#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Program.h"
#include "llvm/Support/raw_ostream.h"

#include <cstdlib>
#include <optional>
#include <string>
#include <unistd.h>
#include <vector>

extern "C" {
extern char **environ;
}

using namespace mlir;

namespace mlir {
namespace pto {
#define GEN_PASS_DEF_INSERTTEMPLATEATTRIBUTES
#include "PTO/Transforms/Passes.h.inc"
} // namespace pto
} // namespace mlir

namespace {

constexpr llvm::StringLiteral kCandidatesAttr = "candidates";

struct CandidateMetadata {
  int64_t id;
  std::string name;
  int64_t loopDepth;
  bool postUpdate;
  bool tail;
};

static std::string getDtypeString(Type elementType) {
  if (elementType.isF32())
    return "f32";
  if (elementType.isF16())
    return "f16";
  if (elementType.isBF16())
    return "bf16";
  if (elementType.isSignlessInteger(32))
    return "i32";
  if (elementType.isSignlessInteger(16))
    return "i16";
  if (elementType.isSignlessInteger(8))
    return "i8";
  return "";
}

static std::string stringifyMemorySpace(pto::AddressSpace space) {
  switch (space) {
  case pto::AddressSpace::GM:
    return "gm";
  case pto::AddressSpace::MAT:
    return "mat";
  case pto::AddressSpace::LEFT:
    return "left";
  case pto::AddressSpace::RIGHT:
    return "right";
  case pto::AddressSpace::ACC:
    return "acc";
  case pto::AddressSpace::BIAS:
    return "bias";
  case pto::AddressSpace::SCALING:
    return "scaling";
  case pto::AddressSpace::VEC:
  case pto::AddressSpace::Zero:
    return "ub";
  }
  return "ub";
}

static std::string getMemorySpaceString(pto::TileBufType tileType) {
  auto memorySpace =
      dyn_cast_or_null<pto::AddressSpaceAttr>(tileType.getMemorySpace());
  return memorySpace ? stringifyMemorySpace(memorySpace.getAddressSpace())
                     : "ub";
}

static StringRef getBLayoutString(pto::BLayout layout) {
  return layout == pto::BLayout::ColMajor ? "col_major" : "row_major";
}

static StringRef getSLayoutString(pto::SLayout layout) {
  if (layout == pto::SLayout::RowMajor)
    return "row_major";
  if (layout == pto::SLayout::ColMajor)
    return "col_major";
  return "none_box";
}

static void appendJsonIntArray(std::string &json, ArrayRef<int64_t> values) {
  json += "[";
  for (auto [index, value] : llvm::enumerate(values)) {
    if (index != 0)
      json += ",";
    json += std::to_string(value);
  }
  json += "]";
}

static std::optional<std::string>
buildOperandSpecsJson(Operation *operation) {
  std::string json = "[";
  for (auto [index, operand] : llvm::enumerate(operation->getOperands())) {
    auto tileType = dyn_cast<pto::TileBufType>(operand.getType());
    if (!tileType) {
      operation->emitError(
          "InsertTemplateAttributes currently supports only tile operands");
      return std::nullopt;
    }

    std::string dtype = getDtypeString(tileType.getElementType());
    if (dtype.empty()) {
      operation->emitError(
          "InsertTemplateAttributes encountered an unsupported tile dtype");
      return std::nullopt;
    }

    if (index != 0)
      json += ",";
    json += "{\"kind\":\"tile\",\"dtype\":\"" + dtype + "\",\"shape\":";
    appendJsonIntArray(json, tileType.getShape());
    json += ",\"valid_shape\":";
    auto validShape = tileType.getValidShape();
    appendJsonIntArray(json,
                       validShape.empty() ? tileType.getShape() : validShape);
    json += ",\"memory_space\":\"";
    json += getMemorySpaceString(tileType);
    json += "\",\"config\":{";

    pto::BLayout bLayout = pto::BLayout::RowMajor;
    pto::SLayout sLayout = pto::SLayout::NoneBox;
    int64_t fractalSize = 0;
    uint64_t padValue = 0;
    if (auto config = tileType.getConfigAttr()) {
      bLayout = config.getBLayout().getValue();
      sLayout = config.getSLayout().getValue();
      if (config.getSFractalSize())
        fractalSize = config.getSFractalSize().getInt();
      padValue = static_cast<uint64_t>(config.getPad().getValue());
    }

    json += "\"b_layout\":\"";
    json += getBLayoutString(bLayout);
    json += "\",\"s_layout\":\"";
    json += getSLayoutString(sLayout);
    json += "\",\"s_fractal_size\":";
    json += std::to_string(fractalSize);
    json += ",\"pad_value\":\"0x";
    json += llvm::utohexstr(padValue, /*LowerCase=*/false);
    json += "\"}}";
  }
  json += "]";
  return json;
}

static std::optional<std::string>
getTargetArch(Operation *operation) {
  auto module = operation->getParentOfType<ModuleOp>();
  if (!module) {
    operation->emitError(
        "InsertTemplateAttributes requires a parent module");
    return std::nullopt;
  }
  auto target = module->getAttrOfType<StringAttr>("pto.target_arch");
  if (!target) {
    operation->emitError(
        "InsertTemplateAttributes requires pto.target_arch");
    return std::nullopt;
  }
  return target.getValue().str();
}

static std::optional<std::string>
invokeMetadataHelper(Operation *operation, StringRef pythonExe,
                     StringRef daemonSocketPath, StringRef tileLibPkgPath,
                     StringRef daemonHelperModule) {
  auto pythonPath = llvm::sys::findProgramByName(pythonExe);
  if (!pythonPath) {
    operation->emitError("InsertTemplateAttributes cannot find Python '")
        << pythonExe << "'";
    return std::nullopt;
  }

  auto target = getTargetArch(operation);
  auto operandSpecs = buildOperandSpecsJson(operation);
  if (!target || !operandSpecs)
    return std::nullopt;

  llvm::SmallString<128> outputPath;
  int outputFd;
  if (auto error = llvm::sys::fs::createTemporaryFile(
          "tilelib_metadata", "json", outputFd, outputPath)) {
    operation->emitError("InsertTemplateAttributes cannot create temporary "
                         "metadata output: ")
        << error.message();
    return std::nullopt;
  }
  ::close(outputFd);

  std::string opName = operation->getName().getStringRef().str();
  SmallVector<StringRef> args = {
      *pythonPath,       "-m",            daemonHelperModule,
      "--method",        "get_metadata",  "--socket",
      daemonSocketPath,  "--target",      *target,
      "--op",            opName,          "--operand-specs",
      *operandSpecs,
  };

  std::optional<StringRef> redirects[] = {
      std::nullopt,
      StringRef(outputPath),
      std::nullopt,
  };

  SmallVector<StringRef> environment;
  std::string pythonPathEnvironment;
  std::vector<std::string> environmentStorage;
  bool hasPythonPath = !tileLibPkgPath.empty();
  if (hasPythonPath) {
    const char *existingPath = ::getenv("PYTHONPATH");
    pythonPathEnvironment = "PYTHONPATH=" + tileLibPkgPath.str();
    if (existingPath && existingPath[0] != '\0')
      pythonPathEnvironment += ":" + std::string(existingPath);

    for (char **entry = environ; *entry; ++entry) {
      StringRef value(*entry);
      if (!value.starts_with("PYTHONPATH="))
        environmentStorage.push_back(value.str());
    }
    environmentStorage.push_back(pythonPathEnvironment);
    for (std::string &value : environmentStorage)
      environment.push_back(value);
  }

  std::string errorMessage;
  int result = llvm::sys::ExecuteAndWait(
      *pythonPath, args,
      hasPythonPath
          ? std::optional<llvm::ArrayRef<StringRef>>(environment)
          : std::nullopt,
      redirects, /*secondsToWait=*/30, /*memoryLimit=*/0, &errorMessage);
  if (result != 0) {
    llvm::sys::fs::remove(outputPath);
    operation->emitError("InsertTemplateAttributes metadata RPC failed: ")
        << errorMessage;
    return std::nullopt;
  }

  auto output = llvm::MemoryBuffer::getFile(outputPath);
  llvm::sys::fs::remove(outputPath);
  if (!output) {
    operation->emitError(
        "InsertTemplateAttributes cannot read metadata output");
    return std::nullopt;
  }
  return (*output)->getBuffer().str();
}

static FailureOr<ArrayAttr>
parseCandidateAttributes(Operation *operation, StringRef metadataJson) {
  auto parsed = llvm::json::parse(metadataJson);
  if (!parsed) {
    llvm::consumeError(parsed.takeError());
    operation->emitError(
        "InsertTemplateAttributes received invalid metadata JSON");
    return failure();
  }

  auto *root = parsed->getAsObject();
  auto *candidates = root ? root->getObject("candidates") : nullptr;
  if (!candidates || candidates->empty()) {
    operation->emitError(
        "InsertTemplateAttributes found no legal template candidates");
    return failure();
  }

  SmallVector<CandidateMetadata> parsedCandidates;
  parsedCandidates.reserve(candidates->size());
  for (const auto &entry : *candidates) {
    auto *metadata = entry.second.getAsObject();
    if (!metadata) {
      operation->emitError(
          "InsertTemplateAttributes candidate metadata must be an object");
      return failure();
    }

    auto name = metadata->getString("name");
    auto id = metadata->getInteger("id");
    auto loopDepth = metadata->getInteger("loop_depth");
    auto postUpdate = metadata->getBoolean("is_post_update");
    auto tail = metadata->getBoolean("has_tail");
    if (!name || !loopDepth || !postUpdate || !tail) {
      operation->emitError(
          "InsertTemplateAttributes candidate metadata is missing name, "
          "loop_depth, is_post_update, or has_tail");
      return failure();
    }
    if (!id && candidates->size() != 1) {
      operation->emitError(
          "InsertTemplateAttributes requires an id for every "
          "multi-candidate template");
      return failure();
    }

    parsedCandidates.push_back(CandidateMetadata{
        id.value_or(0),
        name->str(),
        *loopDepth,
        *postUpdate,
        *tail,
    });
  }

  llvm::sort(parsedCandidates,
             [](const CandidateMetadata &left,
                const CandidateMetadata &right) {
               if (left.id != right.id)
                 return left.id < right.id;
               return left.name < right.name;
             });
  for (auto [index, candidate] : llvm::enumerate(parsedCandidates)) {
    if (index != 0 && candidate.id == parsedCandidates[index - 1].id) {
      operation->emitError(
          "InsertTemplateAttributes candidate ids must be unique");
      return failure();
    }
  }

  Builder builder(operation->getContext());
  SmallVector<Attribute> attributes;
  attributes.reserve(parsedCandidates.size());
  for (const CandidateMetadata &candidate : parsedCandidates) {
    attributes.push_back(DictionaryAttr::get(
        operation->getContext(),
        {
            builder.getNamedAttr("id", builder.getI64IntegerAttr(candidate.id)),
            builder.getNamedAttr("name",
                                 builder.getStringAttr(candidate.name)),
            builder.getNamedAttr(
                "loop_depth",
                builder.getI64IntegerAttr(candidate.loopDepth)),
            builder.getNamedAttr(
                "postupdate",
                builder.getI64IntegerAttr(candidate.postUpdate ? 1 : 0)),
            builder.getNamedAttr(
                "tail", builder.getI64IntegerAttr(candidate.tail ? 1 : 0)),
        }));
  }
  return builder.getArrayAttr(attributes);
}

struct InsertTemplateAttributesPass
    : public pto::impl::InsertTemplateAttributesBase<
          InsertTemplateAttributesPass> {
  using InsertTemplateAttributesBase::InsertTemplateAttributesBase;

  void runOnOperation() override {
    ModuleOp module = getOperation();
    if (daemonSocketPath.empty()) {
      module.emitError(
          "InsertTemplateAttributes requires a PTODSL daemon socket");
      return signalPassFailure();
    }

    SmallVector<Operation *> tileOperations;
    module.walk([&](Operation *operation) {
      if (isa<pto::TReshapeOp>(operation))
        return;
      if (isa<pto::OpPipeInterface>(operation))
        tileOperations.push_back(operation);
    });

    for (Operation *operation : tileOperations) {
      auto metadata = invokeMetadataHelper(
          operation, pythonExe, daemonSocketPath, tileLibPkgPath,
          daemonHelperModule);
      if (!metadata)
        return signalPassFailure();

      auto candidates = parseCandidateAttributes(operation, *metadata);
      if (failed(candidates))
        return signalPassFailure();
      operation->setAttr(kCandidatesAttr, *candidates);
    }
  }
};

} // namespace

namespace mlir {
namespace pto {

std::unique_ptr<Pass> createInsertTemplateAttributesPass() {
  return std::make_unique<InsertTemplateAttributesPass>();
}

std::unique_ptr<Pass> createInsertTemplateAttributesPass(
    const InsertTemplateAttributesOptions &options) {
  return std::make_unique<InsertTemplateAttributesPass>(options);
}

} // namespace pto
} // namespace mlir
