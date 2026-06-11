# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""TileLib version-selection test: metadata-driven, priority-ranked."""

import unittest

import ptodsl.tilelib.templates  # noqa: F401  (registers tadd + tadd_hp)
from ptodsl.tilelib import ScalarType, TileSpec, default_registry, select
from ptodsl.tilelib.registry import NoMatchingTemplate


def _f32_specs():
    spec = TileSpec(shape=(8, 64), dtype=ScalarType("f32"))
    return {"src0": spec, "src1": spec, "dst": spec}


class TileLibSelectTest(unittest.TestCase):
    def test_two_tadd_versions_registered(self):
        names = {d.name for d in default_registry().lookup("pto.tadd", "a5")}
        self.assertTrue({"template_tadd", "tadd_basic_2d_high_priority"} <= names)

    def test_priority_wins(self):
        chosen = select("pto.tadd", "a5", _f32_specs())
        self.assertEqual(chosen.name, "tadd_basic_2d_high_priority")
        self.assertEqual(chosen.metadata.priority, 10)

    def test_no_matching_dtype_raises(self):
        spec = TileSpec(shape=(8, 64), dtype=ScalarType("i8"))
        with self.assertRaises(NoMatchingTemplate):
            select("pto.tadd", "a5", {"src0": spec, "src1": spec, "dst": spec})

    def test_unknown_op_raises(self):
        with self.assertRaises(NoMatchingTemplate):
            select("pto.tnope", "a5", _f32_specs())


if __name__ == "__main__":
    unittest.main()
