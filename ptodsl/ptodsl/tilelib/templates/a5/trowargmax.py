# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.trowargmax."""

import ptodsl.tilelib as pto


@pto.tile_template(op="pto.trowargmax", target="a5", name="template_trowargmax")
def template_trowargmax(src: pto.Tile, tmp: pto.Tile, dst: pto.Tile):
    src_dtype = src.element_type
    index_dtype = dst.element_type
    lanes = pto.get_lanes(src_dtype)
    valid_rows, valid_cols = src.valid_shape
    byte_width = pto.bytewidth(index_dtype)
    if pto.constexpr(byte_width == 4):
        store_dist = pto.VStoreDist.ONE_POINT_B32
    elif pto.constexpr(byte_width == 2):
        store_dist = pto.VStoreDist.ONE_POINT_B16
    else:
        store_dist = pto.VStoreDist.ONE_POINT_B8

    for row in range(0, valid_rows, 1):
        remained = valid_cols
        value_acc = pto.vbr(pto.PadValue.MIN.eval(src_dtype))
        index_acc = pto.vbr(pto.scalar(0, index_dtype))
        value_mask, _ = pto.make_mask(src_dtype, 1)
        index_mask, _ = pto.make_mask(index_dtype, 1)
        for col in range(0, valid_cols, lanes):
            mask, remained = pto.make_mask(src_dtype, remained)
            reduced = pto.vcmax(pto.vlds(src[row, col:]), mask)
            value, index = pto.vdintlv(
                reduced,
                pto.vbr(pto.scalar(0, src_dtype)),
            )
            index = pto.vbitcast(index, index_dtype)
            index = pto.vadds(index, pto.cast_scalar(col, index_dtype), index_mask)
            selected = pto.vcmp(value_acc, value, value_mask, "lt")
            value_acc = pto.vsel(value, value_acc, selected)
            index_acc = pto.vsel(
                index,
                index_acc,
                pto.pbitcast(selected, pto.mask_b32),
            )
        pto.vsts(index_acc, dst[row, 0:], index_mask, dist=store_dist)
