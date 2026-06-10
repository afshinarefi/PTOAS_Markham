# 02 — `ptodsl` (the new Python frontend)

Location: `ptodsl/`. This is the **user-facing** DSL: a human writes a kernel in Python, it
traces the Python execution once, and emits PTO MLIR (`.pto`). It is the intended *single* DSL
foundation under #739 (see [00-overview.md](00-overview.md)) — but it does **not** yet plug into
the compiler-internal `ExpandTileOp` path; that integration is unbuilt.

Scale: ~11.3k LoC core, 26 core modules, 8 examples, 8 test suites (~4.4k LoC), 12-chapter user
guide (`ptodsl/docs/user_guide/`).

## 1. What you write — three authoring styles

### A. Tile-centric (`mode="auto"`, default)
Allocate tiles, partition GM views, compose with `pto.tile.*`:
```python
@pto.jit(mode="auto", target="a5")
def kernel(...):
    t = pto.alloc_tile(shape=[16, 64], dtype=pto.f32)
    pto.tile.load(partition, t)        # DMA GM→UB
    pto.tile.add(a, b, c)              # tile arithmetic
    pto.tile.store(t, partition)       # DMA UB→GM
```
`pto.tile.*` namespace (`_tile_namespace.py:18–152`): `load/store/mov`, `add/sub/mul/div/max/min`,
reductions (`rowsum/rowmax/colsum/...`), transcendentals (`exp/log/sqrt/rsqrt/relu`).
Example: `ptodsl/examples/tadd_launch.py`.

### B. Vector + tile (`mode="explicit"`)
Drop to explicit vector registers and pointers inside a `pto.simd()` region:
```python
with pto.simd():
    ptr = pto.castptr(addr, pto.ptr(pto.f32, "ub"))
    va  = pto.vlds(ptr, offset)
    vc  = pto.vadd(va, vb, mask)
    pto.vsts(vc, ptr, offset, mask)
```
Vector ops in `_ops.py:200–500` (`vlds/vsts/vldsx2`, `vadd/vsub/vmul/vmax`, bitwise, `vexp/vln/vsqrt`);
pointer ops `castptr`/`addptr` at `_ops.py:182–198`. Example: `ptodsl/examples/tadd_dsl.py`.

> Per the #739 design notes, this bare-pointer style is a **demo**, not the model for future
> TileLib templates — those should use the structured `tile[row, col:]` indexing (style A/§4).

### C. Raw MLIR bindings
Direct `mlir.dialects.pto` construction, no DSL sugar. Example: `ptodsl/examples/tadd_lowlevel.py`.

### Subkernels — `@pto.cube` / `@pto.simd` / `@pto.simt`
Defined in `_subkernels.py:29–100`. Hardware-bound compute scopes, usable as decorated functions
or context managers (inlined at call site):

| Subkernel | Hardware | Accesses | Data crossing boundary |
|-----------|----------|----------|------------------------|
| `@pto.cube` | matrix unit | LEFT/RIGHT/ACC/BIAS tiles + UB | UB tiles only |
| `@pto.simd` | vector unit | vector registers (vregs) | UB-backed tiles only (vregs may **not** escape) |
| `@pto.simt` | scalar PG | scalar regs, UB ptrs | UB tile scalars |

Boundary contracts are validated (`_subkernels.py:74–94`): no simd-in-simd, cube not callable from
simt, vreg escape rejected. Inline lowering emits `pto.section_cube` / `pto.section_vector`
(`_tracing/session.py:121–134`). These subkernels are the intended bridge between a TileOp and its
micro-instruction implementation in the #739 design.

## 2. How it works — tracing

`kernel.compile(**constexpr)` **executes the Python body once**, recording each op into an MLIR module.

- **Python constructs run at trace time**: `for i in range(4)` unrolls; a Python `if` folds;
  `alpha * x` bakes a constant.
- **`pto.*` constructs are recorded as IR**: `pto.for_(...)`→`scf.for`, `pto.if_(...)`→`scf.if`,
  `pto.vadd(...)`→`pto.vadd`.

Engine:
- `TracingRuntime` (`_tracing/runtime.py:22–131`) orchestrates: `compute_argument_types` →
  `create_session` → `trace_entry` → `validate_trace_state` → `emit_return`. Subclasses
  `SignatureTracingRuntime` (parses `@pto.jit` signature, binds constexprs) and `CallbackTracingRuntime`.
