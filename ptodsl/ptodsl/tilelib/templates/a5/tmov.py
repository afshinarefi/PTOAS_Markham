# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tmov."""

import ptodsl.tilelib as pto


def _tmov_ub2ub_nd2nd_constraint(
    src_memory_space,
    dst_memory_space,
    src_config,
    dst_config,
    src_dtype,
    dst_dtype,
):
    widths = {
        "i8": 1,
        "si8": 1,
        "ui8": 1,
        "f16": 2,
        "i16": 2,
        "si16": 2,
        "ui16": 2,
        "f32": 4,
        "i32": 4,
        "si32": 4,
        "ui32": 4,
    }
    return (
        src_memory_space == "ub"
        and dst_memory_space == "ub"
        and src_config.s_layout == pto.SLayout.NONE_BOX
        and dst_config.s_layout == pto.SLayout.NONE_BOX
        and widths.get(src_dtype) == widths.get(dst_dtype)
    )


@pto.tile_template(
    op="pto.tmov",
    target="a5",
    name="template_tmov_basic",
    constraints=[_tmov_ub2ub_nd2nd_constraint],
)
def template_tmov_basic(src: pto.Tile, dst: pto.Tile):
    src_dtype = src.element_type
    dst_dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape
    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dst_dtype)):
            mask, remained = pto.make_mask(dst_dtype, remained)
            data = pto.vlds(src[row, col:])
            if pto.constexpr(str(src_dtype) != str(dst_dtype)):
                data = pto.vbitcast(data, dst_dtype)
            pto.vsts(data, dst[row, col:], mask)
