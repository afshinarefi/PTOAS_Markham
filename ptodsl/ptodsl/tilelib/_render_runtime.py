# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""
TileLib render runtime.

Traces a tilelang-style template body into a standalone ``func.func`` whose MLIR is on
par with the legacy tilelang-dsl render (``tile_buf_addr`` -> memref, ``memref.subview``,
``pto.vlds/vadd/vsts``, dynamic ``pto.tile_valid_rows/cols``). The body emitters are NOT
reimplemented here: tile slicing / valid-shape / mask / vector ops route through the
existing ptodsl engine (``_surface_values`` / ``_ops``, via :mod:`author`). This module
owns only the entry tile_buf typing, the golden-shaped module/func container, and thin
loop wrappers that keep all values engine-native.
"""

from __future__ import annotations

import inspect

from .metadata import TileSpec, scalar_descriptor
from .._bootstrap import make_context
from .._surface_types import Tile
from .._surface_values import (
    TileValue,
    _coerce_index_value,
    unwrap_surface_value,
    wrap_surface_value,
)
from .._tracing import KernelModuleSpec, ModuleStyle, TracingRuntime
from .._tracing.active import activate_runtime, activate_session
from .._types import _resolve

from mlir.dialects import func, scf
from mlir.ir import Attribute, InsertionPoint, Location, Module, StringAttr, UnitAttr


# ── tile handle handed to the template body ────────────────────────────────────────

class _TemplateTile(TileValue):
    """Engine ``TileValue`` with the template-author alias ``element_type`` and forced
    dynamic ``valid_shape`` (emit ``pto.tile_valid_rows/cols`` rather than folding the
    static ``v_row/v_col`` carried in the tile_buf type).

    Metadata (shape/dtype/memory_space) is supplied from the ``TileSpec`` because a raw
    entry-block ``tile_buf`` type is not introspectable by ``parse_tile_type_metadata``;
    supplying it explicitly takes the fast path in ``infer_memref_type_from_surface_value``.
    """

    def __init__(self, value, spec: TileSpec):
        elem = _resolve(scalar_descriptor(spec.dtype))
        super().__init__(
            value,
            shape=tuple(spec.shape),
            physical_shape=tuple(spec.shape),
            dtype=elem,
            memory_space=spec.memory_space,
            valid_shape=None,
        )
        # Force the dynamic valid-shape ops to match the tilelang render.
        self.static_valid_shape = None
        self._valid_shape._cache.clear()

    @property
    def element_type(self):
        return self.dtype


# ── loop authoring (engine-native values) ───────────────────────────────────────────

class _StateView:
    def __init__(self, names, values):
        self._values = dict(zip(names, values))

    def __getattr__(self, name):
        try:
            return self._values[name]
        except KeyError as exc:
            raise AttributeError(name) from exc


class _LoopHandle:
    def __init__(self, for_op, state_names, inner_iter_args):
        self.for_op = for_op
        self.iv = wrap_surface_value(for_op.induction_variable)
        self._state_names = tuple(state_names)
        self._inner = tuple(inner_iter_args)
        self.state = _StateView(self._state_names, [wrap_surface_value(a) for a in self._inner])
        self.yielded = False

    def yield_state(self, **kwargs):
        if not self._state_names:
            raise RuntimeError("yield_state(...) requires for_(..., state={...})")
        missing = [n for n in self._state_names if n not in kwargs]
        extra = [n for n in kwargs if n not in self._state_names]
        if missing or extra:
            raise RuntimeError(f"yield_state names must match state exactly; missing={missing} extra={extra}")
        ordered = [unwrap_surface_value(kwargs[n]) for n in self._state_names]
        scf.YieldOp(ordered)
        self.yielded = True


class _ForCM:
    def __init__(self, trace, start, stop, step, state):
        self._trace = trace
        self._start = start
        self._stop = stop
        self._step = step
        self._state = tuple(state.items()) if state else ()
        self._handle = None
        self._ip = None

    def __enter__(self):
        start = _coerce_index_value(self._start)
        stop = _coerce_index_value(self._stop)
        step = _coerce_index_value(self._step)
        inits = [unwrap_surface_value(v) for _, v in self._state]
        for_op = scf.ForOp(start, stop, step, inits if inits else None)
        self._ip = InsertionPoint(for_op.body)
        self._ip.__enter__()
        state_names = tuple(n for n, _ in self._state)
        self._handle = _LoopHandle(for_op, state_names, for_op.inner_iter_args)
        self._trace._loop_stack.append(self._handle)
        return self._handle if state_names else self._handle.iv

    def __exit__(self, exc_type, exc, tb):
        handle = self._trace._loop_stack.pop()
        if exc_type is None:
            if handle._state_names and not handle.yielded:
                raise RuntimeError("for_(..., state=...) requires an explicit loop.yield_state(...)")
            if not handle._state_names:
                scf.YieldOp([])
        self._ip.__exit__(exc_type, exc, tb)


# ── tracing runtime ────────────────────────────────────────────────────────────────

class _TemplateTrace(TracingRuntime):
    def __init__(self, descriptor, tile_specs: dict):
        super().__init__(
            KernelModuleSpec(
                function_name=descriptor.name,
                target_arch=descriptor.target,
                kernel_kind="vector",
                mode="auto",
                module_style=ModuleStyle.NESTED,
                source_file=inspect.getsourcefile(descriptor.py_fn) or inspect.getfile(descriptor.py_fn),
                source_line=getattr(descriptor.py_fn.__code__, "co_firstlineno", None),
            )
        )
        self.descriptor = descriptor
        self.tile_specs = tile_specs
        self._loop_stack: list = []
        self._ordered_specs: list = []
        self._signature_parameters = tuple(inspect.signature(descriptor.py_fn).parameters.items())

    def compute_argument_types(self):
        arg_types = []
        ordered = []
        for param_name, param in self._signature_parameters:
            if not _is_tile_annotation(param.annotation):
                raise TypeError(
                    f"tile-template parameters must be annotated Tile; {param_name!r} is {param.annotation!r}"
                )
            spec = self.tile_specs.get(param_name)
            if spec is None:
                raise ValueError(f"missing TileSpec for parameter {param_name!r}")
            ordered.append((param_name, spec))
            arg_types.append(spec.mlir_type())
        self._ordered_specs = ordered
        return arg_types

    def bind_entry_arguments(self, entry_arguments):
        return tuple(
            _TemplateTile(arg, spec) for arg, (_, spec) in zip(entry_arguments, self._ordered_specs)
        )

    def trace_entry(self, *args):
        self.descriptor.py_fn(*args)

    def validate_trace_state(self):
        if self._loop_stack:
            raise RuntimeError("tile-template trace exited with an open scf.for block")

    # Author-facing loop entry (called via require_active_runtime from author.for_).
    def for_(self, start, stop, *, step, state=None):
        return _ForCM(self, start, stop, step, state)

    # Custom golden-shaped container: single module(target_arch) + func(instance, kernel_kind).
    def build_module(self):
        ctx = make_context()
        with ctx, Location.unknown():
            arg_types = list(self.compute_argument_types())
            module, ir_fn = self._create_instance_module(arg_types)
            session = self.create_session(module, ir_fn)
            entry = ir_fn.add_entry_block()
            with InsertionPoint(entry), activate_runtime(self), activate_session(session):
                self.initialize_session(session, entry)
                args = self.bind_entry_arguments(entry.arguments)
                self.trace_entry(*args)
                self.validate_trace_state()
                self.emit_return()
                self.finalize_session(session)
                session.validate_final_state()
            self.verify_module(module)
            return module

    def _create_instance_module(self, arg_types):
        module = Module.create()
        module.operation.attributes["pto.target_arch"] = StringAttr.get(self.descriptor.target)
        with InsertionPoint(module.body):
            fn_ty = func.FunctionType.get(arg_types, [])
            ir_fn = func.FuncOp(self.descriptor.name, fn_ty)
            ir_fn.attributes["pto.tilelang.instance"] = UnitAttr.get()
            ir_fn.attributes["pto.kernel_kind"] = Attribute.parse("#pto.kernel_kind<vector>")
        return module, ir_fn


def _is_tile_annotation(annotation) -> bool:
    if annotation is Tile:
        return True
    if isinstance(annotation, str):
        return annotation == "Tile" or annotation.endswith(".Tile")
    return getattr(annotation, "__name__", None) == "Tile"


__all__ = ["_TemplateTrace", "_TemplateTile"]
