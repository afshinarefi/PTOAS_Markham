// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under the terms and conditions of
// CANN Open Software License Agreement Version 2.0 (the "License").
// Please refer to the License for details. You may not use this file except in compliance with the License.
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
// See LICENSE in the root of the software repository for the full text of the License.

#include "PTO/Transforms/TileFusion/FusionOpSemantics.h"

#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/StringSwitch.h"

namespace mlir {
namespace pto {

static FusionComputeFamily getFusionComputeFamily(StringRef opName) {
  return llvm::StringSwitch<FusionComputeFamily>(opName)
      .Cases("tadd", "tsub", "tmul", "tdiv", "tmax", "tmin",
             FusionComputeFamily::Elementwise)
      .Cases("tadds", "tsubs", "tmuls", "tdivs", "tmaxs", "tmins",
             FusionComputeFamily::Elementwise)
      .Case("texp", FusionComputeFamily::Elementwise)
      .Case("texpands", FusionComputeFamily::ScalarExpand)
      .Cases("trowexpandmul", "trowexpanddiv",
             FusionComputeFamily::RowBroadcastBinary)
      .Cases("trowsum", "trowmax", "trowmin", FusionComputeFamily::ReduceRow)
      .Cases("tcolsum", "tcolmax", "tcolmin", FusionComputeFamily::ReduceCol)
      .Default(FusionComputeFamily::Unknown);
}

bool isSupportedPreFusionComputeOp(StringRef opName) {
  return getFusionComputeFamily(opName) != FusionComputeFamily::Unknown;
}

static bool isTileFusionTileValue(Value value) {
  return isa<pto::TileBufType>(value.getType());
}

static SmallVector<Value, 2> collectNormalizedTileOutputs(Operation *op) {
  SmallVector<Value, 2> outputs;

  if (auto dpsIface = dyn_cast<pto::PTO_DpsInitOpInterface>(op)) {
    for (Value init : dpsIface.getDpsInits()) {
      if (isTileFusionTileValue(init))
        outputs.push_back(init);
    }
    if (!outputs.empty())
      return outputs;
  }

  for (Value result : op->getResults()) {
    if (isTileFusionTileValue(result))
      outputs.push_back(result);
  }
  return outputs;
}

static StringRef getTileFusionOpName(Operation *op) {
  StringRef opName = op->getName().getStringRef();
  opName.consume_front("pto.");
  return opName;
}

static FailureOr<FusionVFImplKind> parseVFImplKind(StringRef value) {
  return llvm::StringSwitch<FailureOr<FusionVFImplKind>>(value)
      .Case("PostUpdate", FusionVFImplKind::PostUpdate)
      .Case("NoPostUpdate", FusionVFImplKind::NoPostUpdate)
      .Default(failure());
}

static FailureOr<FusionTailKind> parseTailKind(StringRef value) {
  return llvm::StringSwitch<FailureOr<FusionTailKind>>(value)
      .Case("has_tail", FusionTailKind::HasTail)
      .Case("no_tail", FusionTailKind::NoTail)
      .Default(failure());
}

// Parse the canonical implementation metadata:
//   versions = [{id = 1 : i64, loop_depth = 1 : i64,
//                vf_impl_kind = "PostUpdate", tail = "has_tail"}, ...]
static FailureOr<SmallVector<FusionTileOpVersions>>
parseFusionTileOpVersions(Operation *op) {
  Attribute versionsAttr = op->getAttr("versions");
  if (!versionsAttr)
    return SmallVector<FusionTileOpVersions>{};

  auto versions = dyn_cast<ArrayAttr>(versionsAttr);
  if (!versions)
    return failure();

  SmallVector<FusionTileOpVersions> result;
  result.reserve(versions.size());
  llvm::SmallDenseSet<unsigned, 4> ids;

  for (Attribute versionAttr : versions) {
    auto version = dyn_cast<DictionaryAttr>(versionAttr);
    if (!version)
      return failure();

    auto idAttr = version.getAs<IntegerAttr>("id");
    auto depthAttr = version.getAs<IntegerAttr>("loop_depth");
    auto implKindAttr = version.getAs<StringAttr>("vf_impl_kind");
    auto tailAttr = version.getAs<StringAttr>("tail");
    if (!idAttr || !depthAttr || !implKindAttr || !tailAttr ||
        idAttr.getInt() <= 0 || depthAttr.getInt() <= 0)
      return failure();

    unsigned id = static_cast<unsigned>(idAttr.getInt());
    if (!ids.insert(id).second)
      return failure();

    FailureOr<FusionVFImplKind> implKind =
        parseVFImplKind(implKindAttr.getValue());
    FailureOr<FusionTailKind> tailKind = parseTailKind(tailAttr.getValue());
    if (failed(implKind) || failed(tailKind))
      return failure();

    result.push_back({
        id,
        static_cast<unsigned>(depthAttr.getInt()),
        *implKind,
        *tailKind,
    });
  }

  return result;
}

FailureOr<FusionOpSemantics> getFusionOpSemantics(Operation *op) {
  FusionOpSemantics semantics;
  semantics.op = op;
  semantics.opName = getTileFusionOpName(op).str();

  if (auto reshape = dyn_cast<pto::TReshapeOp>(op)) {
    semantics.kind = FusionOpKind::LocalBoundary;
    semantics.opName = "treshape";
    semantics.tileInputs.push_back(reshape.getSrc());
    semantics.tileOutputs.push_back(reshape.getResult());
    return semantics;
  }

  semantics.computeFamily = getFusionComputeFamily(semantics.opName);
  if (semantics.computeFamily == FusionComputeFamily::Unknown) {
    semantics.kind = FusionOpKind::HardBoundary;
    return semantics;
  }

  auto dpsIface = dyn_cast<pto::PTO_DpsInitOpInterface>(op);
  if (!dpsIface && op->getNumResults() == 0) {
    semantics.kind = FusionOpKind::HardBoundary;
    return semantics;
  }

  semantics.kind = FusionOpKind::Compute;
  semantics.tileOutputs = collectNormalizedTileOutputs(op);
  if (semantics.tileOutputs.empty())
    return failure();

  SmallVector<unsigned, 4> dpsInitOperandNumbers;
  if (dpsIface) {
    for (OpOperand &dpsInit : dpsIface.getDpsInitsMutable())
      dpsInitOperandNumbers.push_back(dpsInit.getOperandNumber());
  }

  for (OpOperand &operand : op->getOpOperands()) {
    if (llvm::is_contained(dpsInitOperandNumbers, operand.getOperandNumber()))
      continue;

    Value value = operand.get();
    if (isTileFusionTileValue(value))
      semantics.tileInputs.push_back(value);
    else
      semantics.scalarInputs.push_back(value);
  }

  if (semantics.tileInputs.empty()) {
    for (Value output : semantics.tileOutputs) {
      if (!isa<pto::TileBufType>(output.getType()))
        return failure();
    }
  }

  FailureOr<SmallVector<FusionTileOpVersions>> versions =
      parseFusionTileOpVersions(op);

  if (failed(versions))
    return op->emitError("invalid TileOp implementation metadata");

  semantics.versions = std::move(*versions);

  return semantics;
}

} // namespace pto
} // namespace mlir
