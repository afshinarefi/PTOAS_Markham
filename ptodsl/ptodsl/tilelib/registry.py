# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""TileLib registry + version selection.

Mirrors the *logic* of tilelang-dsl's ``select_kernel`` (filter legal candidates, rank by
priority) but is engine-agnostic: it returns the chosen ``TileTemplate`` descriptor, which
the caller renders via ptodsl's engine. Selection order:

    1. filter by op + target (hard)
    2. filter by dtype-signature (hard)
    3. no legal candidate  -> error
    4. one legal candidate -> choose it
    5. several             -> highest priority wins; remaining ties -> error
"""

from __future__ import annotations


class NoMatchingTemplate(Exception):
    pass


class AmbiguousTemplate(Exception):
    pass


class TileTemplateRegistry:
    def __init__(self):
        self._descriptors: list = []

    def register(self, descriptor) -> None:
        # Re-registration (e.g. module reload) replaces the prior entry with the same name.
        self._descriptors = [
            d for d in self._descriptors
            if not (d.op == descriptor.op and d.target == descriptor.target and d.name == descriptor.name)
        ]
        self._descriptors.append(descriptor)

    def all(self) -> tuple:
        return tuple(self._descriptors)

    def lookup(self, op: str, target: str) -> list:
        return [d for d in self._descriptors if d.op == op and d.target == target]

    def select(self, op: str, target: str, tile_specs: dict, context_attrs: dict | None = None):
        candidates = self.lookup(op, target)
        if not candidates:
            raise NoMatchingTemplate(f"no template registered for op={op!r} target={target!r}")

        legal = [d for d in candidates if _dtype_signature_matches(d, tile_specs)]
        if not legal:
            sig = _dtype_signature(candidates[0], tile_specs)
            raise NoMatchingTemplate(
                f"no template for op={op!r} target={target!r} matches dtype signature {sig}"
            )

        if len(legal) == 1:
            return legal[0]

        legal.sort(key=lambda d: d.metadata.priority, reverse=True)
        top_priority = legal[0].metadata.priority
        winners = [d for d in legal if d.metadata.priority == top_priority]
        if len(winners) > 1:
            names = ", ".join(d.name for d in winners)
            raise AmbiguousTemplate(
                f"multiple templates tie at priority {top_priority} for op={op!r} target={target!r}: {names}"
            )
        return legal[0]


def _dtype_signature(descriptor, tile_specs: dict) -> tuple:
    """Per-operand dtype-name tuple in the template's parameter order."""
    return tuple(tile_specs[name].dtype.name for name in descriptor.param_names)


def _dtype_signature_matches(descriptor, tile_specs: dict) -> bool:
    # Empty dtypes metadata == "accepts any dtype signature".
    if not descriptor.metadata.dtypes:
        return True
    try:
        sig = _dtype_signature(descriptor, tile_specs)
    except KeyError:
        return False
    return sig in descriptor.metadata.dtypes


# Process-wide default registry (the decorator registers into this one).
_DEFAULT_REGISTRY = TileTemplateRegistry()


def default_registry() -> TileTemplateRegistry:
    return _DEFAULT_REGISTRY


def register(descriptor) -> None:
    _DEFAULT_REGISTRY.register(descriptor)


def select(op: str, target: str, tile_specs: dict, context_attrs: dict | None = None):
    return _DEFAULT_REGISTRY.select(op, target, tile_specs, context_attrs)


__all__ = [
    "TileTemplateRegistry",
    "NoMatchingTemplate",
    "AmbiguousTemplate",
    "default_registry",
    "register",
    "select",
]
