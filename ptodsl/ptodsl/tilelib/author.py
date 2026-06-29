# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Author-facing TileLib body surface.

A template imports this namespace as ``pto`` and writes a tilelang-style body. Control
flow uses the **engine's** AST-rewrite surface (``for x in range(...)`` is rewritten to
``pto.for_(...).carry(...)`` at trace time — see ``_render_runtime`` / ``_ast_rewrite``),
so ``for_``/``static_range``/``if_``/``yield_`` are re-exported from ``_control_flow``
rather than reimplemented. The body ops route to the existing ``_ops`` engine.
"""

from __future__ import annotations

# Engine control-flow surface (target of the AST rewrite).
from .._control_flow import const_expr, for_, if_, static_range, vecscope, yield_
from .._surface_types import (
    BarrierType,
    MaskPattern,
    PostUpdate,
    PredicateDist,
    PredicatePart,
    Tile,
    VStoreDist,
    VcvtPartMode,
    VcvtSatMode,
)
from .._types import mask_type
from .. import _ops
from .._types import _resolve
from .metadata import ScalarType, scalar_descriptor


constexpr = const_expr
mask_b16 = mask_type("b16")
mask_b32 = mask_type("b32")


def _author_dtype(dtype):
    if isinstance(dtype, ScalarType):
        return scalar_descriptor(dtype)
    return dtype


class _PadValue:
    def __init__(self, kind):
        self.kind = kind

    def eval(self, dtype):
        resolved_dtype = _author_dtype(dtype)
        dtype_name = str(_resolve(resolved_dtype))
        limits = {
            "f16": (-65504.0, 65504.0),
            "bf16": (-3.3895313892515355e38, 3.3895313892515355e38),
            "f32": (-3.4028234663852886e38, 3.4028234663852886e38),
            "i8": (-128, 127),
            "i16": (-32768, 32767),
            "i32": (-2147483648, 2147483647),
        }
        if dtype_name not in limits:
            raise TypeError(f"PadValue.{self.kind} does not support dtype {dtype_name}")
        value = limits[dtype_name][0 if self.kind == "MIN" else 1]
        return _ops.const(value, dtype=resolved_dtype)


class PadValue:
    """TileLang-compatible extrema used to initialize reduction vectors."""

    MIN = _PadValue("MIN")
    MAX = _PadValue("MAX")


def get_lanes(dtype) -> int:
    """Vector lanes for *dtype* (256-byte vreg). Returns a Python int used as a loop step."""
    return _ops._elements_per_vreg(_resolve(_author_dtype(dtype)))


def make_mask(dtype, value):
    """``pto.plt_b{8,16,32}`` predicate mask; returns a ``(mask, remained)``-unpackable value."""
    return _ops.make_mask(_author_dtype(dtype), value)


def addptr(base_ptr, index_offset):
    """``pto.addptr`` – advance a pointer by an element offset."""
    return _ops.addptr(base_ptr, index_offset)


def scalar(value, dtype):
    """Materialize a scalar constant with an explicit element dtype."""
    return _ops.const(value, dtype=_author_dtype(dtype))


def vlds(src_ptr, offset=None, result_vreg_type=None, *, dist=None, post_update=PostUpdate.OFF):
    """``pto.vlds`` from a tile slice or pointer."""
    return _ops.vlds(
        src_ptr,
        offset,
        result_vreg_type,
        dist=dist,
        post_update=post_update,
    )


def vadd(lhs, rhs, mask):
    """``pto.vadd`` element-wise add."""
    return _ops.vadd(lhs, rhs, mask)


def vsub(lhs, rhs, mask):
    """``pto.vsub`` element-wise subtract."""
    return _ops.vsub(lhs, rhs, mask)


def vmul(lhs, rhs, mask):
    """``pto.vmul`` element-wise multiply."""
    return _ops.vmul(lhs, rhs, mask)


def vmax(lhs, rhs, mask):
    """``pto.vmax`` element-wise maximum."""
    return _ops.vmax(lhs, rhs, mask)


def vmin(lhs, rhs, mask):
    """``pto.vmin`` element-wise minimum."""
    return _ops.vmin(lhs, rhs, mask)


def vdiv(lhs, rhs, mask):
    """``pto.vdiv`` element-wise divide (default precision)."""
    return _ops.vdiv(lhs, rhs, mask)


def vand(lhs, rhs, mask):
    return _ops.vand(lhs, rhs, mask)


def vor(lhs, rhs, mask):
    return _ops.vor(lhs, rhs, mask)


def vxor(lhs, rhs, mask):
    return _ops.vxor(lhs, rhs, mask)


def vshl(lhs, rhs, mask):
    return _ops.vshl(lhs, rhs, mask)


def vshr(lhs, rhs, mask):
    return _ops.vshr(lhs, rhs, mask)


def vabs(inp, mask):
    return _ops.vabs(inp, mask)


def vneg(inp, mask):
    return _ops.vneg(inp, mask)


def vnot(inp, mask):
    return _ops.vnot(inp, mask)


def vrelu(inp, mask):
    return _ops.vrelu(inp, mask)


def vexp(inp, mask):
    return _ops.vexp(inp, mask)


def vexpdif(inp, ref, mask, part=VcvtPartMode.ODD):
    return _ops.vexpdif(inp, ref, mask, part)


def vbr(value):
    return _ops.vbr(value)


def vsqrt(inp, mask):
    return _ops.vsqrt(inp, mask)


def vdup(value, mask):
    return _ops.vdup(value, mask)


def vcmax(value, mask):
    return _ops.vcmax(value, mask)


def vcmin(value, mask):
    return _ops.vcmin(value, mask)


def vcadd(value, mask):
    return _ops.vcadd(value, mask)


def vcvt(src, to_dtype, mask, *, rnd=None, sat=None, part=None):
    return _ops.vcvt(src, _author_dtype(to_dtype), mask, rnd=rnd, sat=sat, part=part)


def vsel(true_value, false_value, mask):
    return _ops.vsel(true_value, false_value, mask)


def bytewidth(dtype):
    return _ops.bytewidth(_author_dtype(dtype))


def plds(buf, offset, dist=PredicateDist.NORM):
    return _ops.plds(buf, offset, dist=dist)


def pset_b16(pattern):
    return _ops.pset_b16(pattern)


def pbitcast(mask, to_type):
    return _ops.pbitcast(mask, to_type)


def pintlv_b16(lhs, rhs):
    return _ops.pintlv_b16(lhs, rhs)


def punpack(mask, part, to_type=None):
    return _ops.punpack(mask, part, to_type)


def mem_bar(barrier_type):
    return _ops.mem_bar(barrier_type)


def vsts(vec, dst_ptr, offset, mask=None, *, dist=None, post_update=PostUpdate.OFF):
    """``pto.vsts`` to a tile slice or pointer."""
    return _ops.vsts(vec, dst_ptr, offset, mask, dist=dist, post_update=post_update)


__all__ = [
    "Tile",
    "for_",
    "static_range",
    "if_",
    "yield_",
    "const_expr",
    "constexpr",
    "vecscope",
    "get_lanes",
    "make_mask",
    "addptr",
    "scalar",
    "PostUpdate",
    "BarrierType",
    "MaskPattern",
    "PredicateDist",
    "PredicatePart",
    "VStoreDist",
    "VcvtPartMode",
    "VcvtSatMode",
    "PadValue",
    "mask_b16",
    "mask_b32",
    "vlds",
    "vadd",
    "vsub",
    "vmul",
    "vmax",
    "vmin",
    "vdiv",
    "vand",
    "vor",
    "vxor",
    "vshl",
    "vshr",
    "vabs",
    "vneg",
    "vnot",
    "vrelu",
    "vexp",
    "vexpdif",
    "vbr",
    "vsqrt",
    "vdup",
    "vcmax",
    "vcmin",
    "vcadd",
    "vcvt",
    "vsel",
    "bytewidth",
    "plds",
    "pset_b16",
    "pbitcast",
    "pintlv_b16",
    "punpack",
    "mem_bar",
    "vsts",
]
