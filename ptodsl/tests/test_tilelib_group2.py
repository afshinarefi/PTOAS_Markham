# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Selection, constraint, and render coverage for Group 2 TileLib migrations."""

import unittest

import ptodsl.tilelib.templates  # noqa: F401  (registers all A5 templates)
from ptodsl.tilelib import NoMatchingTemplate, TileSpec, f16, f32, i8, i16, i32, select


GROUP2_CASES = {
    "pto.tabs": ("template_tabs", "pto.vabs", "unary_f32"),
    "pto.tneg": ("template_tneg", "pto.vneg", "unary_f32"),
    "pto.tnot": ("template_tnot", "pto.vnot", "unary_i32"),
    "pto.trelu": ("template_trelu", "pto.vrelu", "unary_f32"),
    "pto.tand": ("template_tand", "pto.vand", "binary_i32"),
    "pto.tor": ("template_tor", "pto.vor", "binary_i32"),
    "pto.txor": ("template_txor", "pto.vxor", "xor_i32"),
    "pto.tcolexpandexpdif": (
        "template_tcolexpandexpdif_f32",
        "pto.vexpdif",
        "column_expand",
    ),
    "pto.tpartmax": ("template_tpartmax", "pto.vmax", "partial"),
    "pto.tpartmin": ("template_tpartmin", "pto.vmin", "partial"),
    "pto.trsqrt": ("template_trsqrt", "pto.vsqrt", "unary_f32"),
    "pto.tsel": ("template_tsel", "pto.vsel", "select_f32"),
    "pto.tshl": ("template_tshl", "pto.vshl", "binary_i32"),
    "pto.tshr": ("template_tshr", "pto.vshr", "binary_i32"),
    "pto.trowexpand": ("template_trowexpand", "pto.vdup", "row_expand"),
    "pto.trowexpandadd": ("template_trowexpandadd", "pto.vadd", "row_expand_binary"),
    "pto.trowexpandmax": ("template_trowexpandmax", "pto.vmax", "row_expand_binary"),
    "pto.trowexpandmin": ("template_trowexpandmin", "pto.vmin", "row_expand_binary"),
    "pto.trowexpandmul": ("template_trowexpandmul", "pto.vmul", "row_expand_binary"),
    "pto.trowexpandsub": ("template_trowexpandsub", "pto.vsub", "row_expand_binary"),
    "pto.trowexpandexpdif": (
        "template_trowexpandexpdif_f32",
        "pto.vexpdif",
        "row_expand_binary",
    ),
    "pto.trowmax": ("template_trowmax", "pto.vcmax", "row_reduction"),
    "pto.trowmin": ("template_trowmin", "pto.vcmin", "row_reduction"),
    "pto.trowsum": ("template_trowsum", "pto.vcadd", "row_reduction"),
}

SHARED_OPS = (
    "pto.tile_buf_addr",
    "pto.vlds",
    "pto.vsts",
    "pto.tilelang.instance",
)


def _same(shape, dtype, *names, **kwargs):
    return {name: TileSpec(shape, dtype, **kwargs) for name in names}


def _specs(kind):
    if kind == "unary_f32":
        return _same((8, 64), f32, "src", "dst")
    if kind == "unary_i32":
        return _same((8, 64), i32, "src", "dst")
    if kind == "binary_i32":
        return _same((8, 64), i32, "src0", "src1", "dst")
    if kind == "xor_i32":
        return _same((8, 64), i32, "src0", "src1", "tmp", "dst")
    if kind == "column_expand":
        return {
            "src0": TileSpec((8, 64), f32),
            "src1": TileSpec((1, 64), f32),
            "dst": TileSpec((8, 64), f32),
        }
    if kind == "partial":
        return _same((8, 64), f32, "src0", "src1", "dst")
    if kind == "select_f32":
        data = TileSpec((2, 128), f32)
        return {
            "mask": TileSpec((2, 16), i8),
            "src0": data,
            "src1": data,
            "tmp": data,
            "dst": data,
        }
    if kind == "row_expand":
        return {
            "src": TileSpec((8, 8), f32),
            "dst": TileSpec((8, 64), f32),
        }
    if kind == "row_expand_binary":
        return {
            "src0": TileSpec((8, 64), f32),
            "src1": TileSpec((8, 8), f32),
            "dst": TileSpec((8, 64), f32),
        }
    if kind == "row_reduction":
        return {
            "src": TileSpec((8, 64), f32),
            "tmp": TileSpec((8, 64), f32),
            "dst": TileSpec((8, 1), f32),
        }
    raise AssertionError(f"unknown Group 2 test kind {kind}")


