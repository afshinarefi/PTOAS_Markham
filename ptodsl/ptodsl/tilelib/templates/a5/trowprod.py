# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.trowprod."""

import ptodsl.tilelib as pto


@pto.tile_template(op="pto.trowprod", target="a5", name="template_trowprod")
def template_trowprod(src: pto.Tile, tmp: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    lanes = pto.get_lanes(dtype)
    valid_rows, valid_cols = src.valid_shape
    byte_width = pto.bytewidth(dtype)
    if pto.constexpr(str(dtype) in ("f16", "i16", "si16", "ui16")):
        reduction_steps = 7
    else:
        reduction_steps = 6
    if pto.constexpr(byte_width == 4):
        store_dist = pto.VStoreDist.ONE_POINT_B32
    elif pto.constexpr(byte_width == 2):
        store_dist = pto.VStoreDist.ONE_POINT_B16
    else:
        store_dist = pto.VStoreDist.ONE_POINT_B8
    mask_one, _ = pto.make_mask(dtype, 1)

    for row in range(0, valid_rows, 1):
        remained = valid_cols
        one = pto.scalar(1, dtype)
        accumulator = pto.vbr(one)
        one_vector = pto.vbr(one)
        for col in range(0, valid_cols, lanes):
            mask, remained = pto.make_mask(dtype, remained)
            product = pto.vmul(accumulator, pto.vlds(src[row, col:]), mask)
            accumulator = pto.vsel(product, accumulator, mask)
        reduction_mask, _ = pto.make_mask(dtype, lanes)
        for _ in range(0, reduction_steps, 1):
            lhs, rhs = pto.vintlv(accumulator, one_vector)
            accumulator = pto.vmul(lhs, rhs, reduction_mask)
        pto.vsts(accumulator, dst[row, 0:], mask_one, dist=store_dist)
