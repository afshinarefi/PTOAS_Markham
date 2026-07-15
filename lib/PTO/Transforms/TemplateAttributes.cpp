// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under the terms and conditions of
// CANN Open Software License Agreement Version 2.0 (the "License").
// Please refer to the License for details. You may not use this file except in compliance with the License.
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
// See LICENSE in the root of the software repository for the full text of the License.

#include "PTO/Transforms/TemplateAttributes.h"

#include "mlir/IR/Builders.h"

using namespace mlir;

namespace mlir {
namespace pto {

DictionaryAttr
buildTemplateCandidateAttr(MLIRContext *context,
                           const TemplateCandidateMetadata &candidate) {
  Builder builder(context);
  return DictionaryAttr::get(
      context,
      {
          builder.getNamedAttr(kTemplateCandidateIdAttr,
                               builder.getI64IntegerAttr(candidate.id)),
          builder.getNamedAttr(kTemplateCandidateNameAttr,
                               builder.getStringAttr(candidate.name)),
          builder.getNamedAttr(kTemplateCandidateLoopDepthAttr,
                               builder.getI64IntegerAttr(candidate.loopDepth)),
          builder.getNamedAttr(
              kTemplateCandidatePostUpdateAttr,
              builder.getI64IntegerAttr(candidate.isPostUpdate ? 1 : 0)),
          builder.getNamedAttr(kTemplateCandidateTailAttr,
                               builder.getI64IntegerAttr(candidate.hasTail ? 1
                                                                           : 0)),
      });
}

ArrayAttr buildTemplateCandidateArrayAttr(
    MLIRContext *context, ArrayRef<TemplateCandidateMetadata> candidates) {
  Builder builder(context);
  SmallVector<Attribute> attributes;
  attributes.reserve(candidates.size());
  for (const TemplateCandidateMetadata &candidate : candidates)
    attributes.push_back(buildTemplateCandidateAttr(context, candidate));
  return builder.getArrayAttr(attributes);
}

FailureOr<TemplateCandidateMetadata>
parseTemplateCandidateAttr(DictionaryAttr attr) {
  auto id =
      dyn_cast_or_null<IntegerAttr>(attr.get(kTemplateCandidateIdAttr));
  auto name =
      dyn_cast_or_null<StringAttr>(attr.get(kTemplateCandidateNameAttr));
  auto loopDepth = dyn_cast_or_null<IntegerAttr>(
      attr.get(kTemplateCandidateLoopDepthAttr));
  auto postUpdate = dyn_cast_or_null<IntegerAttr>(
      attr.get(kTemplateCandidatePostUpdateAttr));
  auto tail =
      dyn_cast_or_null<IntegerAttr>(attr.get(kTemplateCandidateTailAttr));

  if (!id || !name || !loopDepth || !postUpdate || !tail)
    return failure();

  return TemplateCandidateMetadata{
      id.getInt(),
      name.getValue().str(),
      loopDepth.getInt(),
      postUpdate.getInt() != 0,
      tail.getInt() != 0,
  };
}

FailureOr<SmallVector<TemplateCandidateMetadata, 4>>
getTemplateCandidateAttrs(Operation *operation) {
  Attribute candidateAttr = operation->getAttr(kTemplateCandidatesAttr);
  if (!candidateAttr)
    return SmallVector<TemplateCandidateMetadata, 4>{};

  auto candidates = dyn_cast<ArrayAttr>(candidateAttr);
  if (!candidates || candidates.empty()) {
    operation->emitError()
        << "expected '" << kTemplateCandidatesAttr
        << "' to be a non-empty array of template candidate dictionaries";
    return failure();
  }

  SmallVector<TemplateCandidateMetadata, 4> parsedCandidates;
  parsedCandidates.reserve(candidates.size());
  for (Attribute attr : candidates) {
    auto dict = dyn_cast<DictionaryAttr>(attr);
    if (!dict) {
      operation->emitError()
          << "expected every entry in '" << kTemplateCandidatesAttr
          << "' to be a template candidate dictionary";
      return failure();
    }

    FailureOr<TemplateCandidateMetadata> candidate =
        parseTemplateCandidateAttr(dict);
    if (failed(candidate)) {
      operation->emitError()
          << "expected every template candidate in '"
          << kTemplateCandidatesAttr << "' to define integer '"
          << kTemplateCandidateIdAttr << "', string '"
          << kTemplateCandidateNameAttr << "', integer '"
          << kTemplateCandidateLoopDepthAttr << "', integer '"
          << kTemplateCandidatePostUpdateAttr << "', and integer '"
          << kTemplateCandidateTailAttr << "' fields";
      return failure();
    }

    parsedCandidates.push_back(std::move(*candidate));
  }
  return parsedCandidates;
}

} // namespace pto
} // namespace mlir
