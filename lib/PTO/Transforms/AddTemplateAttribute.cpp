// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under
// the terms and conditions of CANN Open Software License Agreement Version 2.0
// (the "License"). Please refer to the License for details. You may not use
// this file except in compliance with the License. THIS SOFTWARE IS PROVIDED ON
// AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS
// FOR A PARTICULAR PURPOSE. See LICENSE in the root of the software repository
// for the full text of the License.

#include "PTO/IR/PTO.h"
#include "PTO/Transforms/Passes.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/Vector/IR/VectorOps.h"
#include "mlir/Pass/Pass.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Program.h"

#include <cstdlib>
#include <unistd.h>

extern "C" {
extern char **environ;
}

namespace mlir {
namespace pto {
namespace func = ::mlir::func;
#define GEN_PASS_DEF_PTOADDTEMPLATEATTRIBUTEPASS
#include "PTO/Transforms/Passes.h.inc"
} // namespace pto
} // namespace mlir

using namespace mlir;

namespace {

// ============================================================================
// OperandTypeInfo: describes one operand for template specialization.
//
// Four kinds of operands:
//   Tile   — from TileBufType.  dtype + shape + memorySpace + config
//            all participate in the specialization key (SpecKey).
//   View   — from MemRefType (lowered PartitionTensorViewType). Only dtype
//            participates in SpecKey — the template is fully dynamic so
//            shape/strides/memorySpace don't affect code generation. They are
//            carried here solely for JSON serialization to the Python DSL for
//            constraint checking.
//   Vector — from builtin VectorType. The element dtype and vector shape
//            participate in SpecKey so helper-side schema filtering can
//            distinguish auxiliary vector operands such as tmrgsort's
//            `excuted : vector<4xi16>`.
//   Scalar — from a scalar element type.  Only dtype participates in SpecKey.
// ============================================================================
enum class OperandKind { Tile, View, Vector, Scalar };

struct TileLibMetadataResult {
  std::string jsonText;
};

struct TileLibCandidateChoice {
  std::string name;
  int64_t priority = 0;
  int64_t loopDepth = -1;
};

struct TemplateAttribute {
  int64_t id;
  int64_t loop_depth;
  std::string vf_impl_kind;
  std::string tail;
};

struct OperandTypeInfo {
  OperandKind kind = OperandKind::Tile;
  std::string dtype; // all kinds: element type string (e.g. "f32")

  // --- Tile-only (TileBufType) ---
  SmallVector<int64_t, 2> tileShape;
  SmallVector<int64_t, 2> tileValidShape;
  std::string
      tileMemorySpace; // e.g. "ub", "gm", "mat", "left", "right", "acc", "bias"
  int32_t blayout = 0;
  int32_t slayout = 0;
  int32_t fractal = 0;
  uint64_t pad = 0;

  // --- View-only (MemRefType) — for JSON / constraint checking only ---
  SmallVector<int64_t> viewShape;
  SmallVector<int64_t> viewStrides;
  std::string viewMemorySpace; // "gm" or "ub"

  // --- Vector-only (builtin VectorType) ---
  SmallVector<int64_t> vectorShape;

  // --- Scalar-only ---
  std::optional<int64_t> scalarValue;

  /// Equality for SpecKey caching — only compares fields relevant to each kind.
  bool operator==(const OperandTypeInfo &rhs) const {
    if (kind != rhs.kind || dtype != rhs.dtype)
      return false;
    if (kind == OperandKind::Tile)
      return tileShape == rhs.tileShape &&
             tileValidShape == rhs.tileValidShape &&
             tileMemorySpace == rhs.tileMemorySpace && blayout == rhs.blayout &&
             slayout == rhs.slayout && fractal == rhs.fractal && pad == rhs.pad;
    if (kind == OperandKind::Vector)
      return vectorShape == rhs.vectorShape;
    if (kind == OperandKind::Scalar)
      return scalarValue == rhs.scalarValue;
    // View: dtype alone is sufficient for template caching.
    return true;
  }
};

struct SpecKey {
  std::string opName;
  std::string targetArch;
  SmallVector<OperandTypeInfo, 4> operands;
  SmallVector<std::pair<std::string, std::string>, 4> contextAttrs;

