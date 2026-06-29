# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""End-to-end TileLib daemon test: ExpandTileOp RPC contract -> rendered MLIR, in-process.

Drives the daemon with the exact ``operand_specs`` JSON shape the C++ ExpandTileOp builds
for ``pto.tadd`` (see lib/PTO/Transforms/ExpandTileOp.cpp buildOperandSpecsJson), over the
real socket protocol — without any C++ / rebuild.
"""

import os
import tempfile
import threading
import unittest

from ptodsl.tilelib.serving.client import DaemonClient
from ptodsl.tilelib.serving.client import DaemonError
from ptodsl.tilelib.serving.daemon import TileLibDaemonServer


def _tile_spec(dtype="f32"):
    return {
        "kind": "tile",
        "dtype": dtype,
        "shape": [8, 64],
        "valid_shape": [8, 64],
        "memory_space": "ub",
        "config": {
            "b_layout": "row_major",
            "s_layout": "none_box",
            "s_fractal_size": 512,
            "pad_value": "0x0",
        },
    }


# operand order matches `pto.tadd ins(src0, src1) outs(dst)` == template params (src0, src1, dst).
TADD_OPERANDS = [_tile_spec(), _tile_spec(), _tile_spec()]
TADD_2D_NO_POST_UPDATE = "template_tadd_2d_no_post_update"
TADDS_OPERANDS = [_tile_spec(), {"kind": "scalar", "dtype": "f32"}, _tile_spec()]


class TileLibDaemonTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.mkdtemp()
        self.socket_path = os.path.join(self._dir, "ptodsl_tilelib.sock")
        self.server = TileLibDaemonServer(self.socket_path)
        self._thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self._thread.start()
        self.client = DaemonClient(self.socket_path)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

    def test_ping(self):
        self.assertEqual(self.client.ping(), "pong")

    def test_instantiate_tadd_returns_structured_mlir(self):
        mlir = self.client.instantiate(
            "a5", "pto.tadd", TADD_OPERANDS, candidate_id=TADD_2D_NO_POST_UPDATE
        )
        for op in ("pto.tile_buf_addr", "memref.subview", "pto.vlds", "pto.vadd",
                   "pto.vsts", "pto.plt_b32", "pto.tilelang.instance"):
            self.assertIn(op, mlir)
        self.assertNotIn("pto.castptr", mlir)

    def test_instantiate_requires_candidate_when_tadd_is_ambiguous(self):
        with self.assertRaises(DaemonError):
            self.client.instantiate("a5", "pto.tadd", TADD_OPERANDS)

    def test_instantiate_can_render_2d_no_post_update_tadd(self):
        mlir = self.client.instantiate(
            "a5", "pto.tadd", TADD_OPERANDS, candidate_id=TADD_2D_NO_POST_UPDATE
        )
        self.assertIn(f"func.func @{TADD_2D_NO_POST_UPDATE}", mlir)

    def test_get_metadata_returns_legal_candidates(self):
        metadata = self.client.get_metadata("a5", "pto.tadd", TADD_OPERANDS)
        candidates = metadata["candidates"]
        self.assertEqual(set(candidates), {
            TADD_2D_NO_POST_UPDATE,
            "template_tadd_1d_no_post_update",
            "template_tadd_2d_post_update",
            "template_tadd_1d_post_update",
        })
        self.assertEqual(candidates[TADD_2D_NO_POST_UPDATE]["loop_depth"], 2)
        self.assertEqual(candidates[TADD_2D_NO_POST_UPDATE]["Tail"], {"callable": "has_tail"})
        self.assertFalse(candidates[TADD_2D_NO_POST_UPDATE]["is_post_update"])
        self.assertEqual(candidates[TADD_2D_NO_POST_UPDATE]["tags"], ["binop", "2d", "no_post_update"])
        self.assertEqual(candidates["template_tadd_1d_no_post_update"]["loop_depth"], 1)
        self.assertEqual(candidates["template_tadd_1d_no_post_update"]["Tail"], {"callable": "has_tail"})
        self.assertTrue(candidates["template_tadd_2d_post_update"]["is_post_update"])
        self.assertEqual(candidates["template_tadd_2d_post_update"]["Tail"], {"callable": "has_tail"})
        self.assertTrue(candidates["template_tadd_1d_post_update"]["is_post_update"])
        self.assertEqual(candidates["template_tadd_1d_post_update"]["Tail"], {"callable": "has_tail"})

    def test_instantiate_can_render_named_candidate(self):
        mlir = self.client.instantiate(
            "a5", "pto.tadd", TADD_OPERANDS, candidate_id=TADD_2D_NO_POST_UPDATE
        )
        self.assertIn(f"func.func @{TADD_2D_NO_POST_UPDATE}", mlir)

    def test_instantiate_preserves_scalar_operands(self):
        mlir = self.client.instantiate("a5", "pto.tadds", TADDS_OPERANDS)
        self.assertIn("%arg1: f32", mlir)
        self.assertIn("pto.vadds", mlir)

    def test_instantiate_passes_context_attributes(self):
        operands = [_tile_spec(), _tile_spec(), _tile_spec("i8")]
        mlir = self.client.instantiate(
            "a5",
            "pto.tcmp",
            operands,
            context_attrs={"cmp_mode": "lt"},
        )
        self.assertIn('"lt"', mlir)

    def test_cache_hit_on_repeat(self):
        self.client.instantiate("a5", "pto.tadd", TADD_OPERANDS, candidate_id=TADD_2D_NO_POST_UPDATE)
        self.client.instantiate("a5", "pto.tadd", TADD_OPERANDS, candidate_id=TADD_2D_NO_POST_UPDATE)
        self.assertEqual(self.server.stats["misses"], 1)
        self.assertEqual(self.server.stats["hits"], 1)

    def test_unknown_op_errors(self):
        with self.assertRaises(DaemonError):
            self.client.instantiate("a5", "pto.tnope", TADD_OPERANDS)


if __name__ == "__main__":
    unittest.main()
