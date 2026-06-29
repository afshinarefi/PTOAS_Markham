# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tcmp."""

import ptodsl.tilelib as pto


@pto.tile_template(
    op="pto.tcmp",
    target="a5",
    name="template_tcmp",
    dtypes=[
        ("f32", "f32", "i8"),
        ("i32", "i32", "i8"),
        ("f16", "f16", "i8"),
        ("i16", "i16", "i8"),
        ("i8", "i8", "i8"),
        ("ui8", "ui8", "i8"),
    ],
)
def template_tcmp(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    dtype = src0.element_type
    valid_rows, valid_cols = src0.valid_shape
    cmp_mode = pto.get_op_attr("cmp_mode", "eq")
    lanes = pto.get_lanes(dtype)
    dst_ptr = dst.as_ptr()
    dst_stride = dst.shape[1]

    if pto.constexpr(str(dtype) in ("f32", "i32")):
        iterations = ((valid_cols + lanes - 1) // lanes + 1) // 2
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            for j in range(0, iterations, 1):
                mask0, remained = pto.make_mask(dtype, remained)
                mask1, remained = pto.make_mask(dtype, remained)
                cmp0 = pto.vcmp(
                    pto.vlds(src0[row, j * lanes * 2:]),
                    pto.vlds(src1[row, j * lanes * 2:]),
                    mask0,
                    cmp_mode,
                )
                cmp1 = pto.vcmp(
                    pto.vlds(src0[row, (j * 2 + 1) * lanes:]),
                    pto.vlds(src1[row, (j * 2 + 1) * lanes:]),
                    mask1,
                    cmp_mode,
                )
                packed, _ = pto.pdintlv_b8(
                    pto.pbitcast(cmp0, pto.mask_b8),
                    pto.pbitcast(cmp1, pto.mask_b8),
                )
                pto.psts(
                    packed,
                    dst_ptr,
                    row * dst_stride + j * 16,
                    dist=pto.PredicateDist.PK,
                )
    else:
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            for col in range(0, valid_cols, lanes):
                mask, remained = pto.make_mask(dtype, remained)
                compared = pto.vcmp(
                    pto.vlds(src0[row, col:]),
                    pto.vlds(src1[row, col:]),
                    mask,
                    cmp_mode,
                )
                if pto.constexpr(str(dtype) in ("f16", "i16")):
                    compared = pto.pbitcast(compared, pto.mask_b8)
                    distance = pto.PredicateDist.PK
                    byte_offset = row * dst_stride + (col // lanes) * 16
                else:
                    distance = pto.PredicateDist.NORM
                    byte_offset = row * dst_stride + (col // lanes) * 32
                pto.psts(compared, dst_ptr, byte_offset, dist=distance)
