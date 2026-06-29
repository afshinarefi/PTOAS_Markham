# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tsel."""

import ptodsl.tilelib as pto


@pto.tile_template(
    op="pto.tsel",
    target="a5",
    name="template_tsel",
    dtypes=[
        ("i8", "f32", "f32", "f32", "f32"),
        ("i8", "f16", "f16", "f16", "f16"),
        ("i8", "i8", "i8", "i8", "i8"),
    ],
    layouts=["row_major"],
    memory_spaces=["ub"],
)
def template_tsel(mask: pto.Tile, src0: pto.Tile, src1: pto.Tile, tmp: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape

    lanes = pto.get_lanes(dtype)
    mask_row_stride = mask.shape[1]
    mask_ptr = mask.as_ptr()

    if pto.constexpr(str(dtype) == "f32"):
        full_mask_b16 = pto.pset_b16(pto.MaskPattern.ALL)
        pair_width = lanes * 2
        paired_cols = (valid_cols // pair_width) * pair_width
        for row in range(0, valid_rows, 1):
            for col in range(0, paired_cols, pair_width):
                mask_offset = row * mask_row_stride + col // 8
                select_mask_raw = pto.plds(mask_ptr, mask_offset, pto.PredicateDist.US)
                select_mask = pto.pbitcast(select_mask_raw, pto.mask_b16)
                pred0, _ = pto.make_mask(dtype, pair_width)
                pred1, _ = pto.make_mask(dtype, lanes)
                select_mask0, select_mask1 = pto.pintlv_b16(select_mask, full_mask_b16)
                select_mask0 = pto.pbitcast(select_mask0, pto.mask_b32)
                select_mask1 = pto.pbitcast(select_mask1, pto.mask_b32)
                lhs0 = pto.vlds(src0[row, col:])
                rhs0 = pto.vlds(src1[row, col:])
                lhs1 = pto.vlds(src0[row, col + lanes:])
                rhs1 = pto.vlds(src1[row, col + lanes:])
                selected0 = pto.vsel(lhs0, rhs0, select_mask0)
                selected1 = pto.vsel(lhs1, rhs1, select_mask1)
                pto.vsts(selected0, dst[row, col:], pred0)
                pto.vsts(selected1, dst[row, col + lanes:], pred1)
            tail_cols = valid_cols - paired_cols
            if tail_cols > 0:
                col = paired_cols
                mask_offset = row * mask_row_stride + col // 8
                select_mask_raw = pto.plds(mask_ptr, mask_offset, pto.PredicateDist.US)
                select_mask = pto.pbitcast(select_mask_raw, pto.mask_b16)
                select_mask0 = pto.punpack(select_mask, pto.PredicatePart.LOWER)
                select_mask0 = pto.pbitcast(select_mask0, pto.mask_b32)
                pred0, _ = pto.make_mask(dtype, tail_cols)
                lhs0 = pto.vlds(src0[row, col:])
                rhs0 = pto.vlds(src1[row, col:])
                selected0 = pto.vsel(lhs0, rhs0, select_mask0)
                pto.vsts(selected0, dst[row, col:], pred0)
    else:
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            for col in range(0, valid_cols, lanes):
                pred_mask, remained = pto.make_mask(dtype, remained)
                mask_offset = row * mask_row_stride + col // 8
                if pto.constexpr(str(dtype) == "f16"):
                    select_mask_raw = pto.plds(mask_ptr, mask_offset, pto.PredicateDist.US)
                    select_mask = pto.pbitcast(select_mask_raw, pto.mask_b16)
                else:
                    select_mask = pto.plds(mask_ptr, mask_offset, pto.PredicateDist.NORM)
                lhs = pto.vlds(src0[row, col:])
                rhs = pto.vlds(src1[row, col:])
                selected = pto.vsel(lhs, rhs, select_mask)
                pto.vsts(selected, dst[row, col:], pred_mask)
