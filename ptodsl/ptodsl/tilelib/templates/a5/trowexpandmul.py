# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.trowexpandmul."""

import ptodsl.tilelib as pto


def _validate_layouts(
    src0_config=None,
    src1_config=None,
    src1_shape=(),
    dst_config=None,
):
    if src0_config is None or src1_config is None or dst_config is None:
        return False
    src1_supported = src1_config.b_layout == pto.BLayout.ROW_MAJOR or (
        src1_config.b_layout == pto.BLayout.COL_MAJOR
        and len(src1_shape) == 2
        and src1_shape[1] == 1
    )
    return (
        src0_config.b_layout == pto.BLayout.ROW_MAJOR
        and src1_supported
        and dst_config.b_layout == pto.BLayout.ROW_MAJOR
    )


@pto.tile_template(
    op="pto.trowexpandmul",
    target="a5",
    name="template_trowexpandmul",
    dtypes=[
        ("f16", "f16", "f16"),
        ("f32", "f32", "f32"),
        ("i8", "i8", "i8"),
        ("i16", "i16", "i16"),
        ("i32", "i32", "i32"),
    ],
    constraints=[_validate_layouts],
    memory_spaces=["ub"],
)
def template_trowexpandmul(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape

    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            scalar_vec = pto.vlds(src1[row, :])
            broadcasted = pto.vdup(scalar_vec, mask)
            lhs = pto.vlds(src0[row, col:])
            result = pto.vmul(lhs, broadcasted, mask)
            pto.vsts(result, dst[row, col:], mask)
