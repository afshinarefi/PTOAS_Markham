# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""TileLib template metadata + tile specialization specs.

``TemplateMetadata`` carries both the *hard constraints* used to decide whether a
template is legal for a concrete TileOp (op/target/dtypes/layouts/memory_spaces) and the
*selection hints* used to rank legal candidates (priority/fusible/tags).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .._types import (
    float16 as _float16,
    float32 as _float32,
    int8 as _int8,
    int16 as _int16,
    int32 as _int32,
    int64 as _int64,
    si8 as _si8,
    si16 as _si16,
    si32 as _si32,
    tile_buf_type as _tile_buf_type,
    ui8 as _ui8,
    ui16 as _ui16,
    ui32 as _ui32,
    _resolve,
)

from mlir.ir import Type


@dataclass(frozen=True)
class ScalarType:
    """Author-facing dtype tag (used to build entry tile_buf types at specialize time)."""

    name: str

    def __repr__(self) -> str:
        return self.name


f32 = ScalarType("f32")
f16 = ScalarType("f16")
bf16 = ScalarType("bf16")
i32 = ScalarType("i32")
i64 = ScalarType("i64")
i16 = ScalarType("i16")
i8 = ScalarType("i8")
si32 = ScalarType("si32")
si16 = ScalarType("si16")
si8 = ScalarType("si8")
ui32 = ScalarType("ui32")
ui16 = ScalarType("ui16")
ui8 = ScalarType("ui8")


def scalar_descriptor(dtype: ScalarType):
    """Map a TileLib ``ScalarType`` to a ptodsl ``_types`` dtype descriptor."""
    descriptors = {
        "f32": _float32,
        "f16": _float16,
        "bf16": Type.parse("bf16"),
        "i8": _int8,
        "i16": _int16,
        "i32": _int32,
        "i64": _int64,
        "si8": _si8,
        "si16": _si16,
        "si32": _si32,
        "ui8": _ui8,
        "ui16": _ui16,
        "ui32": _ui32,
    }
    descriptor = descriptors.get(dtype.name)
    if descriptor is None:
        raise ValueError(f"unsupported scalar dtype {dtype.name}")
    return descriptor


@dataclass(frozen=True)
class ScalarSpec:
    """Concrete specialization of one scalar operand."""

    dtype: ScalarType
    value: int | float | None = None

    def mlir_type(self):
        return _resolve(scalar_descriptor(self.dtype))


@dataclass(frozen=True)
class TileSpec:
    """Concrete specialization of one tile operand.

    Shape, layout, fractal size, and standard padding are preserved in the rendered
    ``tile_buf`` type as well as exposed to legality constraints.
    """

    shape: tuple
    dtype: ScalarType
    memory_space: str = "ub"
    valid_shape: tuple | None = None
    b_layout: str = "row_major"
    s_layout: str = "none_box"
    s_fractal_size: int = 512
    pad_value: str = "0x0"

    def __post_init__(self):
        if len(self.shape) != 2:
            raise ValueError("TileSpec currently only supports rank-2 tile shapes")
        if any(not isinstance(dim, int) or dim <= 0 for dim in self.shape):
            raise ValueError("TileSpec.shape must contain positive integers")
        if self.memory_space != "ub":
            raise ValueError("TileSpec currently only supports ub tiles")

    def mlir_type(self):
        rows, cols = self.shape
        blayout = {
            "row_major": "RowMajor",
            "col_major": "ColMajor",
        }.get(self.b_layout)
        slayout = {
            "none_box": "NoneBox",
            "row_major": "RowMajor",
            "col_major": "ColMajor",
        }.get(self.s_layout)
        pad = {
            "0x0": "Null",
            "0x1": "Zero",
            "0x2": "Max",
            "0x3": "Min",
        }.get(str(self.pad_value).lower())
        if blayout is None or slayout is None:
            raise ValueError(
                f"unsupported tile layout b_layout={self.b_layout!r}, s_layout={self.s_layout!r}"
            )
        if pad is None:
            raise ValueError(f"unsupported tile pad value {self.pad_value!r}")
        return _tile_buf_type(
            [rows, cols],
            scalar_descriptor(self.dtype),
            list(self.valid_shape) if self.valid_shape else [rows, cols],
            blayout=blayout,
            address_space=self.memory_space,
            slayout=slayout,
            fractal_size=self.s_fractal_size,
            pad=pad,
        )


@dataclass(frozen=True)
class TemplateMetadata:
    """Hard constraints + selection hints for one registered template version."""

    op: str
    target: str
    name: str
    # Hard constraints
    dtypes: tuple = ()          # tuple of per-operand dtype-name tuples, e.g. (("f32","f32","f32"),)
    layouts: tuple = ()
    memory_spaces: tuple = ()
    # Hard constraints (legality predicates: callables matched by param name — see constraints.py)
    constraints: tuple = ()
    # Selection hints
    priority: int = 0
    fusible: bool = False
    loop_depth: int | None = None
    id: int | None = None
    Tail: object = None
    is_post_update: bool = False
    tags: tuple = ()

    @staticmethod
    def build(*, op, target, name, dtypes=(), layouts=(), memory_spaces=(),
              constraints=(), priority=0, fusible=False, loop_depth=None,
              id=None, Tail=None, is_post_update=False, tags=()):
        return TemplateMetadata(
            op=op,
            target=target,
            name=name,
            dtypes=tuple(tuple(sig) for sig in dtypes),
            layouts=tuple(layouts),
            memory_spaces=tuple(memory_spaces),
            constraints=tuple(constraints),
            priority=priority,
            fusible=fusible,
            loop_depth=loop_depth,
            id=id,
            Tail=Tail,
            is_post_update=bool(is_post_update),
            tags=tuple(tags),
        )


__all__ = [
    "ScalarType",
    "ScalarSpec",
    "TileSpec",
    "TemplateMetadata",
    "scalar_descriptor",
    "f32",
    "f16",
    "bf16",
    "i32",
    "i64",
    "i16",
    "i8",
    "si32",
    "si16",
    "si8",
    "ui32",
    "ui16",
    "ui8",
]
