# 06 — Plan: make `ptodsl` the TileLib for `ExpandTileOp`

> **Status: PLAN / not yet implemented.** This is the working plan to execute #739 Goal 1
> (one DSL) + Goal 2 (version selection). It supersedes nothing in code yet. Not pushed.
> Background: [00-overview.md](00-overview.md), [02](02-ptodsl-frontend.md),
> [03](03-tilelang-dsl-and-expandtileop.md), [05](05-pto-isa-library.md).

## 0. Baseline / git (done)

- `mani/test` already contains **all of `upstream/main`** (hw-native-sys `29a8af28`, dated
  2026-06-09 — the latest). `upstream/main` is a direct ancestor of `mani/test`. **No rebase
  needed.**
- `origin/main` (the afshinarefi fork, `26f5e93c`) is **65 commits behind** upstream — it is the
  stale ref, not us. Don't rebase onto it.
- Untracked `tadd_template.mlir` in the repo root is a scratch artifact (left alone).

## 1. The agreed flow (from the team)

1. **Copy the `lib/TileOps/*_template.py` templates into ptodsl** and register them as ptodsl
   templates.
2. **Transform a Python template → MLIR** *on demand*, when `ExpandTileOp` asks for that op
   (lazy, per-op).
3. **Instantiate** that MLIR for the concrete tile sizes/shapes/configs of the actual op.
4. Output MLIR at the **structured `memref.subview` level** (like the `tadd_template.mlir` we
   rendered), **not** the raw ptr/offset level of `tadd_lowlevel.py`.
5. Version selection is in scope and **should happen at this layer** (but is a later phase).

The good news: **ptodsl already has a prototype of steps 1–3** (`_tile_template_tracing.py`).
The work is to fix it to the right abstraction level, add dynamic shapes, add the
registry/selector, fill the mask-op gap, and wire it to `ExpandTileOp`.

## 2. What ptodsl already HAS vs LACKS (audited)

ptodsl ships an **unwired prototype**: `ptodsl/ptodsl/_tile_template_tracing.py`.

| Capability | ptodsl tile-template path | tilelang-dsl | Evidence |
|---|---|---|---|
| Template decorator | ✅ `@tile_template(target=, op=, name=)` | ✅ `@vkernel(...)` | `_tile_template_tracing.py:553–568` |
| `.specialize(**TileSpec)` → standalone `func.func` | ✅ `SpecializedTileTemplate` via `_TraceBuilder` | ✅ `specialize()` + daemon | `_tile_template_tracing.py:531–550, 284–338` |
| Emits `vlds/vadd/vsts/make_mask` over `tile[row,col:]` | ✅ | ✅ | `_tile_template_tracing.py:616–644` |
| **Access level** | ⚠️ **ptr + linear offset** (`ensure_tile_ptr` + `materialize_linear_offset`) — **too low** | ✅ `memref.subview` | `_tile_template_tracing.py:620–623, 642–644` |
| **Dynamic / tail valid_shape** | ❌ static only — `valid_shape` returns `index_const(spec.shape)`; `_validate_static_bound` rejects dynamic | ✅ runtime `pto.tile_valid_rows/cols` + `scf.for` | `_tile_template_tracing.py:167–171, 191–192` |
| Authoring mechanism | execution **tracing** (must use `pto.for_`, `with vecscope()`) | **AST** rendering (plain `for … range`) | `_tracing/runtime.py`; `frontend_ast.py`→`pybind_renderer.py` |
| Registry of templates | ❌ none | ✅ `KernelRegistry` | tilelang `kernel.py:1507,1515` |
| dtype-signature matching | ❌ | ✅ `dtypes=[...]` + `_dtype_matches` | tilelang `daemon_core.py:175,398` |
| Constraint predicates | ❌ | ✅ `constraints=[...]` | tilelang `kernel.py:998` |
| Priority selection | ❌ | ✅ `select_kernel` + priority | tilelang `daemon_core.py:190` |
| Exported / tested | ❌ not in `pto.py`/`__init__.py`, **0 tests** | ✅ public + tests | grep: no refs |
| Memory space / rank | ⚠️ `ub` + rank-2 only | broader | `_tile_template_tracing.py:91–96` |
| `plt_b{8,16,32}` mask op | ⚠️ `NotImplementedError` if binding missing | AST emits it | `_tile_template_tracing.py:605–609` |
| Daemon / C++ ExpandTileOp hook | ❌ none | ✅ `TilelangDaemon` + `daemon_core` | `tools/ptoas/TilelangDaemon.cpp` |

