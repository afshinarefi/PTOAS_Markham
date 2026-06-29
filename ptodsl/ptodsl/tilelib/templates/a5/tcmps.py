# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tcmps."""

import ptodsl.tilelib as pto


@pto.tile_template(
    op="pto.tcmps",
    target="a5",
    name="template_tcmps",
    dtypes=[
        ("f32", "f32", "ui8"),
        ("i32", "i32", "ui8"),
        ("f16", "f16", "ui8"),
        ("i16", "i16", "ui8"),
        ("i8", "i8", "ui8"),
        ("ui8", "ui8", "ui8"),
    ],
)
def template_tcmps(src: pto.Tile, scalar: pto.Scalar, dst: pto.Tile):
    dtype = src.element_type
    valid_rows, valid_cols = src.valid_shape
    cmp_mode = pto.get_op_attr("cmp_mode", "eq")
    lanes = pto.get_lanes(dtype)
    dst_ptr = dst.as_ptr()

    if pto.constexpr(str(dtype) in ("f32", "i32")):
        total_elements = valid_rows * valid_cols
        iterations = ((total_elements + lanes - 1) // lanes + 1) // 2
        for i in range(0, iterations, 1):
            offset0 = i * 2 * lanes
            offset1 = (i * 2 + 1) * lanes
            row0, col0 = offset0 // valid_cols, offset0 % valid_cols
            row1, col1 = offset1 // valid_cols, offset1 % valid_cols
            mask0, _ = pto.make_mask(dtype, total_elements - offset0)
            mask1, _ = pto.make_mask(dtype, total_elements - offset1)
            cmp0 = pto.vcmps(pto.vlds(src[row0, col0:]), scalar, mask0, cmp_mode)
            cmp1 = pto.vcmps(pto.vlds(src[row1, col1:]), scalar, mask1, cmp_mode)
            packed, _ = pto.pdintlv_b8(
                pto.pbitcast(cmp0, pto.mask_b8),
                pto.pbitcast(cmp1, pto.mask_b8),
            )
            pto.psts(packed, dst_ptr, i * 16, dist=pto.PredicateDist.PK)
    else:
        iterations_per_row = (valid_cols + lanes - 1) // lanes
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            for col in range(0, valid_cols, lanes):
                mask, remained = pto.make_mask(dtype, remained)
                compared = pto.vcmps(pto.vlds(src[row, col:]), scalar, mask, cmp_mode)
                iteration = row * iterations_per_row + col // lanes
                if pto.constexpr(str(dtype) in ("f16", "i16")):
                    distance = pto.PredicateDist.PK
                    byte_offset = iteration * 16
                else:
                    distance = pto.PredicateDist.NORM
                    byte_offset = iteration * 32
                pto.psts(compared, dst_ptr, byte_offset, dist=distance)
