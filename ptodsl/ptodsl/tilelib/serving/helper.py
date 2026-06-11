# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""One-shot client helper (drop-in for ``tilelang_dsl.daemon_helper``).

Same CLI/contract ExpandTileOp invokes: connect to the daemon socket, issue an
``instantiate`` RPC, print the rendered MLIR to stdout (exit non-zero on failure).

    python3 -m ptodsl.tilelib.serving.helper --socket <path> --target a5 --op pto.tadd \\
        --operand-specs '[...]' [--context-attrs '{...}']
"""

from __future__ import annotations

import argparse
import json
import sys

from .client import DaemonClient, DaemonError


def main(argv=None):
    parser = argparse.ArgumentParser(prog="ptodsl.tilelib.serving.helper")
    parser.add_argument("--socket", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--op", required=True)
    parser.add_argument("--operand-specs", required=True)
    parser.add_argument("--context-attrs", default=None)
    args = parser.parse_args(argv)

    try:
        operand_specs = json.loads(args.operand_specs)
        context_attrs = json.loads(args.context_attrs) if args.context_attrs else {}
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Error: invalid JSON input: {exc}\n")
        sys.exit(1)

    try:
        mlir_text = DaemonClient(args.socket).instantiate(
            args.target, args.op, operand_specs, context_attrs
        )
    except (DaemonError, OSError) as exc:
        sys.stderr.write(f"Error: daemon RPC failed: {exc}\n")
        sys.exit(1)

    sys.stdout.write(mlir_text)


if __name__ == "__main__":
    main()
