# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.tfillpad_expand."""

import ptodsl.tilelib as pto

from .tfillpad import DTYPE_SIGNATURES, fillpad_body


@pto.tile_template(
    op="pto.tfillpad_expand",
    target="a5",
    name="template_tfillpad_expand",
    dtypes=DTYPE_SIGNATURES,
)
def template_tfillpad_expand(src: pto.Tile, dst: pto.Tile):
    fillpad_body(src, dst, expand_rows=True)
