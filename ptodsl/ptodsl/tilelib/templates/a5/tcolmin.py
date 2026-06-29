# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tcolmin."""

import ptodsl.tilelib as pto


def _validate_tcolmin(
    src_shape=(),
    src_valid_shape=(),
    dst_shape=(),
    dst_valid_shape=(),
    src_config=None,
    dst_config=None,
):
    if src_config is None or dst_config is None:
        return False
    if src_config.b_layout != pto.BLayout.ROW_MAJOR:
        return False
    if dst_config.b_layout != pto.BLayout.ROW_MAJOR:
        return False
    if src_config.s_layout != pto.SLayout.NONE_BOX:
        return False
    if dst_config.s_layout != pto.SLayout.NONE_BOX:
        return False
    if dst_valid_shape[0] != 1:
        return False
    return True


@pto.tile_template(
    op="pto.tcolmin",
    target="a5",
    name="template_tcolmin",
    dtypes=[("f32", "f32")],
    layouts=["row_major"],
    memory_spaces=["ub"],
    constraints=[_validate_tcolmin],
    priority=0,
)
def template_tcolmin(src: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = src.valid_shape

    lanes = pto.get_lanes(dtype)
    remained = valid_cols

    for col_chunk in range(0, valid_cols, lanes):
        mask, remained = pto.make_mask(dtype, remained)

        acc = pto.vlds(src[0, col_chunk:])
        for row in range(1, valid_rows, 1):
            row_vec = pto.vlds(src[row, col_chunk:])
            acc = pto.vmin(acc, row_vec, mask)
        pto.vsts(acc, dst[0, col_chunk:], mask)
