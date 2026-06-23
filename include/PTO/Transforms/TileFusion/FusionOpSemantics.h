// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under
// the terms and conditions of CANN Open Software License Agreement Version 2.0
// (the "License"). Please refer to the License for details. You may not use
// this file except in compliance with the License. THIS SOFTWARE IS PROVIDED ON
// AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS
// FOR A PARTICULAR PURPOSE. See LICENSE in the root of the software repository
// for the full text of the License.

#ifndef PTO_TRANSFORMS_TILEFUSION_FUSIONOPSEMANTICS_H
#define PTO_TRANSFORMS_TILEFUSION_FUSIONOPSEMANTICS_H

#include "PTO/IR/PTO.h"

#include "mlir/Support/LLVM.h"

#include <string>

namespace mlir {
namespace pto {

enum class FusionOpKind {
  Compute,
  LocalBoundary,
  HardBoundary,
};

enum class FusionComputeFamily {
  Unknown,
  Elementwise,
  ScalarExpand,
  RowBroadcastBinary,
  ReduceRow,
  ReduceCol,
};

enum class FusionVFImplKind {
  PostUpdate,
  NoPostUpdate,
  // more implementation related fields can be added later
};

enum class FusionTailKind {
  HasTail,
  NoTail,
};

struct FusionTileOpVersions {
  unsigned id;
  std::string name;
  unsigned loopDepth;
  FusionVFImplKind vfImplKind;
  FusionTailKind tailKind;
};

struct FusionOpSemantics {
  FusionOpKind kind = FusionOpKind::HardBoundary;
  FusionComputeFamily computeFamily = FusionComputeFamily::Unknown;
  Operation *op = nullptr;
  std::string opName;
  SmallVector<Value, 4> tileInputs;
  SmallVector<Value, 2> tileOutputs;
  SmallVector<Value, 2> scalarInputs;
  SmallVector<FusionTileOpVersions, 2> versions;
};

bool isSupportedPreFusionComputeOp(StringRef opName);
FailureOr<SmallVector<FusionTileOpVersions>>
getFusionTileOpVersions(Operation *op);
FailureOr<FusionOpSemantics> getFusionOpSemantics(Operation *op);

} // namespace pto
} // namespace mlir

#endif // PTO_TRANSFORMS_TILEFUSION_FUSIONOPSEMANTICS_H
