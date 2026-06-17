# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tadd (ported from lib/TileOps/tadd_template.py).

Body is the tilelang template verbatim; the only changes are the import line
(`import tilelang_dsl as pto` -> `import ptodsl.tilelib as pto`) and the decorator
(`@pto.vkernel` -> `@pto.tile_template` + metadata). The `for ... in range(...)` control
flow is rewritten to pto.for_(...).carry(...) by the engine's AST rewrite at trace time.
"""

import ptodsl.tilelib as pto


@pto.tile_template(
    op="pto.tadd",
    target="a5",
    name="template_tadd",
    dtypes=[("f32", "f32", "f32")],
    layouts=["row_major"],
    memory_spaces=["ub"],
    priority=0,
    loop_depth=1
)
def template_tadd(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape

    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            lhs = pto.vlds(src0[row, col:])
            rhs = pto.vlds(src1[row, col:])
            summed = pto.vadd(lhs, rhs, mask)
            pto.vsts(summed, dst[row, col:], mask)
