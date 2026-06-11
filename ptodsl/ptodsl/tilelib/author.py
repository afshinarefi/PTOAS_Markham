# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Author-facing TileLib body ops.

These are the ``pto.*`` names a template body calls. They are thin wrappers that route
to the existing ptodsl engine (``_ops``) — no MLIR lowering is reimplemented here. Tile
indexing (``tile[row, col:]``) and ``tile.valid_shape`` come from the tile handle itself
(see :class:`_render_runtime._TemplateTile`).
"""

from __future__ import annotations

from . import _render_runtime as _rt
from .._surface_types import Tile
from .. import _ops
from .._tracing import require_active_runtime
from .._types import _resolve


def for_(start, stop, *, step, state=None):
    """Structured loop. Returns the induction var, or a loop handle when ``state=`` is set."""
    runtime = require_active_runtime("for_", expected_type=_rt._TemplateTrace)
    return runtime.for_(start, stop, step=step, state=state)


def get_lanes(dtype) -> int:
    """Vector lanes for *dtype* (256-byte vreg). Returns a Python int used as a loop step."""
    return _ops._elements_per_vreg(_resolve(dtype))


def make_mask(dtype, value):
    """``pto.plt_b{8,16,32}`` predicate mask; returns a ``(mask, remained)``-unpackable value."""
    return _ops.make_mask(dtype, value)


def vlds(tile_slice):
    """``pto.vlds`` from a ``tile[row, col:]`` slice."""
    return _ops.vlds(tile_slice)


def vadd(lhs, rhs, mask):
    """``pto.vadd`` element-wise add."""
    return _ops.vadd(lhs, rhs, mask)


def vsts(vec, tile_slice, mask):
    """``pto.vsts`` to a ``tile[row, col:]`` slice."""
    return _ops.vsts(vec, tile_slice, mask)


__all__ = ["Tile", "for_", "get_lanes", "make_mask", "vlds", "vadd", "vsts"]
