// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under the terms and conditions of
// CANN Open Software License Agreement Version 2.0 (the "License").
// Please refer to the License for details. You may not use this file except in compliance with the License.
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
// See LICENSE in the root of the software repository for the full text of the License.

#ifndef MLIR_DIALECT_PTO_TRANSFORMS_TEMPLATEATTRIBUTES_H
#define MLIR_DIALECT_PTO_TRANSFORMS_TEMPLATEATTRIBUTES_H

#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Operation.h"
#include "mlir/Support/LogicalResult.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"

#include <cstdint>
#include <string>

namespace mlir {
class MLIRContext;

namespace pto {

inline constexpr llvm::StringLiteral kTemplateCandidatesAttr = "candidates";
inline constexpr llvm::StringLiteral kTemplateCandidateIdAttr = "id";
inline constexpr llvm::StringLiteral kTemplateCandidateNameAttr = "name";
inline constexpr llvm::StringLiteral kTemplateCandidateLoopDepthAttr =
    "loop_depth";
inline constexpr llvm::StringLiteral kTemplateCandidatePostUpdateAttr =
    "postupdate";
inline constexpr llvm::StringLiteral kTemplateCandidateTailAttr = "tail";

struct TemplateCandidateMetadata {
  int64_t id = 0;
  std::string name;
  int64_t loopDepth = 0;
  bool isPostUpdate = false;
  bool hasTail = false;
};

DictionaryAttr
buildTemplateCandidateAttr(MLIRContext *context,
                           const TemplateCandidateMetadata &candidate);

ArrayAttr buildTemplateCandidateArrayAttr(
    MLIRContext *context, ArrayRef<TemplateCandidateMetadata> candidates);

FailureOr<TemplateCandidateMetadata>
parseTemplateCandidateAttr(DictionaryAttr attr);

FailureOr<SmallVector<TemplateCandidateMetadata, 4>>
getTemplateCandidateAttrs(Operation *operation);

} // namespace pto
} // namespace mlir

#endif // MLIR_DIALECT_PTO_TRANSFORMS_TEMPLATEATTRIBUTES_H
