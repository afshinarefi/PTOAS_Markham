# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tpartmul."""

import ptodsl.tilelib as pto


@pto.inline_proc
def _apply(dst, src0, src1, valid_rows, valid_cols):
    dtype = dst.element_type
    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            result = pto.vmul(
                pto.vlds(src0[row, col:]),
                pto.vlds(src1[row, col:]),
                mask,
            )
            pto.vsts(result, dst[row, col:], mask)


@pto.inline_proc
def _copy(dst, src, valid_rows, valid_cols, start_row):
    dtype = dst.element_type
    for row in range(start_row, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            pto.vsts(pto.vlds(src[row, col:]), dst[row, col:], mask)


@pto.inline_proc
def _part_mul(dst, full, part, dst_rows, dst_cols, part_rows, part_cols):
    if part_cols < dst_cols:
        _copy(dst, full, dst_rows, dst_cols, 0)
        if part_cols > 0:
            _apply(dst, full, part, part_rows, part_cols)
    else:
        if part_rows == dst_rows:
            _apply(dst, full, part, dst_rows, dst_cols)
        elif part_rows < dst_rows:
            if part_cols > 0:
                _apply(dst, full, part, part_rows, part_cols)
            _copy(dst, full, dst_rows, dst_cols, part_rows)


@pto.tile_template(op="pto.tpartmul", target="a5", name="template_tpartmul")
def template_tpartmul(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    dst_rows, dst_cols = dst.valid_shape
    src0_rows, src0_cols = src0.valid_shape
    src1_rows, src1_cols = src1.valid_shape
    if src0_rows == dst_rows:
        if src0_cols == dst_cols:
            _part_mul(dst, src0, src1, dst_rows, dst_cols, src1_rows, src1_cols)
    elif src1_rows == dst_rows:
        if src1_cols == dst_cols:
            _part_mul(dst, src1, src0, dst_rows, dst_cols, src0_rows, src0_cols)
