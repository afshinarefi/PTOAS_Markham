# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib: ptodsl-native templates for ExpandTileOp (migration of tilelang-dsl).

MVP surface — the registry/selector/serving layers land in later phases. For now this
re-exports the renderer + authoring surface so a template can be specialized to MLIR.
"""

from ._render_runtime import (
    ScalarType,
    Tile,
    TileSpec,
    TileTemplate,
    SpecializedTileTemplate,
    bf16,
    f16,
    f32,
    for_,
    get_lanes,
    i8,
    i16,
    i32,
    make_mask,
    tile_template,
    vadd,
    vlds,
    vsts,
)

__all__ = [
    "ScalarType",
    "Tile",
    "TileSpec",
    "TileTemplate",
    "SpecializedTileTemplate",
    "tile_template",
    "for_",
    "get_lanes",
    "make_mask",
    "vlds",
    "vadd",
    "vsts",
    "f32",
    "f16",
    "bf16",
    "i32",
    "i16",
    "i8",
]
