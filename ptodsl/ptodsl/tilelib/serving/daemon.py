# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""TileLib daemon: a drop-in replacement for ``tilelang_dsl.daemon``.

Same socket protocol + ``instantiate`` RPC as the legacy daemon (see
docs_for_ai/ptodsl_tilelib_migration_plan.md §"daemon contract"), so the C++ side can be
pointed here with only a module-name change. Translates the ExpandTileOp ``operand_specs``
JSON into ``TileSpec``s, selects a registered template, and renders via the ptodsl engine.

CLI (matches the legacy daemon, spawned by tools/ptoas/TilelangDaemon.cpp):

    python3 -m ptodsl.tilelib.serving.daemon --socket <path> --template-dir <dir> [--max-entries N]
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import socketserver
import threading

from .wire import recv_message, send_message
from ..metadata import ScalarType, TileSpec
from .. import registry as _registry


def _build_tile_specs(descriptor, operand_specs: list) -> dict:
    """Zip the positional ExpandTileOp operand_specs onto the template's parameter names."""
    tile_specs = {}
    for name, spec in zip(descriptor.param_names, operand_specs):
        if spec.get("kind") != "tile":
            # MVP: tadd-family is all-tile. Non-tile operands (view/scalar) arrive once
            # those ops are ported; they don't contribute a TileSpec here.
            continue
        config = spec.get("config") or {}
        valid_shape = spec.get("valid_shape")
        tile_specs[name] = TileSpec(
            shape=tuple(spec["shape"]),
            dtype=ScalarType(spec["dtype"]),
            memory_space=spec.get("memory_space", "ub"),
            valid_shape=tuple(valid_shape) if valid_shape else None,
            b_layout=config.get("b_layout", "row_major"),
            s_layout=config.get("s_layout", "none_box"),
        )
    return tile_specs


def render_request(target: str, op: str, operand_specs: list, context_attrs: dict | None = None) -> str:
    """Select + render a registered template for one ExpandTileOp request -> MLIR text."""
    # Importing the templates package registers every template (decorator side effect).
    from .. import templates  # noqa: F401

    candidates = _registry.default_registry().lookup(op, target)
    if not candidates:
        raise _registry.NoMatchingTemplate(f"no template for op={op!r} target={target!r}")

    # Versions of one op share parameter order; use any candidate to map operands -> names.
    tile_specs = _build_tile_specs(candidates[0], operand_specs)
    descriptor = _registry.select(op, target, tile_specs, context_attrs)
    return descriptor.specialize(**tile_specs).mlir_text()


class TileLibDaemonServer(socketserver.ThreadingUnixStreamServer):
    """Threaded Unix-socket server speaking the ExpandTileOp RPC, with an instance cache."""

    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, socket_path: str, max_entries: int = 1000):
        super().__init__(socket_path, _Handler)
        self._cache: dict[str, str] = {}
        self._cache_lock = threading.Lock()
        self._max_entries = max_entries
        self.stats = {"hits": 0, "misses": 0, "evictions": 0}

    def dispatch(self, request: dict) -> dict:
        method = request.get("method")
        params = request.get("params") or {}
        try:
            if method == "instantiate":
                return {"success": True, "result": self._instantiate(**params)}
            if method == "ping":
                return {"success": True, "result": "pong"}
            if method == "get_stats":
                return {"success": True, "result": dict(self.stats, entries=len(self._cache))}
            if method == "clear":
                with self._cache_lock:
                    self._cache.clear()
                return {"success": True, "result": {"cleared": True}}
            return {"success": False, "error": f"unknown method {method!r}"}
        except Exception as exc:  # report rendering/selection failures back over RPC
            return {"success": False, "error": f"{type(exc).__name__}: {exc}"}

    def _instantiate(self, target, op, operand_specs, context_attrs=None):
        key = json.dumps(
            {"target": target, "op": op, "operand_specs": operand_specs, "context_attrs": context_attrs},
            sort_keys=True,
        )
        with self._cache_lock:
            cached = self._cache.get(key)
        if cached is not None:
            self.stats["hits"] += 1
            return cached

        self.stats["misses"] += 1
        mlir_text = render_request(target, op, operand_specs, context_attrs)

        with self._cache_lock:
            if len(self._cache) >= self._max_entries:
                self._cache.pop(next(iter(self._cache)))
                self.stats["evictions"] += 1
            self._cache[key] = mlir_text
        return mlir_text


class _Handler(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            request = recv_message(self.request)
        except (ConnectionError, ValueError):
            return
        send_message(self.request, self.server.dispatch(request))


def _parse_args(argv):
    parser = argparse.ArgumentParser(prog="ptodsl.tilelib.serving.daemon")
    parser.add_argument("--socket", required=True)
    parser.add_argument("--template-dir", default=None,
                        help="accepted for CLI compatibility; ptodsl templates are in-package")
    parser.add_argument("--max-entries", type=int, default=1000)
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args(argv)


def main(argv=None):
    args = _parse_args(argv)

    if os.path.exists(args.socket):
        os.unlink(args.socket)

    server = TileLibDaemonServer(args.socket, max_entries=args.max_entries)
    stop = threading.Event()

    def _shutdown(*_):
        stop.set()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    if args.verbose:
        print(f"ptodsl tilelib daemon listening on {args.socket}", flush=True)

    try:
        stop.wait()
    finally:
        server.shutdown()
        server.server_close()
        if os.path.exists(args.socket):
            os.unlink(args.socket)


if __name__ == "__main__":
    main()


__all__ = ["TileLibDaemonServer", "render_request", "main"]
