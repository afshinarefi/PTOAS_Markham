# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib templates for a small subset of pto.tcvt."""

import ptodsl.tilelib as pto


def _tcvt_f32_to_f16_2d(src: pto.Tile, dst: pto.Tile):
    src_dtype = src.element_type
    valid_rows, valid_cols = dst.valid_shape
    lanes = pto.get_lanes(src_dtype)
    full_mask = pto.make_mask(src_dtype, "PAT_ALL")

    with pto.for_(0, valid_rows, step=1) as row:
        col_loop = pto.for_(0, valid_cols, step=lanes).carry(remained=valid_cols)
        with col_loop:
            col = col_loop.iv
            store_mask, remained = pto.make_mask(src_dtype, col_loop.remained)
            vec = pto.vlds(src[row, col:])
            converted = pto.vcvt(
                vec,
                dst.element_type,
                full_mask,
                rnd=pto.VcvtRoundMode.R,
                sat=pto.VcvtSatMode.SAT,
                part=pto.VcvtPartMode.EVEN,
            )
            pto.vsts(converted, dst[row, col:], store_mask, dist=pto.VStoreDist.PK_B32)
            col_loop.update(remained=remained)


def _tcvt_regular_2d(src: pto.Tile, dst: pto.Tile):
    dst_dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape
    lanes = pto.get_lanes(dst_dtype)

    with pto.for_(0, valid_rows, step=1) as row:
        col_loop = pto.for_(0, valid_cols, step=lanes).carry(remained=valid_cols)
        with col_loop:
            col = col_loop.iv
            mask, remained = pto.make_mask(dst_dtype, col_loop.remained)
            vec = pto.vlds(src[row, col:])
            converted = pto.vcvt(
                vec,
                dst_dtype,
                mask,
                rnd=pto.VcvtRoundMode.R,
                sat=pto.VcvtSatMode.SAT,
            )
            pto.vsts(converted, dst[row, col:], mask)
            col_loop.update(remained=remained)


@pto.tile_template(
    op="pto.tcvt",
    target="a5",
    name="template_tcvt_f32_to_f16",
    id=0,
    constraints=[
        pto.check_type(("f32", "f16")),
        pto.check_memory_space("ub"),
        pto.check_layout("row_major"),
        pto.require_contiguous(False),
    ],
    priority=0,
    loop_depth=2,
    is_post_update=False,
    tags=["tcvt", "2d", "no_post_update", "f32_to_f16"],
)
def template_tcvt_f32_to_f16(src: pto.Tile, dst: pto.Tile):
    _tcvt_f32_to_f16_2d(src, dst)


@pto.tile_template(
    op="pto.tcvt",
    target="a5",
    name="template_tcvt_f32_to_i32",
    id=1,
    constraints=[
        pto.check_type(("f32", "i32")),
        pto.check_memory_space("ub"),
        pto.check_layout("row_major"),
        pto.require_contiguous(False),
    ],
    priority=0,
    loop_depth=2,
    is_post_update=False,
    tags=["tcvt", "2d", "no_post_update", "f32_to_i32"],
)
def template_tcvt_f32_to_i32(src: pto.Tile, dst: pto.Tile):
    _tcvt_regular_2d(src, dst)
