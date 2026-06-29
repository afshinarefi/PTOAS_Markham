# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Selection and render coverage for Group 3 TileLib migrations."""

import unittest

import ptodsl.tilelib.templates  # noqa: F401
from ptodsl.tilelib import (
    ScalarSpec,
    TileSpec,
    f16,
    f32,
    i8,
    i16,
    i32,
    select,
    ui8,
)


GROUP3_CASES = {
    "pto.tadds": ("template_tadds", "pto.vadds", "scalar_f32"),
    "pto.tands": ("template_tands", "pto.vand", "scalar_i32"),
    "pto.tcmps": ("template_tcmps", "pto.vcmps", "compare_scalar"),
    "pto.texpands": ("template_texpands", "pto.vdup", "expand_scalar"),
    "pto.tfmods": ("template_tfmods", "pto.vtrc", "scalar_f32"),
    "pto.tlrelu": ("template_tlrelu", "pto.vlrelu", "lrelu"),
    "pto.tmaxs": ("template_tmaxs", "pto.vmaxs", "scalar_f32"),
    "pto.tmins": ("template_tmins", "pto.vmins", "scalar_f32"),
    "pto.tmuls": ("template_tmuls", "pto.vmuls", "scalar_f32"),
    "pto.tors": ("template_tors", "pto.vor", "scalar_i32"),
    "pto.trems": ("template_trems", "pto.vtrc", "scalar_tmp_f32"),
    "pto.tsels": ("template_tsels", "pto.vsel", "select_scalar"),
    "pto.tshls": ("template_tshls", "pto.vshls", "shift_scalar"),
    "pto.tshrs": ("template_tshrs", "pto.vshrs", "shift_scalar"),
    "pto.tsubs": ("template_tsubs", "pto.vsub", "scalar_f32"),
    "pto.txors": ("template_txors", "pto.vxor", "scalar_tmp_i32"),
    "pto.tcmp": ("template_tcmp", "pto.vcmp", "compare"),
    "pto.tfillpad": ("template_tfillpad", "pto.vdup", "fillpad"),
    "pto.tfillpad_expand": (
        "template_tfillpad_expand",
        "pto.vdup",
        "fillpad_expand",
    ),
    "pto.tfillpad_inplace": (
        "template_tfillpad_inplace",
        "pto.vstus",
        "fillpad_expand",
    ),
    "pto.tmov": ("template_tmov_basic", "pto.vlds", "move"),
    "pto.tcolargmax": ("template_tcolargmax", "pto.vmax", "column_arg"),
    "pto.tcolargmin": ("template_tcolargmin", "pto.vmin", "column_arg"),
    "pto.trowargmax": ("template_trowargmax", "pto.vcmax", "row_arg"),
    "pto.trowargmin": ("template_trowargmin", "pto.vcmin", "row_arg"),
    "pto.trowprod": ("template_trowprod", "pto.vintlv", "row_reduction"),
    "pto.tfmod": ("template_tfmod", "pto.vtrc", "binary_f32"),
    "pto.trem": ("template_trem", "pto.vtrc", "binary_tmp_f32"),
    "pto.tprelu": ("template_tprelu", "pto.vprelu", "binary_tmp_f32"),
    "pto.tpartadd": ("template_tpartadd", "pto.vadd", "partial"),
    "pto.tpartmul": ("template_tpartmul", "pto.vmul", "partial"),
}


def _tile(shape=(2, 64), dtype=f32, **kwargs):
    return TileSpec(shape, dtype, **kwargs)


