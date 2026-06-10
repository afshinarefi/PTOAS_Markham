# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Standalone PTODSL TileLib render check for pto.tadd (MVP).

Renders the ptodsl-native tadd template to MLIR at the structured (memref.subview)
abstraction, for comparison against the tilelang golden in
ptodsl/tests/fixtures/tadd_a5_8x64_f32.golden.mlir.

Usage:
    python3 ptodsl/examples/tilelib_render.py [-o out.mlir]
"""

import argparse

from ptodsl.tilelib import TileSpec, f32
from ptodsl.tilelib.templates.a5.tadd import template_tadd


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output", default=None, help="write MLIR here (default: stdout)")
    args = parser.parse_args()

    spec = TileSpec(shape=(8, 64), dtype=f32)
    artifact = template_tadd.specialize(src0=spec, src1=spec, dst=spec)
    text = artifact.mlir_text()

    if args.output:
        artifact.emit(args.output)
        print(f"wrote {args.output}")
    else:
        print(text)


if __name__ == "__main__":
    main()
