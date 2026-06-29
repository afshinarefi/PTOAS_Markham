# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tfillpad."""

import ptodsl.tilelib as pto


DTYPE_SIGNATURES = [
    (dtype, dtype)
    for dtype in ("f32", "i16", "si16", "ui16", "i32", "si32", "ui32", "i8", "si8", "ui8")
]


def fill_scalar(dst):
    dtype = dst.element_type
    if pto.constexpr(str(dtype) == "f32" and dst.pad_value == pto.PadValue.ZERO):
        return pto.scalar(-1.0, dtype)
    if pto.constexpr(dst.pad_value != pto.PadValue.NULL):
        return dst.pad_value.eval()
    return pto.scalar(0, dtype)


@pto.inline_proc
def fillpad_body(src, dst, *, expand_rows):
    dtype = dst.element_type
    src_rows, _ = src.shape
    src_valid_rows, src_valid_cols = src.valid_shape
    dst_rows, dst_cols = dst.shape
    dst_valid_rows, dst_valid_cols = dst.valid_shape
    lanes = pto.get_lanes(dtype)
    aligned_col = (src_valid_cols // lanes) * lanes
    has_tail = src_valid_cols > aligned_col
    value = fill_scalar(dst)
    fill_cols = dst_valid_cols if expand_rows else dst_cols
    fill_rows = dst_valid_rows if expand_rows else src_valid_rows

    for row in range(0, src_valid_rows, 1):
        remained = aligned_col
        for col in range(0, aligned_col, lanes):
            mask, remained = pto.make_mask(dtype, remained)
            pto.vsts(pto.vlds(src[row, col:]), dst[row, col:], mask)

    if aligned_col < fill_cols:
        for row in range(0, fill_rows, 1):
            remained = fill_cols - aligned_col
            for col in range(aligned_col, fill_cols, lanes):
                mask, remained = pto.make_mask(dtype, remained)
                pto.vsts(pto.vdup(value, mask), dst[row, col:], mask)

    if has_tail:
        for row in range(0, src_valid_rows, 1):
            mask, _ = pto.make_mask(dtype, src_valid_cols - aligned_col)
            pto.vsts(pto.vlds(src[row, aligned_col:]), dst[row, aligned_col:], mask)

    if pto.constexpr(src_rows < dst_rows):
        for row in range(src_rows, dst_rows, 1):
            remained = fill_cols
            for col in range(0, fill_cols, lanes):
                mask, remained = pto.make_mask(dtype, remained)
                pto.vsts(pto.vdup(value, mask), dst[row, col:], mask)


@pto.tile_template(
    op="pto.tfillpad",
    target="a5",
    name="template_tfillpad",
    dtypes=DTYPE_SIGNATURES,
)
def template_tfillpad(src: pto.Tile, dst: pto.Tile):
    fillpad_body(src, dst, expand_rows=False)
