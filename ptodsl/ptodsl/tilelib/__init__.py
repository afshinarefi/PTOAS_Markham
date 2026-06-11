# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib: ptodsl-native templates for ExpandTileOp (migration of tilelang-dsl).

Layers:
  - metadata     : TileSpec + dtypes + TemplateMetadata
  - author       : body ops (for_/get_lanes/make_mask/vlds/vadd/vsts), engine-routed
  - decorator    : @tile_template (registers a version + its metadata)
  - registry     : constraint/priority selection among registered versions
  - render       : render_best(op, target, specs) + CLI  (the ExpandTileOp seam)
  - templates/   : the ported per-arch template bodies
"""

from .author import Tile, for_, get_lanes, make_mask, vadd, vlds, vsts
from .decorator import SpecializedTileTemplate, TileTemplate, tile_template
from .metadata import ScalarType, TemplateMetadata, TileSpec, bf16, f16, f32, i8, i16, i32
from .registry import (
    AmbiguousTemplate,
    NoMatchingTemplate,
    TileTemplateRegistry,
    default_registry,
    register,
    select,
)
from .render import render_best, select_and_specialize

__all__ = [
    # authoring surface
    "Tile",
    "tile_template",
    "for_",
    "get_lanes",
    "make_mask",
    "vlds",
    "vadd",
    "vsts",
    # specs / metadata
    "TileSpec",
    "ScalarType",
    "TemplateMetadata",
    "f32",
    "f16",
    "bf16",
    "i32",
    "i16",
    "i8",
    # descriptors
    "TileTemplate",
    "SpecializedTileTemplate",
    # registry / selection
    "TileTemplateRegistry",
    "default_registry",
    "register",
    "select",
    "NoMatchingTemplate",
    "AmbiguousTemplate",
    # rendering
    "render_best",
    "select_and_specialize",
]