  bool operator==(const SpecKey &rhs) const {
    return opName == rhs.opName && targetArch == rhs.targetArch &&
           operands == rhs.operands && contextAttrs == rhs.contextAttrs;
  }
};

static constexpr llvm::StringLiteral kTileLibMetadataAttr =
    "pto.tilelib.metadata";
static constexpr llvm::StringLiteral kTileLibSelectedTemplateAttr =
    "pto.tilelib.selected_template";

static std::string getDtypeString(Type elemTy) {
  if (elemTy.isIndex())
    return "i32";
  if (elemTy.isInteger(1))
    return "i1";
  if (elemTy.isF32())
    return "f32";
  if (elemTy.isF16())
    return "f16";
  if (elemTy.isBF16())
    return "bf16";
  if (elemTy.isFloat8E4M3FN())
    return "f8e4m3";
  if (elemTy.isFloat8E5M2())
    return "f8e5m2";
  if (isa<pto::HiF8Type>(elemTy))
    return "hif8";
  if (isa<pto::F4E1M2x2Type>(elemTy))
    return "f4e1m2x2";
  if (isa<pto::F4E2M1x2Type>(elemTy))
    return "f4e2m1x2";
  if (elemTy.isUnsignedInteger(64))
    return "ui64";
  if (elemTy.isUnsignedInteger(32))
    return "ui32";
  if (elemTy.isUnsignedInteger(16))
    return "ui16";
  if (elemTy.isUnsignedInteger(8))
    return "ui8";
  if (elemTy.isSignedInteger(64))
    return "si64";
  if (elemTy.isSignedInteger(32))
    return "si32";
  if (elemTy.isSignedInteger(16))
    return "si16";
  if (elemTy.isSignedInteger(8))
    return "si8";
  if (elemTy.isSignlessInteger(64))
    return "i64";
  if (elemTy.isSignlessInteger(32))
    return "i32";
  if (elemTy.isSignlessInteger(16))
    return "i16";
  if (elemTy.isSignlessInteger(8))
    return "i8";
  return "";
}

static StringRef getTileOpName(Operation *op) {
  return op->getName().stripDialect();
}

static std::string getTargetArchString(ModuleOp mod) {
  if (!mod)
    return "";
  auto targetAttr = mod->getAttrOfType<StringAttr>("pto.target_arch");
  if (!targetAttr)
    return "";
  return targetAttr.getValue().str();
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

static std::string getMemorySpaceString(pto::TileBufType tbTy) {
  auto msAttr = dyn_cast_or_null<pto::AddressSpaceAttr>(tbTy.getMemorySpace());
  return msAttr ? stringifyMemorySpace(msAttr.getAddressSpace()) : "ub";
}

static std::string getMemorySpaceString(MemRefType mrTy) {
  auto msAttr = dyn_cast_or_null<pto::AddressSpaceAttr>(mrTy.getMemorySpace());
  return msAttr ? stringifyMemorySpace(msAttr.getAddressSpace()) : "gm";
}

static std::string getBLayoutString(int32_t blayout) {
  if (blayout == static_cast<int32_t>(pto::BLayout::ColMajor))
    return "col_major";
  return "row_major";
}

static std::string getSLayoutString(int32_t slayout) {
  if (slayout == static_cast<int32_t>(pto::SLayout::RowMajor))
    return "row_major";
  if (slayout == static_cast<int32_t>(pto::SLayout::ColMajor))
    return "col_major";
  return "none_box";
}

static bool getStaticIntFromValue(Value value, int64_t &out) {
  if (auto cOp = value.getDefiningOp<arith::ConstantIndexOp>()) {
    out = cOp.value();
    return true;
  }
  if (auto cInt = value.getDefiningOp<arith::ConstantIntOp>()) {
    out = cInt.value();
    return true;
  }
  return false;
}

static int64_t getStaticIntOrDynamic(OpFoldResult ofr) {
  if (auto attr = ofr.dyn_cast<Attribute>()) {
    if (auto intAttr = dyn_cast<IntegerAttr>(attr))
      return intAttr.getInt();
    return ShapedType::kDynamic;
  }
  auto value = llvm::cast<Value>(ofr);
  int64_t result = ShapedType::kDynamic;
  if (getStaticIntFromValue(value, result))
    return result;
  return ShapedType::kDynamic;
}

static void recordStaticSizes(ArrayRef<OpFoldResult> inputs,
                              SmallVectorImpl<int64_t> &out) {
  out.clear();
  out.reserve(inputs.size());
  for (OpFoldResult ofr : inputs)
    out.push_back(getStaticIntOrDynamic(ofr));
}

static SmallVector<int64_t>
combineSubviewStrides(ArrayRef<int64_t> baseStrides,
                      ArrayRef<OpFoldResult> steps) {
  SmallVector<int64_t> result;
  result.reserve(baseStrides.size());
  for (auto [baseStride, step] : llvm::zip(baseStrides, steps)) {
    int64_t stepValue = getStaticIntOrDynamic(step);
    if (baseStride == ShapedType::kDynamic ||
        stepValue == ShapedType::kDynamic) {
      result.push_back(ShapedType::kDynamic);
      continue;
    }
    result.push_back(baseStride * stepValue);
  }
  return result;
}

static void populateViewShapeAndStrides(Value value,
                                        SmallVectorImpl<int64_t> &shape,
                                        SmallVectorImpl<int64_t> &strides) {
  if (!value)
    return;

  if (auto subview = value.getDefiningOp<memref::SubViewOp>()) {
    populateViewShapeAndStrides(subview.getSource(), shape, strides);
    SmallVector<int64_t> subviewShape;
    recordStaticSizes(subview.getMixedSizes(), subviewShape);
    if (!subviewShape.empty())
      shape = subviewShape;
    if (!strides.empty())
      strides = combineSubviewStrides(strides, subview.getMixedStrides());
    return;
  }

  if (auto reinterpret = value.getDefiningOp<memref::ReinterpretCastOp>()) {
    if (shape.empty()) {
      SmallVector<int64_t> reinterpretShape;
      recordStaticSizes(reinterpret.getMixedSizes(), reinterpretShape);
      if (!reinterpretShape.empty())
        shape = reinterpretShape;
    }
    if (strides.empty())
      recordStaticSizes(reinterpret.getMixedStrides(), strides);
    return;
  }

  if (auto cast = value.getDefiningOp<memref::CastOp>()) {
    populateViewShapeAndStrides(cast.getSource(), shape, strides);
    return;
  }

  if (auto memrefTy = dyn_cast<MemRefType>(value.getType())) {
    if (shape.empty())
      shape.assign(memrefTy.getShape().begin(), memrefTy.getShape().end());
    if (strides.empty()) {
      int64_t offset = ShapedType::kDynamic;
      (void)getStridesAndOffset(memrefTy, strides, offset);
    }
  }
}

static std::optional<OperandTypeInfo> buildOperandTypeInfo(Value value) {
  Type ty = value.getType();
  if (auto tbTy = dyn_cast<pto::TileBufType>(ty)) {
    OperandTypeInfo info;
    info.kind = OperandKind::Tile;
    info.dtype = getDtypeString(tbTy.getElementType());
    if (info.dtype.empty())
      return std::nullopt;
    info.tileShape.assign(tbTy.getShape().begin(), tbTy.getShape().end());
    auto validShape = tbTy.getValidShape();
    if (validShape.empty())
      info.tileValidShape.assign(tbTy.getShape().begin(),
                                 tbTy.getShape().end());
    else
      info.tileValidShape.assign(validShape.begin(), validShape.end());
    info.tileMemorySpace = getMemorySpaceString(tbTy);
    if (auto config = tbTy.getConfigAttr()) {
      info.blayout = static_cast<int32_t>(config.getBLayout().getValue());
      info.slayout = static_cast<int32_t>(config.getSLayout().getValue());
      info.fractal =
          config.getSFractalSize()
              ? static_cast<int32_t>(config.getSFractalSize().getInt())
              : 0;
      info.pad = static_cast<uint64_t>(config.getPad().getValue());
    }
    return info;
  }

  if (auto mrTy = dyn_cast<MemRefType>(ty)) {
    OperandTypeInfo info;
    info.kind = OperandKind::View;
    info.dtype = getDtypeString(mrTy.getElementType());
    if (info.dtype.empty())
      return std::nullopt;
    info.viewMemorySpace = getMemorySpaceString(mrTy);
    populateViewShapeAndStrides(value, info.viewShape, info.viewStrides);
    if (info.viewShape.empty())
      info.viewShape.assign(mrTy.getShape().begin(), mrTy.getShape().end());
    if (info.viewStrides.empty()) {
      int64_t offset = ShapedType::kDynamic;
      (void)getStridesAndOffset(mrTy, info.viewStrides, offset);
    }
    return info;
  }

  if (auto vecTy = dyn_cast<VectorType>(ty)) {
    OperandTypeInfo info;
    info.kind = OperandKind::Vector;
    info.dtype = getDtypeString(vecTy.getElementType());
    if (info.dtype.empty())
      return std::nullopt;
    info.vectorShape.assign(vecTy.getShape().begin(), vecTy.getShape().end());
    return info;
  }

  OperandTypeInfo info;
  info.kind = OperandKind::Scalar;
  info.dtype = getDtypeString(ty);
  if (info.dtype.empty())
    return std::nullopt;
  int64_t scalarValue = 0;
  if (getStaticIntFromValue(value, scalarValue))
    info.scalarValue = scalarValue;
  return info;
}

static void appendOpContextAttrs(
    Operation *op,
    SmallVectorImpl<std::pair<std::string, std::string>> &attrs) {
  (void)op;
  (void)attrs;
}

static std::optional<SpecKey> buildSpecKey(Operation *op) {
  SpecKey key;
  key.opName = getTileOpName(op).str();
  key.targetArch = getTargetArchString(op->getParentOfType<ModuleOp>());

  for (unsigned i = 0; i < op->getNumOperands(); ++i) {
    auto info = buildOperandTypeInfo(op->getOperand(i));
    if (!info)
      return std::nullopt;
    key.operands.push_back(*info);
  }
  if (key.operands.empty())
    return std::nullopt;

  appendOpContextAttrs(op, key.contextAttrs);
  return key;
}

static void appendJsonIntArray(std::string &json, ArrayRef<int64_t> arr) {
  json += "[";
  for (size_t i = 0; i < arr.size(); ++i) {
    if (i > 0)
      json += ",";
    json += std::to_string(arr[i]);
  }
  json += "]";
}

static void appendJsonDimArray(std::string &json, ArrayRef<int64_t> arr,
                               bool negativeIsDynamic = false) {
  json += "[";
  for (size_t i = 0; i < arr.size(); ++i) {
    if (i > 0)
      json += ",";
    int64_t dim = arr[i];
    if (ShapedType::isDynamic(dim) || (negativeIsDynamic && dim < 0)) {
      json += "null";
      continue;
    }
    json += std::to_string(dim);
  }
  json += "]";
}

struct ExpandState {
  std::vector<OwningOpRef<ModuleOp>> parsedModules; // Keep parsed modules alive

  std::string tilelangPath;
  std::string tilelangPkgPath;
  std::string pythonExe;
  std::string daemonSocketPath;
  std::string daemonHelperModule = "tilelang_dsl.daemon_helper";
  bool enableTileLibMetadata = false;

  func::FuncOp invokeTilelangDSL(const SpecKey &key, Operation *tileOp,
                                 ModuleOp mod, MLIRContext *ctx,
                                 StringRef candidateId = {});
  func::FuncOp invokeTilelangDaemon(const SpecKey &key, Operation *tileOp,
                                    ModuleOp mod, MLIRContext *ctx,
                                    StringRef candidateId = {});
  std::optional<TileLibMetadataResult> invokeTileLibMetadata(const SpecKey &key,
                                                             Operation *tileOp);

  LogicalResult expandTileOpsInFunction(func::FuncOp func, ModuleOp mod,
                                        MLIRContext *ctx);
};

static std::string buildOperandSpecsJson(const SpecKey &key) {
  std::string json = "[";
  for (size_t i = 0; i < key.operands.size(); ++i) {
    const auto &op = key.operands[i];
    if (i > 0)
      json += ",";

    if (op.kind == OperandKind::Tile) {
      json += "{\"kind\":\"tile\",\"dtype\":\"" + op.dtype + "\",\"shape\":";
      appendJsonIntArray(json, op.tileShape);
      json += ",\"valid_shape\":";
      appendJsonDimArray(json, op.tileValidShape, /*negativeIsDynamic=*/true);
      json += ",\"memory_space\":\"";
      json += op.tileMemorySpace;
      json += "\",\"config\":{";
      json += "\"b_layout\":\"";
      json += getBLayoutString(op.blayout);
      json += "\",\"s_layout\":\"";
      json += getSLayoutString(op.slayout);
      json += "\",\"s_fractal_size\":";
      json += std::to_string(op.fractal);
      json += ",\"pad_value\":\"0x";
      json += llvm::utohexstr(op.pad, /*LowerCase=*/false);
      json += "\"}}";
      continue;
    }

    if (op.kind == OperandKind::View) {
      json += "{\"kind\":\"view\",\"dtype\":\"" + op.dtype + "\",\"shape\":";
      appendJsonDimArray(json, op.viewShape);
      if (!op.viewStrides.empty()) {
        json += ",\"strides\":[";
        for (size_t dim = 0; dim < op.viewStrides.size(); ++dim) {
          if (dim > 0)
            json += ",";
          if (ShapedType::isDynamic(op.viewStrides[dim]))
            json += "null";
          else
            json += std::to_string(op.viewStrides[dim]);
        }
        json += "]";
      }
      json += ",\"memory_space\":\"" + op.viewMemorySpace + "\"}";
      continue;
    }

    if (op.kind == OperandKind::Vector) {
      json += "{\"kind\":\"vector\",\"dtype\":\"" + op.dtype + "\",\"shape\":";
      appendJsonIntArray(json, op.vectorShape);
      json += "}";
      continue;
    }

    // Scalar
    json += "{\"kind\":\"scalar\",\"dtype\":\"" + op.dtype + "\"";
    if (op.scalarValue) {
      json += ",\"value\":";
      json += std::to_string(*op.scalarValue);
    }
    json += "}";
  }
  json += "]";
  return json;
}

static std::string buildContextAttrsJson(const SpecKey &key) {
  std::string json = "{";
  for (size_t i = 0; i < key.contextAttrs.size(); ++i) {
    const auto &[attrName, attrValue] = key.contextAttrs[i];
    if (i > 0)
      json += ",";
    json += "\"";
    json += attrName;
    json += "\":\"";
    json += attrValue;
    json += "\"";
  }
  json += "}";
  return json;
}

static LogicalResult addAttribute(StringRef metadataJson, Operation *op,
                                  MLIRContext *ctx) {
  auto parsed = llvm::json::parse(metadataJson);
  if (!parsed) {
    llvm::errs() << "ExpandTileOp: failed to parse TileLib metadata JSON\n";
    llvm::consumeError(parsed.takeError());
    return failure();
  }

  llvm::json::Object *root = parsed->getAsObject();
  if (!root) {
    llvm::errs()
        << "ExpandTileOp: TileLib metadata response is not a JSON object\n";
    return failure();
  }

  llvm::json::Object *candidates = root->getObject("candidates");
  if (!candidates || candidates->empty()) {
    llvm::errs()
        << "ExpandTileOp: TileLib metadata response has no legal candidates\n";
    return failure();
  }

  // Generate attributes
  int64_t id = 0;
  SmallVector<Attribute> versions;
  for (const auto &entry : *candidates) {
    StringRef implKind;
    StringRef tail;
    StringRef candidateName = entry.getFirst();
    if (candidateName.empty())
      continue;

    const llvm::json::Object *candidateMetadata =
        entry.getSecond().getAsObject();
    if (!candidateMetadata) {
      llvm::errs() << "ExpandTileOp: TileLib candidate metadata for "
                   << candidateName << " is not a JSON object\n";
      return failure();
    }
    std::optional<int64_t> loopDepth =
        candidateMetadata->getInteger("loop_depth");
    if (!loopDepth) {
      op->emitError("ExpandTileOp: TileLib candidate metadata for ")
          << candidateName << " has no loop_depth integer";
      return failure();
    }

    std::optional<bool> postUpdate =
        candidateMetadata->getBoolean("is_post_update");
    if (!postUpdate) {
      op->emitError("ExpandTileOp: TileLib candidate metadata for ")
          << candidateName << " has no is_post_update boolean";
      return failure();
    }

    if (*postUpdate)
      implKind = "PostUpdate";
    else
      implKind = "NoPostUpdate";
    if (*loopDepth == 2 && *postUpdate)
      tail = "has_tail";
    else
      tail = "no_tail";

    // Function to make version
    auto makeVersion = [&](StringRef candidateName, int64_t id,
                           int64_t loopDepth, StringRef implKind,
                           StringRef tail) {
      return DictionaryAttr::get(
          ctx,
          {
              NamedAttribute(StringAttr::get(ctx, "name"),
                             StringAttr::get(ctx, candidateName)),
              NamedAttribute(StringAttr::get(ctx, "id"),
                             IntegerAttr::get(IntegerType::get(ctx, 64), id)),
              NamedAttribute(
                  StringAttr::get(ctx, "loop_depth"),
                  IntegerAttr::get(IntegerType::get(ctx, 64), loopDepth)),
              NamedAttribute(StringAttr::get(ctx, "vf_impl_kind"),
                             StringAttr::get(ctx, implKind)),
              NamedAttribute(StringAttr::get(ctx, "tail"),
                             StringAttr::get(ctx, tail)),
          });
    };
    id++;
    versions.push_back(
        makeVersion(candidateName, id, *loopDepth, implKind, tail));
  }
  op->setAttr("versions", ArrayAttr::get(ctx, versions));
  return success();
}
// ============================================================================
// Invoke PTODSL TileLib metadata RPC.
// ============================================================================
std::optional<TileLibMetadataResult>
ExpandState::invokeTileLibMetadata(const SpecKey &key, Operation *tileOp) {
  (void)tileOp;
  if (daemonSocketPath.empty()) {
    llvm::errs() << "ExpandTileOp: TileLib metadata requires daemon mode\n";
    return std::nullopt;
  }

  auto pythonPath = llvm::sys::findProgramByName(pythonExe);
  if (!pythonPath) {
    llvm::errs() << "ExpandTileOp: cannot find '" << pythonExe << "'\n";
    return std::nullopt;
  }

  std::string operandSpecsJson = buildOperandSpecsJson(key);
  std::string contextAttrsJson = buildContextAttrsJson(key);
  if (key.targetArch.empty()) {
    llvm::errs() << "ExpandTileOp: missing pto.target_arch module attribute\n";
    return std::nullopt;
  }

  SmallString<128> tmpPath;
  int tmpFD;
  if (auto ec = llvm::sys::fs::createTemporaryFile("tilelib_metadata", "json",
                                                   tmpFD, tmpPath)) {
    llvm::errs() << "ExpandTileOp: cannot create temp file: " << ec.message()
                 << "\n";
    return std::nullopt;
  }
  ::close(tmpFD);

  std::string opName = "pto." + key.opName;
  SmallVector<StringRef> args = {
      *pythonPath,      "-m",           daemonHelperModule,
      "--method",       "get_metadata", "--socket",
      daemonSocketPath, "--target",     key.targetArch,
      "--op",           opName,         "--operand-specs",
      operandSpecsJson,
  };
  if (!key.contextAttrs.empty()) {
    args.push_back("--context-attrs");
    args.push_back(contextAttrsJson);
  }

  std::optional<StringRef> redirects[] = {std::nullopt, StringRef(tmpPath),
                                          std::nullopt};

  SmallVector<StringRef> envp;
  std::string pythonPathEnv;
  std::vector<std::string> envStorage;
  bool hasPythonPath = !tilelangPkgPath.empty();
  if (hasPythonPath) {
    const char *existingPath = ::getenv("PYTHONPATH");
    pythonPathEnv = "PYTHONPATH=" + tilelangPkgPath;
    if (existingPath && existingPath[0] != '\0') {
      pythonPathEnv += ":";
      pythonPathEnv += existingPath;
    }
    for (char **e = environ; *e; ++e) {
      StringRef entry(*e);
      if (entry.starts_with("PYTHONPATH="))
        continue;
      envStorage.push_back(std::string(entry));
    }
    envStorage.push_back(pythonPathEnv);
    for (auto &s : envStorage)
      envp.push_back(s);
  }

  std::string errMsg;
  int rc = llvm::sys::ExecuteAndWait(
      *pythonPath, args,
      hasPythonPath ? std::optional<ArrayRef<StringRef>>(envp) : std::nullopt,
      redirects, /*secondsToWait=*/30, /*memoryLimit=*/0, &errMsg);

  if (rc != 0) {
    llvm::errs() << "ExpandTileOp: TileLib metadata helper failed (rc=" << rc
                 << "): " << errMsg << "\n";
    llvm::sys::fs::remove(tmpPath);
    return std::nullopt;
  }

  auto bufOrErr = llvm::MemoryBuffer::getFile(tmpPath);
  llvm::sys::fs::remove(tmpPath);
  if (!bufOrErr) {
    llvm::errs() << "ExpandTileOp: cannot read TileLib metadata output\n";
    return std::nullopt;
  }

  std::string metadataJson = (*bufOrErr)->getBuffer().str();
  if (metadataJson.empty()) {
    llvm::errs() << "ExpandTileOp: empty TileLib metadata output\n";
    return std::nullopt;
  }

  return TileLibMetadataResult{std::move(metadataJson)};
}

// ============================================================================
// Get a legal template in a single function
// ============================================================================
LogicalResult ExpandState::expandTileOpsInFunction(func::FuncOp func,
                                                   ModuleOp mod,
                                                   MLIRContext *ctx) {
  OpBuilder builder(ctx);

  // Collect tile ops first (avoid modifying while iterating).
  SmallVector<Operation *, 16> tileOps;
  func.walk([&](Operation *op) {
    if (isa<pto::TReshapeOp>(op))
      return;
    if (isa<pto::OpPipeInterface>(op))
      tileOps.push_back(op);
  });

  if (enableTileLibMetadata) {
    if (daemonSocketPath.empty()) {
      func.emitError("ExpandTileOp: TileLib metadata is enabled, but daemon "
                     "mode is unavailable");
      return failure();
    }

    // Phase 1: ask PTODSL for legal candidate metadata for every TileOp.
    for (auto *op : tileOps) {
      auto specKeyOpt = buildSpecKey(op);
      if (!specKeyOpt) {
        op->emitError("ExpandTileOp: cannot build specialization key for this "
                      "operand schema");
        return failure();
      }

      std::optional<TileLibMetadataResult> metadata =
          invokeTileLibMetadata(*specKeyOpt, op);
      if (!metadata) {
        StringRef opName = getTileOpName(op);
        op->emitError("ExpandTileOp: failed to query TileLib metadata for " +
                      opName);
        return failure();
      }
      if (failed(addAttribute(metadata->jsonText, op, ctx)))
        return failure();
    }

    // for (auto *op : tileOps) {
    //   auto metadataAttr =
    //   op->getAttrOfType<StringAttr>(kTileLibMetadataAttr); if (!metadataAttr)
    //   {
    //     op->emitError("ExpandTileOp: missing TileLib metadata for version
    //     selection"); return failure();
    //   }

    //   std::optional<std::string> selectedCandidate =
    //       selectCandidateFromMetadata(metadataAttr.getValue());
    //   if (!selectedCandidate) {
    //     StringRef opName = getTileOpName(op);
    //     op->emitError("ExpandTileOp: failed to select TileLib candidate for "
    //     +
    //                   opName);
    //     return failure();
    //   }

    //   op->setAttr(kTileLibSelectedTemplateAttr,
    //               StringAttr::get(ctx, *selectedCandidate));
    // }
  }

  return success();
}

struct PTOAddTemplateAttributePass
    : public mlir::pto::impl::PTOAddTemplateAttributePassBase<
          PTOAddTemplateAttributePass> {
  using PTOAddTemplateAttributePassBase::PTOAddTemplateAttributePassBase;

  unsigned templateID = 0;

  void runOnOperation() override;
};

// ============================================================================
// Main entry point.
// ============================================================================
void PTOAddTemplateAttributePass::runOnOperation() {
  ModuleOp module = getOperation();
  ExpandState state;
  state.tilelangPath = tilelangPath;
  state.tilelangPkgPath = tilelangPkgPath;
  state.pythonExe = pythonExe;
  state.daemonSocketPath = daemonSocketPath;
  state.daemonHelperModule = daemonHelperModule;
  state.enableTileLibMetadata = enableTileLibMetadata;

  MLIRContext *ctx = module.getContext();
  for (auto func : module.getOps<func::FuncOp>()) {
    if (failed(state.expandTileOpsInFunction(func, module, ctx))) {
      signalPassFailure();
      return;
    }
  }
}

} // namespace

std::unique_ptr<Pass> mlir::pto::createPTOAddTemplateAttributePass() {
  return std::make_unique<PTOAddTemplateAttributePass>();
}

std::unique_ptr<Pass> mlir::pto::createPTOAddTemplateAttributePass(
    const PTOAddTemplateAttributePassOptions &options) {
  return std::make_unique<PTOAddTemplateAttributePass>(options);
}