class TileLibGroup2Test(unittest.TestCase):
    def test_all_group2_templates_select_and_render(self):
        self.assertEqual(len(GROUP2_CASES), 24)
        for op, (name, vector_op, kind) in GROUP2_CASES.items():
            with self.subTest(op=op):
                specs = _specs(kind)
                descriptor = select(op, "a5", specs)
                self.assertEqual(descriptor.name, name)
                text = descriptor.specialize(**specs).mlir_text()
                self.assertIn(vector_op, text)
                for shared_op in SHARED_OPS:
                    self.assertIn(shared_op, text)

    def test_f16_exp_difference_variants(self):
        for op, name, src1_cols in (
            ("pto.tcolexpandexpdif", "template_tcolexpandexpdif_f16", 64),
            ("pto.trowexpandexpdif", "template_trowexpandexpdif_f16", 16),
        ):
            with self.subTest(op=op):
                specs = {
                    "src0": TileSpec((8, 64), f16),
                    "src1": TileSpec((1 if "col" in op else 8, src1_cols), f16),
                    "dst": TileSpec((8, 64), f16),
                }
                descriptor = select(op, "a5", specs)
                self.assertEqual(descriptor.name, name)
                self.assertIn("pto.vexp", descriptor.specialize(**specs).mlir_text())

    def test_tsel_f16_and_i8_paths(self):
        for dtype in (f16, i8):
            with self.subTest(dtype=dtype.name):
                data = TileSpec((2, 128), dtype)
                specs = {
                    "mask": TileSpec((2, 16), i8),
                    "src0": data,
                    "src1": data,
                    "tmp": data,
                    "dst": data,
                }
                text = select("pto.tsel", "a5", specs).specialize(**specs).mlir_text()
                self.assertIn("pto.plds", text)
                self.assertIn("pto.vsel", text)

    def test_i16_trowsum_widens_and_converts_back(self):
        specs = _same((8, 64), i16, "src", "tmp")
        specs["dst"] = TileSpec((8, 1), i16)
        text = select("pto.trowsum", "a5", specs).specialize(**specs).mlir_text()
        self.assertIn("!pto.vreg<64xi32>", text)
        self.assertIn("pto.vcvt", text)

    def test_row_expand_layout_constraints(self):
        full = TileSpec((8, 64), f32)
        row_scalar = TileSpec((8, 8), f32)
        col_scalar = TileSpec((8, 1), f32, b_layout="col_major")

        with self.assertRaises(NoMatchingTemplate):
            select(
                "pto.trowexpandadd",
                "a5",
                {"src0": full, "src1": col_scalar, "dst": full},
            )

        for op in ("pto.trowexpandmul", "pto.trowexpandsub"):
            with self.subTest(op=op):
                descriptor = select(
                    op,
                    "a5",
                    {"src0": full, "src1": col_scalar, "dst": full},
                )
                self.assertEqual(descriptor.name, f"template_{op.removeprefix('pto.')}")

        descriptor = select(
            "pto.trowexpandadd",
            "a5",
            {"src0": full, "src1": row_scalar, "dst": full},
        )
        self.assertEqual(descriptor.name, "template_trowexpandadd")


if __name__ == "__main__":
    unittest.main()