**Two abstraction notes that matter:**
- ptodsl's **main** `@pto.jit` surface (`_surface_values.py`) *already* lowers `tile[row,col:]` →
  `memref.SubViewOp` **and** supports runtime `pto.tile_valid_rows/cols`. So the subview-level +
  dynamic-shape machinery exists in ptodsl — it's just **not used by the tile-template path**,
  which reimplemented a lower-level variant. Fixing the tile-template path largely means routing
  it through the existing surface-value lowering, not inventing new lowering.
- "Copy-paste templates" is **not literal**: tilelang templates use Python `for … in range(...)`
  (AST-rewritten); ptodsl tracing needs `pto.for_(...)` / `with pto.vecscope()`. Each template
  needs a mechanical rewrite (loops, mask, indexing), not a `cp`.

## 3. Version selection — current state & target

**Today:**
- **tilelang-dsl HAS a real selector** — `select_kernel(target, op, operand_types, context_attrs,
  registry)` over a `KernelRegistry`, filtering by target/op/param-kinds/dtype-signature/constraints
  and tie-breaking by `priority` (`daemon_core.py:163–195`, `kernel.py:1507+`). It is
  **legality + priority**, not a cost model, and today there's typically **one template per op**.
- **ptoas `ExpandTileOp` delegates** selection to that matcher via the daemon (it builds the
  `SpecKey`, the daemon selects).
- **ptodsl has NONE of it.**

**Target (this is #739 Goal 2):** lift the pto-isa-hidden perf variants (1D/2D, post-update,
tail — [05](05-pto-isa-library.md)) up to *this* layer as **multiple constraint-tagged versions
per op**, and select among the *legal/applicable* ones. Two flavors of constraint, both already
seen in `lib/TileOps`:
- **algorithm-legality** (e.g. `tcolmax` needs row-major + 1-row output) — wrong otherwise;
- **optimization-applicability** (e.g. a `tadd_1d` version needs contiguity) — correct but only
  valid under that condition.

Selection order: filter by hard constraints → if one legal version, use it → if several, rank by
priority (deterministic first), add a cost model only later.

## 4. Target architecture

```
ExpandTileOp (C++)                         ptodsl TileLib (Python)
  build SpecKey from op operands  ──RPC──▶  registry.select(op,target,operand_types,ctx)
  (dtype, shape, valid_shape,               │  ├ filter legal/applicable versions
   memspace, layout, fusion ctx)            │  └ rank (priority → later cost)
                                            ▼
                                   chosen @tile_template version
                                            │ trace body → MLIR
                                            ▼
                            standalone func.func @op_vN(%t0,%t1,%t2 : !pto.tile_buf<…>)
                            body uses memref.subview + pto.vlds/vadd/vsts/plt_b
                            loops are scf.for over pto.tile_valid_rows/cols (dynamic)
  parse + clone + func.call ◀──── MLIR text ─┘
  → FoldTileBufIntrinsics / canonicalize folds concrete sizes
```

On "generate template MLIR then instantiate": a fully type-erased template is **not** achievable
— dtype must be concrete (drives `vreg` lanes + `plt_b` mask width) and memory space is in the
type. The realistic seam is: render **parameterized by the SpecKey**, keeping **valid_shape (and,
where the op allows, physical dims) dynamic**, then let MLIR canonicalization fold the concrete
sizes downstream. That gives the "template then instantiate" feel without an impossible generic IR.
(See [03 §"target IR shape"] reasoning.)

## 5. Phased plan

### Phase 0 — Decide & spike (no big code)
- Confirm: build on the existing `_tile_template_tracing.py` prototype (recommended) vs. port
  tilelang's AST renderer. **Recommendation: extend the prototype** — it already uses ptodsl's
  tracing engine and emits a standalone func; the AST renderer would duplicate ptodsl's frontend.
- Spike one op (`tadd`) end-to-end at the **correct abstraction** to de-risk Phase 1–2.

### Phase 1 — Fix the tile-template path's abstraction level
1. Route `vlds`/`vsts` through the **`memref.subview`** lowering already in `_surface_values.py`
   (the `TileSliceValue` path) instead of `ensure_tile_ptr` + `materialize_linear_offset`.
   Target output == the structured `tadd_template.mlir` we rendered.
