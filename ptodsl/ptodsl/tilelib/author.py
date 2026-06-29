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

from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass
from functools import wraps

# Engine control-flow surface (target of the AST rewrite).
from .._control_flow import const_expr, for_, if_, static_range, vecscope, yield_
from .._surface_types import (
    BarrierType,
    CmpMode,
    MaskPattern,
    PostUpdate,
    PredicateDist,
    PredicatePart,
    Tile,
    VStoreDist,
    VcvtPartMode,
    VcvtRoundMode,
    VcvtSatMode,
)
from .._types import mask_type
from .. import _ops
from .._types import _resolve
from .metadata import ScalarType, scalar_descriptor


constexpr = const_expr
mask_b8 = mask_type("b8")
mask_b16 = mask_type("b16")
mask_b32 = mask_type("b32")
_CONTEXT_ATTRS = ContextVar("ptodsl_tilelib_context_attrs", default={})


class Scalar:
    """Annotation marker for a scalar TileOp operand."""


@contextmanager
def _activate_context_attrs(attrs):
    token = _CONTEXT_ATTRS.set(dict(attrs or {}))
    try:
        yield
    finally:
        _CONTEXT_ATTRS.reset(token)


def get_op_attr(name, default=None):
    """Return a context attribute serialized with the TileOp render request."""
    return _CONTEXT_ATTRS.get().get(name, default)


def inline_proc(fn):
    """Trace a helper function inline using the same AST rewrite as the entry template."""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        from .._ast_rewrite import rewrite_jit_function

        return rewrite_jit_function(fn)(*args, **kwargs)

    return wrapper


def _author_dtype(dtype):
    if isinstance(dtype, ScalarType):
        return scalar_descriptor(dtype)
    return dtype


class _PadValue:
    def __init__(self, kind, dtype=None):
        self.kind = kind
        self.dtype = dtype

    def bind(self, dtype):
        return _PadValue(self.kind, dtype)

    def __eq__(self, other):
        return isinstance(other, _PadValue) and self.kind == other.kind

    def __hash__(self):
        return hash(self.kind)

    def eval(self, dtype=None):
        dtype = dtype or self.dtype
        if dtype is None:
            raise TypeError("PadValue.eval() requires a dtype")
        resolved_dtype = _author_dtype(dtype)
        dtype_name = str(_resolve(resolved_dtype))
        if self.kind == "NULL":
            raise ValueError("PadValue.NULL does not carry a materialized value")
        if self.kind == "ZERO":
            return _ops.const(0, dtype=resolved_dtype)
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
    """TileLang-compatible tile padding values."""

    NULL = _PadValue("NULL")
    ZERO = _PadValue("ZERO")
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


def cast_scalar(value, dtype):
    """Cast a traced scalar value to an explicit element dtype."""
    return _ops.cast_scalar(value, _author_dtype(dtype))


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


def vadds(inp, scalar, mask):
    return _ops.vadds(inp, scalar, mask)


def vsub(lhs, rhs, mask):
    """``pto.vsub`` element-wise subtract."""
    return _ops.vsub(lhs, rhs, mask)


def vsubs(inp, scalar, mask):
    return _ops.vsubs(inp, scalar, mask)


def vmul(lhs, rhs, mask):
    """``pto.vmul`` element-wise multiply."""
    return _ops.vmul(lhs, rhs, mask)


def vmull(lhs, rhs, mask):
    return _ops.vmull(lhs, rhs, mask)


def vmuls(inp, scalar, mask):
    return _ops.vmuls(inp, scalar, mask)


def vmax(lhs, rhs, mask):
    """``pto.vmax`` element-wise maximum."""
    return _ops.vmax(lhs, rhs, mask)


def vmaxs(inp, scalar, mask):
    return _ops.vmaxs(inp, scalar, mask)


def vmin(lhs, rhs, mask):
    """``pto.vmin`` element-wise minimum."""
    return _ops.vmin(lhs, rhs, mask)


def vmins(inp, scalar, mask):
    return _ops.vmins(inp, scalar, mask)


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


def vshls(inp, scalar, mask):
    return _ops.vshls(inp, scalar, mask)


def vshrs(inp, scalar, mask):
    return _ops.vshrs(inp, scalar, mask)


def vabs(inp, mask):
    return _ops.vabs(inp, mask)


def vneg(inp, mask):
    return _ops.vneg(inp, mask)


def vnot(inp, mask):
    return _ops.vnot(inp, mask)


def vrelu(inp, mask):
    return _ops.vrelu(inp, mask)


def vlrelu(inp, slope, mask):
    return _ops.vlrelu(inp, slope, mask)


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


