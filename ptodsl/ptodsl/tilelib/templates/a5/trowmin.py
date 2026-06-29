# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.trowmin."""

import ptodsl.tilelib as pto


@pto.tile_template(
    op="pto.trowmin",
    target="a5",
    name="template_trowmin",
    dtypes=[
        ("f16", "f16", "f16"),
        ("f32", "f32", "f32"),
        ("i16", "i16", "i16"),
        ("i32", "i32", "i32"),
    ],
    memory_spaces=["ub"],
)
def template_trowmin(src: pto.Tile, tmp: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    lanes = pto.get_lanes(dtype)
    valid_rows, valid_cols = src.valid_shape
    elem_bytes = pto.bytewidth(dtype)
    init_val = pto.PadValue.MAX.eval(dtype)

    if pto.constexpr(elem_bytes == 4):
        store_dist = pto.VStoreDist.ONE_POINT_B32
    elif pto.constexpr(elem_bytes == 2):
        store_dist = pto.VStoreDist.ONE_POINT_B16
    else:
        store_dist = pto.VStoreDist.ONE_POINT_B8

    mask_1, _ = pto.make_mask(dtype, 1)

    for row in range(0, valid_rows, 1):
        remained = valid_cols
        v_acc = pto.vbr(init_val)

        for col in range(0, valid_cols, lanes):
            mask, remained = pto.make_mask(dtype, remained)
            v_src = pto.vlds(src[row, col:])
            v_reduced = pto.vcmin(v_src, mask)

            if pto.constexpr(str(dtype) in ("f16", "f32")):
                v_reduced = pto.vsel(v_reduced, v_acc, mask)

            v_acc = pto.vmin(v_acc, v_reduced, mask_1)

        pto.vsts(v_acc, dst[row, 0:], mask_1, dist=store_dist)
