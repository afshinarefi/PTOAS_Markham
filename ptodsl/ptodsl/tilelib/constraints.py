# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Constraint predicates + evaluation for TileLib version selection.

A template may declare ``constraints=[predicate, ...]`` (legality rules, e.g. "row-major
layout and a 1-row output"). During selection we build a per-operand context and call each
predicate by **name-matching its parameters** against that context — the same introspection
convention as tilelang-dsl's `_evaluate_constraints`, so predicates port verbatim. The
predicate receives keys like ``src_shape`` / ``dst_valid_shape`` / ``src_config`` and returns
a truthy value when legal.

``BLayout`` / ``SLayout`` mirror tilelang's enums so a copied predicate's
``cfg.b_layout != pto.BLayout.ROW_MAJOR`` comparison works unchanged (str enums compare equal
to the raw layout strings carried in operand specs).
"""

from __future__ import annotations

import inspect
from dataclasses import dataclass
from enum import Enum


class BLayout(str, Enum):
    ROW_MAJOR = "row_major"
    COL_MAJOR = "col_major"


class SLayout(str, Enum):
    NONE_BOX = "none_box"
    ROW_MAJOR = "row_major"
    COL_MAJOR = "col_major"


@dataclass(frozen=True)
class _ConfigView:
    """The ``{name}_config`` object a constraint sees (``.b_layout`` / ``.s_layout`` strings,
    which compare equal to the BLayout/SLayout str-enums)."""

    b_layout: str
    s_layout: str


def build_context(tile_specs: dict, target: str, op: str) -> dict:
    """Build the flat name-keyed context predicates are matched against."""
    context: dict = {"target": target, "op": op}
    for name, spec in tile_specs.items():
        shape = tuple(spec.shape)
        valid = tuple(spec.valid_shape) if getattr(spec, "valid_shape", None) else shape
        context[f"{name}_shape"] = shape
        context[f"{name}_valid_shape"] = valid
        context[f"{name}_config"] = _ConfigView(
            b_layout=getattr(spec, "b_layout", "row_major"),
            s_layout=getattr(spec, "s_layout", "none_box"),
        )
        if len(shape) == 2:
            context[f"{name}_rows"], context[f"{name}_cols"] = shape
            context[f"{name}_valid_rows"], context[f"{name}_valid_cols"] = valid
    return context


def passes(predicates, context: dict) -> bool:
    """Return True iff every predicate is satisfied for *context* (legality filter)."""
    for predicate in predicates:
        try:
            signature = inspect.signature(predicate)
        except (TypeError, ValueError):
            return False
        kwargs: dict = {}
        for parameter in signature.parameters.values():
            if parameter.kind == inspect.Parameter.VAR_KEYWORD:
                for key, value in context.items():
                    kwargs.setdefault(key, value)
                continue
            if parameter.kind == inspect.Parameter.VAR_POSITIONAL:
                continue
            if parameter.name in context:
                kwargs[parameter.name] = context[parameter.name]
            elif parameter.default is not inspect.Parameter.empty:
                continue
            else:
                # A required parameter we can't supply -> treat as not satisfiable.
                return False
        try:
            if not predicate(**kwargs):
                return False
        except Exception:
            return False
    return True


__all__ = ["BLayout", "SLayout", "build_context", "passes"]