def _specs(kind):
    if kind == "scalar_f32":
        return {
            "src": _tile(),
            "scalar": ScalarSpec(f32),
            "dst": _tile(),
        }
    if kind == "scalar_i32":
        return {
            "src": _tile(dtype=i32),
            "scalar": ScalarSpec(i32),
            "dst": _tile(dtype=i32),
        }
    if kind == "lrelu":
        return {"src": _tile(), "slope": ScalarSpec(f32), "dst": _tile()}
    if kind == "expand_scalar":
        return {"scalar": ScalarSpec(f32), "dst": _tile()}
    if kind == "scalar_tmp_f32":
        return {
            "src": _tile(),
            "scalar": ScalarSpec(f32),
            "tmp": _tile(),
            "dst": _tile(),
        }
    if kind == "shift_scalar":
        return {
            "src": _tile(dtype=i32),
            "scalar": ScalarSpec(i16),
            "dst": _tile(dtype=i32),
        }
    if kind == "scalar_tmp_i32":
        return {
            "src": _tile(dtype=i32),
            "scalar": ScalarSpec(i32),
            "tmp": _tile(dtype=i32),
            "dst": _tile(dtype=i32),
        }
    if kind == "compare":
        return {
            "src0": _tile(),
            "src1": _tile(),
            "dst": _tile(dtype=i8),
        }
    if kind == "compare_scalar":
        return {
            "src": _tile(),
            "scalar": ScalarSpec(f32),
            "dst": _tile(dtype=ui8),
        }
    if kind == "select_scalar":
        return {
            "mask": _tile((2, 16), i8),
            "src": _tile((2, 128)),
            "tmp": _tile((2, 128)),
            "scalar": ScalarSpec(f32),
            "dst": _tile((2, 128)),
        }
    if kind == "fillpad":
        return {
            "src": _tile(valid_shape=(2, 48)),
            "dst": _tile(valid_shape=(2, 64), pad_value="0x1"),
        }
    if kind == "fillpad_expand":
        return {
            "src": _tile((1, 64), valid_shape=(1, 48)),
            "dst": _tile((2, 64), valid_shape=(2, 64), pad_value="0x1"),
        }
    if kind == "move":
        return {"src": _tile(), "dst": _tile()}
    if kind == "column_arg":
        return {
            "src": _tile((4, 64)),
            "tmp": _tile((4, 64)),
            "dst": _tile((1, 64), i32),
        }
    if kind == "row_arg":
        return {
            "src": _tile(),
            "tmp": _tile(),
            "dst": _tile((2, 1), i32),
        }
    if kind == "row_reduction":
        return {"src": _tile(), "tmp": _tile(), "dst": _tile((2, 1))}
    if kind == "binary_f32":
        return {"src0": _tile(), "src1": _tile(), "dst": _tile()}
    if kind == "binary_tmp_f32":
        return {
            "src0": _tile(),
            "src1": _tile(),
            "tmp": _tile(),
            "dst": _tile(),
        }
    if kind == "partial":
        return {"src0": _tile(), "src1": _tile(), "dst": _tile()}
    raise AssertionError(f"unknown Group 3 test kind {kind}")


class TileLibGroup3Test(unittest.TestCase):
    def test_all_group3_templates_select_and_render(self):
        self.assertEqual(len(GROUP3_CASES), 31)
        for op, (name, expected_op, kind) in GROUP3_CASES.items():
            with self.subTest(op=op):
                specs = _specs(kind)
                descriptor = select(op, "a5", specs)
                self.assertEqual(descriptor.name, name)
                text = descriptor.specialize(**specs).mlir_text()
                self.assertIn(expected_op, text)
                self.assertIn("pto.tilelang.instance", text)

    def test_scalar_operand_is_preserved_in_entry_signature(self):
        specs = _specs("scalar_f32")
        text = select("pto.tadds", "a5", specs).specialize(**specs).mlir_text()
        self.assertIn("%arg1: f32", text)
        self.assertIn("pto.vadds", text)

    def test_context_attribute_reaches_comparison_template(self):
        specs = _specs("compare")
        descriptor = select("pto.tcmp", "a5", specs, context_attrs={"cmp_mode": "lt"})
        text = descriptor.specialize(
            context_attrs={"cmp_mode": "lt"},
            **specs,
        ).mlir_text()
        self.assertIn('"lt"', text)

    def test_tile_config_and_pad_are_preserved(self):
        specs = _specs("fillpad")
        text = select("pto.tfillpad", "a5", specs).specialize(**specs).mlir_text()
        self.assertIn("pad=1", text)
        self.assertIn("valid=2x48", text)

    def test_i32_remainder_uses_software_vmod_sequence(self):
        specs = {
            name: _tile(dtype=i32)
            for name in ("src0", "src1", "tmp", "dst")
        }
        text = select("pto.trem", "a5", specs).specialize(**specs).mlir_text()
        for op in ("pto.vmull", "pto.pxor", "pto.pand", "pto.vsel"):
            self.assertIn(op, text)


if __name__ == "__main__":
    unittest.main()
