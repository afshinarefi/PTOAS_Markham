# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tfillpad_inplace."""

import ptodsl.tilelib as pto

from .tfillpad import DTYPE_SIGNATURES, fill_scalar


@pto.tile_template(
    op="pto.tfillpad_inplace",
    target="a5",
    name="template_tfillpad_inplace",
    dtypes=DTYPE_SIGNATURES,
)
def template_tfillpad_inplace(src: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    _, cols = dst.shape
    src_valid_rows, src_valid_cols = src.valid_shape
    dst_valid_rows, _ = dst.valid_shape
    lanes = pto.get_lanes(dtype)
    byte_width = pto.bytewidth(dtype)
    value = fill_scalar(dst)
    fill_vec = pto.vdup(value, pto.make_mask(dtype, pto.MaskPattern.ALL))
    base_ptr = dst.as_ptr()
    pad_cols = cols - src_valid_cols

    for row in range(0, src_valid_rows, 1):
        align = pto.init_align()
        row_ptr = pto.addptr(
            base_ptr,
            (row * cols + src_valid_cols) * byte_width,
        )
        full_chunks = pad_cols // lanes
        for _ in range(0, full_chunks, 1):
            align = pto.vstus(align, lanes, fill_vec, row_ptr)
            row_ptr = pto.addptr(row_ptr, lanes * byte_width)
        tail = pad_cols - full_chunks * lanes
        align = pto.vstus(align, tail, fill_vec, row_ptr)
        row_ptr = pto.addptr(row_ptr, tail * byte_width)
        pto.vstas(align, row_ptr, 0)

    for row in range(src_valid_rows, dst_valid_rows, 1):
        remained = cols
        for col in range(0, cols, lanes):
            mask, remained = pto.make_mask(dtype, remained)
            pto.vsts(pto.vdup(value, mask), dst[row, col:], mask)
