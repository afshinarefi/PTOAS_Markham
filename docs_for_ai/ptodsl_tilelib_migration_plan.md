# PTODSL TileLib Migration Plan (consolidated)

> **Single source of truth** for #739 Goal 1 (one DSL) + Goal 2 (compiler-visible version
> selection). Supersedes the former `06-ptodsl-tilelib-migration-plan.md` and
> `ptodsl_tilelang_expandtileop_summary.md`. Background: [00-overview.md](00-overview.md),
> [01](01-compiler-pipeline.md), [02](02-ptodsl-frontend.md), [03](03-tilelang-dsl-and-expandtileop.md),
> [05](05-pto-isa-library.md). **Status: PLAN — not implemented in code yet.**

---

## 1. Thesis (read this first)

PTOAS has **two Python DSLs** doing overlapping work: `ptodsl` (the user-facing frontend that
emits `.pto`) and `tilelang-dsl` (the compiler-internal template engine that `ExpandTileOp` calls
to generate a TileOp's vector/cube body). #739 collapses them into one: **`ptodsl` plays both
roles.**

The key finding that shapes this whole plan: **ptodsl already contains the hard part — the
transformation engine that lowers a tile body to the right MLIR abstraction.** What ptodsl lacks is
the *library layer* around it (catalog, dispatcher, server). So the work is **not** "rewrite the
templates" and **not** "copy tilelang into ptodsl." It is:

> Build a **thin TileLib layer** (`ptodsl/ptodsl/tilelib/`) that hosts the templates and
> **ports only the catalog/dispatch/serving *logic*** from tilelang, while **calling ptodsl's
> existing engine** for all MLIR rendering. One engine, not two.

Copying tilelang's renderer/AST files wholesale would re-import a second engine — the exact
duplication #739 exists to kill. We port *logic*, not files, for the missing layer.

---

## 2. The contract

- **Input**: a template that looks like today's `lib/TileOps/*_template.py` (TileLang-style
  `tile[row, col:]` body, `for row in range(...)` control flow). The only change is the
  **decorator + metadata**; the body is near-verbatim.
- **Output**: MLIR at the **same abstraction level** as tilelang-dsl's render, so `ExpandTileOp`
  ingests it identically. "Same level" = same ops/structure/semantics, **not** byte-identical
  (SSA names, `tmp_*` numbering will differ).

### The golden reference

`tadd_template.mlir` in the repo root is the target output, regenerable from
[lib/TileOps/tadd_template.py](../lib/TileOps/tadd_template.py) (see §9 for the command). Every
rendered template is judged against output of this shape:

```mlir
func.func @template_tadd(%arg0: !pto.tile_buf<…>, …)
    attributes { pto.tilelang.instance, pto.kernel_kind = #pto.kernel_kind<vector> } {
  %tmp_0 = pto.tile_buf_addr %arg0 : !pto.tile_buf<…> -> memref<8x64xf32, #pto.address_space<vec>>
  %valid_rows = pto.tile_valid_rows %arg2 : … -> index
  %valid_cols = pto.tile_valid_cols %arg2 : … -> index
  scf.for %row = %c0 to %valid_rows step %c1 {
    scf.for %col = %c0 to %valid_cols step %c64 iter_args(%remained = …) -> (i32) {
      %mask, %rem = pto.plt_b32 %remained : i32 -> !pto.mask<b32>, i32
      %sub = memref.subview %tmp_0[%row, %col] [%c1, %sz] [%c1, %c1] : … -> memref<?x?xf32, strided<…>, vec>
      %lhs = pto.vlds %sub[%c0] : … -> !pto.vreg<64xf32>
      … pto.vadd … pto.vsts …
    }
  }
}
```

Critically: `pto.tile_buf_addr` → **memref** (not a ptr), `tile[row,col:]` → **`memref.subview`**,
`valid_shape` → **dynamic** `pto.tile_valid_rows/cols`, masks via `pto.plt_b32`. **Not** bare
`pto.castptr`/`pto.addptr` — that bare-pointer style (the `tadd_dsl.py` demo) loses tile metadata
and is explicitly rejected by the team because it breaks alias/fusion/load-store analysis.