2. Make `valid_shape` **dynamic**: emit `pto.tile_valid_rows/cols` + `scf.for` over them (reuse the
   `@pto.jit` path's mechanism), instead of static `index_const(spec.shape)`.
3. Fix the **`plt_b{8,16,32}`** mask path: ensure the Python bindings exist (or add them); remove
   the `NotImplementedError`. This op is required (the `tadd` template uses `plt_b32`).
4. Export `tile_template` + helpers from the ptodsl public surface; add round-trip + verify tests
   (none exist today).

### Phase 2 — Port the template library
- Mechanically rewrite the `lib/TileOps/*_template.py` (~85 files) into ptodsl tile-templates:
  `for … range` → `pto.for_`, mask/indexing/scope adapted. Start with elementwise (`tadd/tsub/
  tmul/...`), then reductions (`tcolmax/...`), then `tcvt`/`tsel`/`tmatmul`.
- Keep the per-op **legality constraints** that already exist (e.g. `tcolmax` row-major + 1-row;
  `tnot` int-only; `tcvt` conversion-pair whitelist).

### Phase 3 — Registry + selector in ptodsl
- Add a `TileTemplateRegistry` + `register()` (mirror tilelang `KernelRegistry`).
- Add `select(op, target, operand_types, context_attrs)` filtering by op/target/param-kinds/
  dtype-signature/**constraints**, tie-break by **priority**. (Port tilelang `select_kernel` +
  `_filter_descriptors_by_operand_schema` semantics.)
- Multi-version per op: allow several `@tile_template` for one op, each with its constraint set
  and priority.

### Phase 4 — Wire to ExpandTileOp
- Give `ExpandTileOp` a path to call **ptodsl** instead of (or behind the same RPC contract as)
  the tilelang daemon. Reuse the existing `SpecKey` → operand-specs/context-attrs JSON contract
  (`ExpandTileOp.cpp:690–868`) so the C++ side barely changes; swap the Python responder.
- Stand up a ptodsl daemon equivalent (or reuse `TilelangDaemon` with a ptodsl entry module) for
  warm-process performance + an instance cache.

### Phase 5 — Version selection for performance (the #739 Goal-2 payoff)
- Add the **second, constrained** versions that mirror pto-isa variants: e.g. `tadd_1d`
  (`constraints=[is_contiguous]`), a post-update version (`constraints=[is_sequential]`), aligned
  vs. masked-tail. Let the selector pick among legal ones.
- Start deterministic (priority). Add a cost model only when multiple versions are simultaneously
  legal *and* a wrong pick measurably hurts (likely the contiguous-tadd case).

### Phase 6 — Cutover & retire tilelang-dsl
- Parity-test ptodsl-emitted MLIR vs tilelang for every op (the daemon instance cache makes A/B
  easy). Flip `ExpandTileOp` default to ptodsl, then delete `tilelang-dsl` + `lib/TileOps` once
  green.

## 6. Open design questions
- **How much to leave dynamic vs. specialize per SpecKey?** (valid_shape: dynamic. physical shape:
  dynamic where the op allows — DMA-stride/matmul ops need static; elementwise don't.)
- **Instance caching key**: reuse tilelang's stable-key scheme (`stable_key.py`) keyed on
  op/target/operand-types/context.
- **Daemon vs. in-process**: keep the warm-daemon model (cold Python per op is too slow).
- **Where do `pto.simd/cube/simt` subkernels fit** as the TileOp→micro-instruction bridge? (Likely
  the cube/matmul templates use `@pto.cube` + `pto.mad`.)
- **Constraint vocabulary**: standardize predicates (dtype, layout, contiguity, memspace, valid-shape
  rank/parity, fusion context) so versions across ops declare them uniformly.

## 7. Risks
- **Abstraction regression**: the prototype's ptr/offset output is below target — must not ship it
  as-is; route through subview.
- **Template rewrite volume**: ~85 templates, each needs manual adaptation + a regression test.
- **Binding gaps**: `plt_b*` is one known missing op; expect more (mask/cube/DMA ops) as ports
  progress.
- **Parity**: ptodsl output must match tilelang semantics op-by-op before cutover.
- **Don't reimplement pto-isa's tuning blindly**: for unfused EmitC-backend ops, pto-isa stays the
  better path; the win is on the VPTO/expansion path and across fusion (see [05 §"is pto-isa
  optimal"] reasoning).