- `TraceSession` (`_tracing/session.py:46–160`) holds function/subkernel/carry-loop stacks and MLIR insertion points.
- `_tile_template_tracing.py` is a specialized tracer for the tile-template (TileLang-like) surface:
  `TileSpec`, `_TileSlice`, wrapper `_Value`/`_MaskValue`/`_VectorValue`.
- **Surface values** (`_surface_values.py`) wrap MLIR values with metadata: `TileValue`,
  `TensorViewValue`, `PartitionTensorViewValue`, `TileSliceValue`.
- Module layout (`_tracing/module_builder.py`): `FLAT_AICORE` (default — flat func w/ `pto.aicore`
  attr) or `NESTED`. Sets module attrs `pto.target_arch`, `pto.kernel_kind` (`vector`/`cube`), `pto.mode`.
- Compilation cache: `KernelCompiler` (`_kernel_compilation.py:52–93`) keys specializations on
  identity + constexpr bindings → `CompiledKernelHandle`.
- Launch: `_runtime/launch.py` ctypes-dispatches to a compiled `.so` (cached under `~/.cache/ptodsl/`);
  `_runtime/codegen.py` generates the C++ host wrapper.

## 3. Tile indexing `tile[row, col:]` (the structured-access path #739 wants)

Implemented in `_surface_values.py:799–876`:
- `tile[row, col:]` → `_materialize_tile_slice` → `_build_tile_slice_view` → emits
  `pto.TileBufAddrOp` (base memref) then **`memref.SubViewOp`** → wraps as `TileSliceValue`.
- ✅ supported: rank-2 `tile[row, col:]` (1D column view), rank-1 `tile[start:]`, static + dynamic
  offsets/sizes, element access `tile[row, col]` → `TileElementRef`.
- This is exactly the structured-tile-info-preserving lowering the migration design relies on
  (see [ptodsl_tilelib_migration_plan.md](ptodsl_tilelib_migration_plan.md)).

## 4. Current status

**✅ Works**
- `@pto.jit` auto + explicit modes; tile ops, vector ops, pointer ops, mask/predicate ops
  (`plt_b*`, `pset_b*`, `pand/por/pxor`, `ppack/punpack`).
- Control flow `pto.for_` / `pto.if_` + loop carry (`.carry()`).
- Tensor/partition views; `tile[row, col:]` → `memref.SubViewOp`.
- Subkernels `@pto.cube/@pto.simd/@pto.simt` (inline lowering + boundary checks).
- Constexpr specialization + caching; `pto.merge_jit_modules(*kernels)`.
- Data movement (`mte_gm_ub`, `mte_l1_l0a`, `mte_l0c_ub`, …), sync (`set_flag/wait_flag`, `pipe_barrier`).
- Both compile-only (emit + verify MLIR) and end-to-end launch (ctypes → `.so`, verified on msprof sim).

**⚠️ Partial / known limits**
- `tile[row, col:]` mask op in the **tile-template tracing path** raises `NotImplementedError`
  — `pto.PltB{8,16,32}Op` Python bindings missing (`_tile_template_tracing.py:607–609`).
  Workaround: explicit mode with direct `vlds`/`vsts`.
- **f16/bf16 runtime scalar launch marshaling** unsupported (`_runtime/launch.py:84–90`) — use f32/int
  scalars or tensorize.
- `pto.for_(..., iter_args=(...))` disabled — use `.carry()`.
- Tile shapes must be statically known at trace time (specialized per shape).

**❌ Not built**
- **Integration with `ExpandTileOp`** — `ptodsl` is *not* wired in as the TileLib the compiler calls.
  This is Goal 1 of #739 and is unstarted.
- Deprecated public surface (`pto.ukernel`, `pto.vecscope`, `pto.as_ptr`, `pto.vbrc_load`,
  `pto.vsts_1pt`) raises `unsupported_public_surface_error` (`pto.py:144–146`, `_diagnostics.py`).

**Tests** (`ptodsl/tests/`): `test_jit_compile.py` (~2.1k LoC, 50+ probes), `test_vector_cube_ops.py`,
`test_docs_as_test.py` (runs every user-guide code example), `test_jit_diagnostics.py`,
`test_subkernel_diagnostics.py`, `test_flash_attention_demo_compile.py`,
`test_pipe_surface_sample_compile.py`, `test_ptoas_frontend_verify.py` (frontend handoff to `ptoas`).