---

## 3. Gap analysis — what to reuse vs. what to port

tilelang's template→MLIR pipeline is ~10 stages. Mapping each to ptodsl:

| Stage | tilelang | ptodsl | Action |
|---|---|---|---|
| `for…range` → MLIR loops | `semantic.py`/`frontend_ast.py` | ✅ `_ast_rewrite.py` (post-PR #769) | **reuse** |
| `tile[row,col:]` → `memref.subview` | `lowering.py` `_materialize_rank2_tile_subview` | ✅ `_surface_values.py` `_build_tile_slice_view` (~831), `_emit_tile_memref` (~878) | **reuse** |
| dynamic `valid_shape` → `tile_valid_rows/cols` | `semantic.py`/`lowering.py` | ✅ `_surface_values.py` (~397), `_ops.py` | **reuse** |
| `make_mask` → `plt_b{8,16,32}` | `lowering.py` (~1791) | ✅ `_ops.py` make_mask | **reuse** |
| `vlds/vadd/vsts` → MLIR | `lowering.py` (~1822+) | ✅ `_ops.py` | **reuse** |
| decorator + registry | `kernel.py` `@vkernel` + `KernelRegistry` | ❌ none | **port logic** |
| dtype-signature matching | `kernel.py` `_match_descriptor_dtype_signature` | ❌ none | **port logic** |
| constraint predicates | `kernel.py` `_evaluate_constraints` | ❌ none | **port logic** |
| priority selection | `kernel.py` `select_kernel` / `daemon_core.py` | ❌ none | **port logic** |
| daemon / RPC + cache | `daemon_core.py`, `daemon.py`, `stable_key.py` | ❌ none | **port logic** |

**The split:** the 5 *rendering* stages already exist in ptodsl (call them). The 5 *library*
stages (catalog/match/select/serve) are missing — port their **engine-agnostic logic** into the new
layer and point the "render the winner" step at ptodsl's engine.

> Line numbers drift — treat as "start here," grep the symbol if moved.

### One existing prototype, at the wrong abstraction

`ptodsl/ptodsl/_tile_template_tracing.py` is an **unwired prototype** (no importers, 0 tests, not
exported). It already emits a *standalone func with `!pto.tile_buf` params* (the right module shape,
`ModuleStyle.NESTED`), but its body emitters are **too low-level**: `ensure_tile_ptr` +
`materialize_linear_offset` produce ptr+offset instead of `memref.subview`, `valid_shape` is static,
and `plt_b32` may raise `NotImplementedError`. **We keep its func-shaping and fix its three emitters
to call the engine** (this becomes `tilelib/_render_runtime.py`).

---

## 4. File / folder design

```
ptodsl/ptodsl/tilelib/                  ← the entire new addition
├── __init__.py              public surface: tile_template, registry, render_best, dtypes
├── metadata.py              TemplateMetadata: op/target/dtypes/layouts/memory_spaces/
│                            rank/requires (hard) + priority/fusible/tags (hints)
├── constraints.py           constraint-predicate vocabulary + evaluator
├── decorator.py             @tile_template — binds fn+metadata → descriptor, registers it
├── registry.py              TileTemplateRegistry: register / lookup(op,target) /
│                            select(op,target,operand_specs,context_attrs)
├── author.py                author-facing op namespace (vlds/vadd/vsts/make_mask/get_lanes/
│                            for_/Tile/TileSpec/f32…) — thin re-exports that route to engine
├── _render_runtime.py       the FIXED tile-template tracer (today's _tile_template_tracing.py,
│                            re-pointed at _surface_values / _ops / _ast_rewrite)
├── render.py                render(descriptor, operand_specs, ctx) → MLIR text;
│                            render_best(...) = select+render; + `python -m …tilelib.render` CLI
├── serving/                 ← Phase 5 (ExpandTileOp hookup); stub until then
│   ├── __init__.py
│   ├── cache.py             InstanceCache + stable-key (port tilelang stable_key)
│   ├── daemon.py            warm server, the entry the C++ side spawns
│   └── client.py
└── templates/               ported template library (bodies ≈ verbatim)
    ├── __init__.py          imports a5/* so decorators self-register on import
    └── a5/
        ├── __init__.py
        ├── tadd.py
        ├── tsub.py
        └── …                (the ~85 lib/TileOps families, ported incrementally)
```

Tests/examples in existing locations (not under the package):
```
ptodsl/tests/test_tilelib_render.py     round-trip + golden-parity (tadd first)
ptodsl/tests/test_tilelib_select.py     registry/constraint/priority selection
ptodsl/examples/tilelib_render.py        standalone render demo (parallels render_template_mlir.py)
```

### Responsibility & origin

| File | Responsibility | Origin |
|---|---|---|
| `metadata.py` | Pure data: hard constraints + selection hints | **port** field set from `VKernelDescriptor` |
| `constraints.py` | Reusable predicates (`is_contiguous`, `is_row_major`, `dtype_in`, `valid_cols_multiple_of_lanes`…) + evaluator | **port** `_evaluate_constraints` logic (engine-agnostic) |
| `decorator.py` | `@tile_template(op=, target=, dtypes=, …)` → wraps fn + metadata, registers | **port** `@vkernel` shape |
| `registry.py` | Catalog + dispatcher: filter op→target→dtype-sig→constraints, tie-break by priority | **port** `select_kernel`/`daemon_core` filtering — *the* core ported logic |
| `author.py` | The `pto.*` names a body calls; re-exports that route to ptodsl engine | **reuse** `_ops`, `_surface_values` |
| `_render_runtime.py` | Trace chosen template → standalone `func.func` w/ `!pto.tile_buf` params + instance attr | fixed `_tile_template_tracing.py` |
| `render.py` | `render_best` = select → render → MLIR text; CLI | glue |
| `serving/` | Warm daemon + instance cache; RPC endpoint `ExpandTileOp` calls | **port** tilelang daemon, swap responder to call `render.py` |
| `templates/a5/*.py` | Op bodies, near-verbatim from `lib/TileOps`; only import + decorator change | bodies ≈ copy |

### Dependency direction (one-way, no cycles)

```
templates/a5/*.py
   │ import: tile_template (decorator) + author.py ops
   ▼
decorator.py ──registers──▶ registry.py ◀──uses── metadata.py, constraints.py
                                  │
render.py ── select() ────────────┘
   │ render via
   ▼
_render_runtime.py ──calls──▶ ptodsl engine ( _ast_rewrite, _surface_values, _ops )   ← REUSE
   ▲
serving/ ── wraps render.py (+ cache.py)  ◀── C++ ExpandTileOp (RPC)
```

Only `_render_runtime.py` (and `author.py` re-exports) touch MLIR emission, and they **delegate
into the existing engine**. Everything above is pure Python catalog/dispatch — no second renderer.

---

## 5. Version selection (Goal 2)

**Today:** tilelang has a real selector — `select_kernel` filters by target/op/param-kinds/
dtype-signature/constraints and tie-breaks by `priority` (`daemon_core.py`/`kernel.py`). It is
**legality + priority**, not a cost model; typically one template per op. ptodsl has none of it.

**Target:** lift the pto-isa-hidden perf variants (1D/2D, post-update, tail — see [05](05-pto-isa-library.md))
up to *this* layer as **multiple constraint-tagged versions per op**, selected among the *legal*
ones. Two constraint flavors, both already present in `lib/TileOps`:
- **algorithm-legality** (e.g. `tcolmax` needs row-major + 1-row output) — wrong otherwise;
- **optimization-applicability** (e.g. a `tadd_1d` version needs contiguity) — correct but only
  valid under that condition.

**Selection order:** filter by hard constraints → one legal → use it → several → rank by priority
(deterministic first). Add a cost model **only later**, when multiple versions are simultaneously
legal *and* a wrong pick measurably hurts.

**Note on the seam:** a fully type-erased template is not achievable — dtype is concrete (drives
`vreg` lanes + `plt_b` width) and memory space is in the type. Render **parameterized by the
SpecKey**, keep **valid_shape dynamic** (and physical dims dynamic where the op allows — elementwise
yes; DMA-stride/matmul need static), then let MLIR canonicalization fold concrete sizes downstream.

---

## 6. Phased plan

### Phase 0 — Verify & spike *(see §9 checklist)*
Confirm the reuse assumptions (engine emitters, func shape, attribute name, bindings) and regenerate
the golden. No large code.

### Phase 1 — Fix the renderer abstraction *(highest risk; do first)*
In `_render_runtime.py` (from `_tile_template_tracing.py`):
1. Emit `pto.tile_buf_addr` → **memref** (not ptr); route `vlds`/`vsts` through
   `_surface_values._build_tile_slice_view` so they consume `memref.subview` + `%c0`. Delete
   `materialize_linear_offset`/`_materialize_row_offset`/ptr cache.
2. Make `valid_shape` **dynamic** — emit `pto.tile_valid_rows/cols`, so `scf.for` bounds are dynamic.
3. Fix `plt_b32` (binding present → wire; absent → add it; `tadd` needs `plt_b32`).
4. Author the spike `tadd` body **without `vecscope`** (the golden has none) and diff vs the golden.

### Phase 2 — Catalog layer (minimum to author)
`metadata.py`, `decorator.py`, `author.py`. Export `tile_template` from `tilelib/__init__.py`.

### Phase 3 — Registry + selector
`registry.py`: `register` + `select` (op/target → dtype-signature → constraints → priority).
`constraints.py` starts as a stub (returns legal) until a second real variant exists.

### Phase 4 — Port the template library
Mechanically port `lib/TileOps/*_template.py` (~85) into `templates/a5/`: bodies near-verbatim,
keep per-op legality constraints (`tcolmax` row-major+1-row; `tnot` int-only; `tcvt` pair whitelist).
Order: elementwise (`tadd/tsub/tmul/…`) → reductions (`tcolmax/…`) → `tcvt`/`tsel`/`tmatmul`.

### Phase 5 — Wire to `ExpandTileOp`
Stand up `serving/daemon.py` reusing the **existing C++ RPC contract** (`ExpandTileOp.cpp` builds
`SpecKey` → operand-specs/context-attrs JSON); swap the Python responder to call `render.py`. C++
side barely changes. Reuse `stable_key`-style cache (`cache.py`). Gate behind a flag/target initially.

### Phase 6 — Cutover & retire tilelang-dsl
Parity-test ptodsl vs tilelang MLIR per op (instance cache makes A/B easy). Flip the `ExpandTileOp`
default to ptodsl; delete `tilelang-dsl` + `lib/TileOps` once green.

---

## 7. MVP (build first, in this order)

Prove the loop with `tadd` before any breadth:
1. `_render_runtime.py` — Phase 1 fixes (subview + dynamic valid_shape + plt_b32).
2. `metadata.py`, `decorator.py`, `author.py`.
3. `templates/a5/tadd.py` — one real template **plus a duplicate at higher `priority`** to exercise
   selection (proves multi-version registration even with identical bodies).
4. `registry.py` — `register` + `select`.
5. `render.py` + CLI; `ptodsl/tests/test_tilelib_render.py` diffing against `tadd_template.mlir`.

Expected: selecting `pto.tadd`/`a5` returns the priority-10 template; rendered MLIR matches the
golden's abstraction. Example render command:

```bash
python3 -m ptodsl.tilelib.render --op pto.tadd --target a5 \
  --tile dst=8x64@ub:f32 --tile src0=8x64@ub:f32 --tile src1=8x64@ub:f32 \
  -o /tmp/ptodsl_tadd_tilelib.mlir
```

`constraints.py` stays a stub and `serving/` stays empty until their phases.

---

## 8. Open decisions

1. **Decorator name** — `@tile_template` (recommended) vs `@op_template`/`@tilelib_template`.
2. **Module home** — **settled: `ptodsl/ptodsl/tilelib/`** (not `ptodsl.pto.tilelib`).
3. **Instance attribute** — keep `pto.tilelang.instance` (zero C++ change) vs introduce
   `pto.tilelib.instance`. *Recommend keep for MVP; rename in cutover.*
4. **Dynamic vs specialized per SpecKey** — valid_shape: dynamic. Physical shape: dynamic where the
   op allows (elementwise) / static where required (DMA-stride, matmul).
5. **`_render_runtime.py` location** — relocate the tracer under `tilelib/` (its only consumer) vs
   leave at package root for the MVP to reduce churn. *Recommend relocate after Phase 1 lands.*
6. **Constraint vocabulary** — standardize predicates (dtype/layout/contiguity/memspace/valid-shape
   rank-parity/fusion-context) so versions across ops declare them uniformly.
7. **Where `pto.simd/cube/simt` subkernels fit** as the TileOp→micro-instruction bridge (likely the
   cube/matmul templates use `@pto.cube` + `pto.mad`).
8. **Daemon vs in-process** — keep the warm-daemon model (cold Python per op is too slow).

---

## 9. Verification checklist (need help from a runner)

These confirm the reuse assumptions before/while building. Paste outputs back.

1. **Bindings present?** (decides whether Phase 1.3 is "wire" or "add a binding"):
   ```bash
   cd /home/mani/Desktop/PTOAS_Markham && python3 -c "from mlir.dialects import pto; \
   print({n: hasattr(pto,n) for n in ['PltB32Op','PltB16Op','PltB8Op','TileBufAddrOp','TileValidRowsOp','TileValidColsOp','VldsOp','VstsOp']})"
   ```
2. **Golden regenerable?** (use `runpy`; `lib/TileOps/math.py` shadows stdlib `math` on direct run):
   ```bash
   cd /home/mani/Desktop/PTOAS_Markham && python3 - <<'PY'
   import runpy, sys
   sys.argv = ["render_template_mlir.py","lib/TileOps/tadd_template.py",
     "--tile","dst=8x64@ub","--tile","src0=8x64@ub","--tile","src1=8x64@ub","-o","/tmp/tadd_golden.mlir"]
   runpy.run_path("lib/TileOps/render_template_mlir.py", run_name="__main__")
   PY
   diff /tmp/tadd_golden.mlir tadd_template.mlir && echo MATCHES
   ```
3. **`_TraceBuilder` func shape** — confirm it emits a standalone `func.func` with `!pto.tile_buf`
   params + `pto.kernel_kind` (and where to attach `pto.tilelang.instance`). Inspect/render
   `SpecializedTileTemplate(...).mlir_text()` for a trivial template.
4. **`@pto.jit` engine reachability** — confirm `_surface_values._build_tile_slice_view` /
   `_emit_tile_memref` / dynamic `valid_shape` / `_ops.make_mask` are callable from a NESTED-style
   trace (so `_render_runtime.py` can call them directly).

---

## 10. Risks

- **Abstraction regression** — the prototype's ptr/offset output is below target; must route through
  subview. (Primary risk; Phase 1 retires it.)
- **Re-importing a second engine** — do **not** `cp` tilelang's `kernel.py`/`lowering.py`; port the
  selection *logic* only and call ptodsl's renderer.
- **Template-port volume** — ~85 templates, each needs light adaptation + a regression test.
- **Binding gaps** — `plt_b*` is one known; expect more (mask/cube/DMA ops) as ports progress.
- **Parity** — ptodsl output must match tilelang semantics op-by-op before cutover.
- **Don't reimplement pto-isa tuning blindly** — for unfused EmitC-backend ops, pto-isa stays the
  better path; the win is on the VPTO/expansion path and across fusion (see [05](05-pto-isa-library.md)).

---

## 11. Cross-layer sync (when Phase 5 lands)

Per `.claude/rules/cross-layer-sync.md`, wiring `ExpandTileOp` to ptodsl touches multiple layers —
keep in sync: C++ (`ExpandTileOp.cpp`, daemon manager), CLI (`tools/ptoas` flag if gated), Python
(`ptodsl/tilelib`), tests (`test/`), and these docs. New `.py`/source files must carry the CANN Open
Software License Agreement v2.0 header.