def vtrc(src, mask, round_mode="Z", *, rnd=None):
    return _ops.vtrc(src, mask, rnd if rnd is not None else round_mode)


def vintlv(lhs, rhs):
    return _ops.vintlv(lhs, rhs)


def vdintlv(lhs, rhs):
    return _ops.vdintlv(lhs, rhs)


def vprelu(lhs, rhs, mask):
    return _ops.vprelu(lhs, rhs, mask)


def vsel(true_value, false_value, mask):
    return _ops.vsel(true_value, false_value, mask)


def bytewidth(dtype):
    return _ops.bytewidth(_author_dtype(dtype))


def plds(buf, offset, dist=PredicateDist.NORM):
    return _ops.plds(buf, offset, dist=dist)


def pset_b16(pattern):
    return _ops.pset_b16(pattern)


def pset_b32(pattern):
    return _ops.pset_b32(pattern)


def pbitcast(mask, to_type):
    return _ops.pbitcast(mask, to_type)


def vbitcast(vector, to_dtype):
    return _ops.vbitcast(vector, _author_dtype(to_dtype))


def pintlv_b16(lhs, rhs):
    return _ops.pintlv_b16(lhs, rhs)


def pintlv_b32(lhs, rhs):
    return _ops.pintlv_b32(lhs, rhs)


def pdintlv_b8(lhs, rhs):
    return _ops.pdintlv_b8(lhs, rhs)


def pdintlv_b32(lhs, rhs):
    return _ops.pdintlv_b32(lhs, rhs)


def pand(lhs, rhs, mask):
    return _ops.pand(lhs, rhs, mask)


def pxor(lhs, rhs, mask):
    return _ops.pxor(lhs, rhs, mask)


def pnot(value, mask):
    return _ops.pnot(value, mask)


def punpack(mask, part, to_type=None):
    return _ops.punpack(mask, part, to_type)


def mem_bar(barrier_type):
    return _ops.mem_bar(barrier_type)


def psts(mask, dst_ptr, offset, *, dist=PredicateDist.NORM):
    return _ops.psts(mask, dst_ptr, offset, dist=dist)


def init_align():
    return _ops.init_align()


def vstus(align, offset, value, base):
    return _ops.vstus(align, offset, value, base)


def vstas(align, destination, offset):
    return _ops.vstas(align, destination, offset)


def vcmp(src0, src1, mask, mode):
    return _ops.vcmp(src0, src1, mask, mode)


def vcmps(src, scalar, mask, mode):
    return _ops.vcmps(src, scalar, mask, mode)


def vsts(vec, dst_ptr, offset, mask=None, *, dist=None, post_update=PostUpdate.OFF):
    """``pto.vsts`` to a tile slice or pointer."""
    return _ops.vsts(vec, dst_ptr, offset, mask, dist=dist, post_update=post_update)


__all__ = [
    "Tile",
    "Scalar",
    "for_",
    "static_range",
    "if_",
    "yield_",
    "const_expr",
    "constexpr",
    "get_op_attr",
    "inline_proc",
    "vecscope",
    "get_lanes",
    "make_mask",
    "addptr",
    "scalar",
    "cast_scalar",
    "PostUpdate",
    "BarrierType",
    "CmpMode",
    "MaskPattern",
    "PredicateDist",
    "PredicatePart",
    "VStoreDist",
    "VcvtPartMode",
    "VcvtRoundMode",
    "VcvtSatMode",
    "PadValue",
    "mask_b16",
    "mask_b8",
    "mask_b32",
    "vlds",
    "vadd",
    "vadds",
    "vsub",
    "vsubs",
    "vmul",
    "vmull",
    "vmuls",
    "vmax",
    "vmaxs",
    "vmin",
    "vmins",
    "vdiv",
    "vand",
    "vor",
    "vxor",
    "vshl",
    "vshr",
    "vshls",
    "vshrs",
    "vabs",
    "vneg",
    "vnot",
    "vrelu",
    "vlrelu",
    "vexp",
    "vexpdif",
    "vbr",
    "vsqrt",
    "vdup",
    "vcmax",
    "vcmin",
    "vcadd",
    "vcvt",
    "vtrc",
    "vintlv",
    "vdintlv",
    "vprelu",
    "vsel",
    "bytewidth",
    "plds",
    "pset_b16",
    "pset_b32",
    "pbitcast",
    "vbitcast",
    "pintlv_b16",
    "pintlv_b32",
    "pdintlv_b8",
    "pdintlv_b32",
    "pand",
    "pxor",
    "pnot",
    "punpack",
    "mem_bar",
    "psts",
    "init_align",
    "vstus",
    "vstas",
    "vcmp",
    "vcmps",
    "vsts",
]
