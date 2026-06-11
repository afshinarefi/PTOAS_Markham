# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""TileLib render abstraction-level test for pto.tadd.

Asserts the rendered MLIR is *on par* with the tilelang golden
(fixtures/tadd_a5_8x64_f32.golden.mlir): same structured abstraction, not byte-identical
(ptodsl differs in SSA naming, constant hoisting, index-vs-i32 carry, subview rank).
"""

from pathlib import Path

from ptodsl.tilelib import TileSpec, f32
from ptodsl.tilelib.templates.a5.tadd import template_tadd

FIXTURE = Path(__file__).parent / "fixtures" / "tadd_a5_8x64_f32.golden.mlir"

# The structured abstraction the migration must preserve (see golden fixture).
REQUIRED_OPS = [
    "pto.tile_buf_addr",
    "memref<8x64xf32, #pto.address_space<vec>>",
    "pto.tile_valid_rows",
    "pto.tile_valid_cols",
    "scf.for",
    "pto.plt_b32",
    "memref.subview",
    "pto.vlds",
    "pto.vadd",
    "pto.vsts",
    "!pto.vreg<64xf32>",
]

# The low-level pointer style the team explicitly rejected for TileLib templates.
FORBIDDEN_OPS = ["pto.castptr", "pto.addptr"]


def _render():
    spec = TileSpec(shape=(8, 64), dtype=f32)
    return template_tadd.specialize(src0=spec, src1=spec, dst=spec).mlir_text()


def test_tadd_renders_structured_abstraction():
    text = _render()
    for op in REQUIRED_OPS:
        assert op in text, f"expected {op!r} in rendered MLIR:\n{text}"
    for op in FORBIDDEN_OPS:
        assert op not in text, f"did not expect bare-pointer {op!r} in rendered MLIR:\n{text}"


def test_tadd_func_is_a_tilelang_instance():
    text = _render()
    assert 'pto.target_arch = "a5"' in text
    assert "pto.tilelang.instance" in text
    assert "#pto.kernel_kind<vector>" in text
    assert "func.func @template_tadd" in text


def test_golden_fixture_uses_same_abstraction():
    # Sanity: the committed reference contains the same structured ops we require of ours.
    assert FIXTURE.exists(), f"missing golden fixture {FIXTURE}"
    golden = FIXTURE.read_text(encoding="utf-8")
    for op in ("pto.tile_buf_addr", "memref.subview", "pto.vlds", "pto.vadd", "pto.vsts", "pto.plt_b32"):
        assert op in golden


if __name__ == "__main__":
    test_tadd_renders_structured_abstraction()
    test_tadd_func_is_a_tilelang_instance()
    test_golden_fixture_uses_same_abstraction()
    print("ok")
