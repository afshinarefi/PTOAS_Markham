# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tsels."""

import ptodsl.tilelib as pto


_SIGNATURES = [
    (mask_dtype, data_dtype, data_dtype, data_dtype, data_dtype)
    for mask_dtype in ("i8", "i16", "i32")
    for data_dtype in ("i8", "i16", "i32", "f16", "f32")
]


@pto.tile_template(
    op="pto.tsels",
    target="a5",
    name="template_tsels",
    dtypes=_SIGNATURES,
)
def template_tsels(
    mask: pto.Tile,
    src: pto.Tile,
    tmp: pto.Tile,
    scalar: pto.Scalar,
    dst: pto.Tile,
):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape
    lanes = pto.get_lanes(dtype)
    mask_row_stride = mask.shape[1] * pto.bytewidth(mask.element_type)
    mask_ptr = mask.as_ptr()
    scalar_mask, _ = pto.make_mask(dtype, lanes)
    scalar_vec = pto.vdup(scalar, scalar_mask)

    if pto.constexpr(lanes == 64):
        full_mask_b16 = pto.pset_b16(pto.MaskPattern.ALL)
        pair_width = lanes * 2
        paired_cols = (valid_cols // pair_width) * pair_width
        for row in range(0, valid_rows, 1):
            for col in range(0, paired_cols, pair_width):
                offset = row * mask_row_stride + col // 8
                raw_mask = pto.plds(mask_ptr, offset, pto.PredicateDist.US)
                select_mask = pto.pbitcast(raw_mask, pto.mask_b16)
                select0, select1 = pto.pintlv_b16(select_mask, full_mask_b16)
                select0 = pto.pbitcast(select0, pto.mask_b32)
                select1 = pto.pbitcast(select1, pto.mask_b32)
                pred0, _ = pto.make_mask(dtype, pair_width)
                pred1, _ = pto.make_mask(dtype, lanes)
                pto.vsts(
                    pto.vsel(pto.vlds(src[row, col:]), scalar_vec, select0),
                    dst[row, col:],
                    pred0,
                )
                pto.vsts(
                    pto.vsel(pto.vlds(src[row, col + lanes:]), scalar_vec, select1),
                    dst[row, col + lanes:],
                    pred1,
                )
            tail = valid_cols - paired_cols
            if tail > 0:
                offset = row * mask_row_stride + paired_cols // 8
                raw_mask = pto.plds(mask_ptr, offset, pto.PredicateDist.US)
                select = pto.punpack(
                    pto.pbitcast(raw_mask, pto.mask_b16),
                    pto.PredicatePart.LOWER,
                )
                select = pto.pbitcast(select, pto.mask_b32)
                pred, _ = pto.make_mask(dtype, tail)
                pto.vsts(
                    pto.vsel(pto.vlds(src[row, paired_cols:]), scalar_vec, select),
                    dst[row, paired_cols:],
                    pred,
                )
    else:
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            for col in range(0, valid_cols, lanes):
                pred, remained = pto.make_mask(dtype, remained)
                offset = row * mask_row_stride + col // 8
                if pto.constexpr(lanes == 128):
                    raw_mask = pto.plds(mask_ptr, offset, pto.PredicateDist.US)
                    select = pto.pbitcast(raw_mask, pto.mask_b16)
                else:
                    select = pto.plds(mask_ptr, offset, pto.PredicateDist.NORM)
                pto.vsts(
                    pto.vsel(pto.vlds(src[row, col:]), scalar_vec, select),
                    dst[row, col:],
                    pred,
                )
