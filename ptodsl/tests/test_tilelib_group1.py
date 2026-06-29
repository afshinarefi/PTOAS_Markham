# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Selection and render coverage for the Group 1 PTODSL TileLib migrations."""

import unittest

import ptodsl.tilelib.templates  # noqa: F401  (registers all A5 templates)
from ptodsl.tilelib import NoMatchingTemplate, TileSpec, f32, select


EXPAND_TEMPLATES = {
    "pto.tcolexpand": ("template_tcolexpand", None),
    "pto.tcolexpandadd": ("template_tcolexpandadd", "pto.vadd"),
    "pto.tcolexpandmax": ("template_tcolexpandmax", "pto.vmax"),
    "pto.tcolexpandmin": ("template_tcolexpandmin", "pto.vmin"),
    "pto.tcolexpandmul": ("template_tcolexpandmul", "pto.vmul"),
    "pto.tcolexpandsub": ("template_tcolexpandsub", "pto.vsub"),
}

REDUCTION_TEMPLATES = {
    "pto.tcolmin": ("template_tcolmin", "pto.vmin"),
    "pto.tcolprod": ("template_tcolprod", "pto.vmul"),
    "pto.tcolsum": ("template_tcolsum", "pto.vadd"),
}

SHARED_OPS = (
    "pto.tile_buf_addr",
    "pto.tile_valid_cols",
    "memref.subview",
    "scf.for",
    "pto.plt_b32",
    "pto.vlds",
    "pto.vsts",
    "pto.tilelang.instance",
)


def _expand_specs(op):
    src0 = TileSpec(shape=(8, 64), dtype=f32)
    dst = TileSpec(shape=(8, 64), dtype=f32)
    if op == "pto.tcolexpand":
        return {
            "src0": TileSpec(shape=(1, 64), dtype=f32),
            "dst": dst,
        }
    return {
        "src0": src0,
        "src1": TileSpec(shape=(1, 64), dtype=f32),
        "dst": dst,
    }


def _reduction_specs(dst_rows=1):
    return {
        "src": TileSpec(shape=(8, 64), dtype=f32),
        "dst": TileSpec(shape=(dst_rows, 64), dtype=f32),
    }


class TileLibGroup1Test(unittest.TestCase):
    def _assert_structured_render(self, text, vector_op):
        for op in SHARED_OPS:
            self.assertIn(op, text)
        if vector_op is not None:
            self.assertIn(vector_op, text)
        self.assertNotIn("pto.castptr", text)
        self.assertNotIn("pto.addptr", text)

    def test_column_expand_templates_select_and_render(self):
        for op, (name, vector_op) in EXPAND_TEMPLATES.items():
            with self.subTest(op=op):
                specs = _expand_specs(op)
                descriptor = select(op, "a5", specs)
                self.assertEqual(descriptor.name, name)
                self._assert_structured_render(
                    descriptor.specialize(**specs).mlir_text(),
                    vector_op,
                )

    def test_column_reduction_templates_select_and_render(self):
        for op, (name, vector_op) in REDUCTION_TEMPLATES.items():
            with self.subTest(op=op):
                specs = _reduction_specs()
                descriptor = select(op, "a5", specs)
                self.assertEqual(descriptor.name, name)
                self._assert_structured_render(
                    descriptor.specialize(**specs).mlir_text(),
                    vector_op,
                )

    def test_column_reductions_require_one_output_row(self):
        for op in REDUCTION_TEMPLATES:
            with self.subTest(op=op):
                with self.assertRaises(NoMatchingTemplate):
                    select(op, "a5", _reduction_specs(dst_rows=2))


if __name__ == "__main__":
    unittest.main()
