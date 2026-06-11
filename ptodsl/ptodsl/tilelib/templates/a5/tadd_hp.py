# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Second pto.tadd template (MVP) — identical body, higher priority.

This intentionally duplicates the body of ``tadd.template_tadd``. Its only purpose is to
validate multi-version registration and priority-based selection: with both registered,
``registry.select(op="pto.tadd", ...)`` must pick this one (priority=10 > 0). Real
alternative implementations (1D-contiguous, post-update, ...) replace this in Phase 5.
"""

from ptodsl.tilelib import (
    Tile,
    for_,
    get_lanes,
    make_mask,
    tile_template,
    vadd,
    vlds,
    vsts,
)


@tile_template(
    op="pto.tadd",
    target="a5",
    name="tadd_basic_2d_high_priority",
    dtypes=[("f32", "f32", "f32")],
    layouts=["row_major"],
    memory_spaces=["ub"],
    priority=10,
    fusible=False,
    tags=["placeholder", "duplicate-body"],
)
def tadd_basic_2d_high_priority(src0: Tile, src1: Tile, dst: Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape

    with for_(0, valid_rows, step=1) as row:
        with for_(0, valid_cols, step=get_lanes(dtype), state={"remained": valid_cols}) as loop:
            col = loop.iv
            mask, remained = make_mask(dtype, loop.state.remained)
            lhs = vlds(src0[row, col:])
            rhs = vlds(src1[row, col:])
            summed = vadd(lhs, rhs, mask)
            vsts(summed, dst[row, col:], mask)
            loop.yield_state(remained=remained)
