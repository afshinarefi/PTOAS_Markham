# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tmaxs."""

import ptodsl.tilelib as pto


@pto.tile_template(op="pto.tmaxs", target="a5", name="template_tmaxs")
def template_tmaxs(src: pto.Tile, scalar: pto.Scalar, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape
    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            result = pto.vmaxs(pto.vlds(src[row, col:]), scalar, mask)
            pto.vsts(result, dst[row, col:], mask)
