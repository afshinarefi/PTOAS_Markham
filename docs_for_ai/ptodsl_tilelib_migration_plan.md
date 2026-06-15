# PTODSL TileLib Migration Plan (consolidated)

> **Single source of truth** for #739 Goal 1 (one DSL) + Goal 2 (compiler-visible version
> selection). Supersedes the former `06-ptodsl-tilelib-migration-plan.md` and
> `ptodsl_tilelang_expandtileop_summary.md`. Background: [00-overview.md](00-overview.md),
> [01](01-compiler-pipeline.md), [02](02-ptodsl-frontend.md), [03](03-tilelang-dsl-and-expandtileop.md),
> [05](05-pto-isa-library.md).
>
> **Status (2026-06-11): Phases 0–3 + 5 DONE; Phase 4 elementwise underway.**
> `ptodsl/ptodsl/tilelib/` exists (metadata/author/decorator/registry/render/_render_runtime +
> `serving/` daemon + `templates/a5/`). Templates are verbatim tilelang bodies (via the #769 AST
> rewrite). **Ported (f32):** binary elementwise `tadd, tsub, tmul, tmax, tmin, tdiv` (default
> precision) + reduction `tcolmax`. **Constraint-driven selection is real** — `constraints.py` ports
> tilelang's introspection eval; `tcolmax` is selected only for row-major/none-box + 1-row output,
> rejected otherwise. Priority selection also works (two `tadd` versions). 17 unittests pass
> (`test_tilelib_{render,select,daemon,elementwise,constraints}.py`). The C++ `ExpandTileOp` expands a real
> kernel's `pto.tadd` through the ptodsl daemon (`--tile-lib-backend=ptodsl`), inlines, folds, and
> lowers through vpto to valid output — semantically equivalent to tilelang (only diff: a
> loop-invariant `castptr` not hoisted; LICM folds it).
>
> **⚠️ Scope (verified):** templates are a **VPTO-backend mechanism only** — `ExpandTileOp` runs
> solely in `lowerPTOToVPTOBackend` (`ptoas.cpp`/`createExpandTileOpPass`). The default **EmitC→C++**
> path does **not** use templates (ours or tilelang's); it lowers `pto.t*` directly to `pto-isa`
> library calls. So the TileLib migration only affects the VPTO/expansion path.
>
> **🧭 Design direction (upstream review):** daemon flow is acceptable for now. Version selection
> must split into **functional/legal** (PTODSL: constraints + render — done at the legality level)
> vs **performance** (PTOAS/MLIR, with full kernel/fusion context). Target flow evolves from "PTODSL
> picks one" to "**PTODSL returns all legal candidates + metadata; PTOAS performance-selects;
> PTODSL renders the chosen one**" — see §5. Next op to exercise real constraint-based selection:
> `tmov` (UB2UB+ND2ND), not more `tadd`-style duplicates.
>
> **Remaining:** Phase 4 — reduction siblings (`tcolmin`/`tcolsum` = same body, swap op; `trow*`
> use cross-lane `vc*` — different body; `tcolargmax`/`argmin` track indices — different body),
> `tcvt` (round-mode `context_attrs`), `tsel`, `tmatmul` (`@pto.cube`/`pto.mad`); HP-`tdiv`
> (`get_op_attr` bridge + port `div_hp.py`); broaden dtypes (f16/i32). Phase 6 — parity cutover.
> Polish — LICM hoist, swap relay to `ptodsl.tilelib.serving.helper`, faster daemon startup.

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

### One existing prototype — keep the scaffolding, discard the emitters

`ptodsl/ptodsl/_tile_template_tracing.py` is an **unwired prototype** (no importers, 0 tests, not
exported). Its *useful* part is the **runtime scaffolding**: `compute_argument_types` builds
`!pto.tile_buf` arg types from `Tile` annotations + a `TileSpec`, and `bind_entry_arguments` hands
the body the entry args. Its *body emitters* are too low-level (`ensure_tile_ptr` +
`materialize_linear_offset` → ptr+offset; static `valid_shape`) and should be **deleted, not
fixed** — see the §9.4 finding: wrapping each entry arg as `TileValue(arg)` makes the engine's own
`tile[row,col:]` / `valid_shape` / `_ops.*` produce the golden directly. This becomes
`tilelib/_render_runtime.py`: keep the scaffolding, bind args as `TileValue`, drop `_TileProxy` and
the ptr/offset path.

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

Version selection splits into **two kinds**, owned by **two different layers**. Getting this split
right is the core of Goal 2 (refined in upstream review).

### 5.1 Functional/legal selection vs. performance selection

- **Functional / legal selection — PTODSL's job.** *Which implementations are correct/applicable*
  for a concrete TileOp. Inputs: op, target, dtype signature, and **per-template constraint
  functions** (predicates like "both operands UB + ND/none-box layout"). Purely local to the op.
- **Performance version selection — PTOAS/MLIR's job.** *Which legal implementation is best.* This
  needs the **full kernel/graph context** — producer/consumer relationships, fusion opportunities,
  loop structure, surrounding TileOps — which only the compiler IR has. PTODSL can't decide this
  locally; some optimizations depend on multiple TileOps together, not one op in isolation.

So PTODSL is the **legal-candidate provider + renderer**; PTOAS owns the **global performance**
decision.

### 5.2 What's implemented (MVP)

`constraints.py` + a hook in `registry.select`: filter op → target → dtype-signature →
**constraint functions**, then rank legal candidates by `priority`. `tcolmax` demonstrates a real
legality constraint (row-major/none-box + 1-row output).

> **Correction adopted (upstream review):** selection is **not** just `op + target + dtype +
> priority`. Per-template **constraint functions are first-class metadata** — matching tilelang,
> e.g. `lib/TileOps/tmov_template.py`'s `_tmov_ub2ub_nd2nd_constraint(src, dst)` (both UB, both
> ND/none-box; rejects GM2UB/UB2GM and specialized layouts). Our `constraints=[...]` + introspection
> evaluator already cover this — the design gap is closed at the legality level.

The current **priority** ranking is an acceptable MVP stand-in (fine with one legal candidate, or to
break ties). It is **not** a substitute for global performance selection (§5.3).

### 5.3 Target flow: PTODSL provides candidates, PTOAS selects

The agreed long-term direction changes selection from *"PTODSL picks one final candidate by
priority"* to *"PTODSL returns **all legal candidates + metadata**; PTOAS performs performance
selection with full IR context; PTODSL then renders the chosen candidate(s)."*

```
PTOAS / MLIR side                          PTODSL / Python side (daemon)
─────────────────                          ────────────────────────────
ExpandTileOp
  └─ send specs for the TileOp(s) ────────▶ legal/functional lookup
                                              (op+target+dtype+constraints)
     all legal candidates + metadata   ◀──── return candidates + metadata
performance version selection
  (kernel/graph context: producer/
   consumer, fusion, loop structure)
  └─ pick best candidate per TileOp ──────▶ render MLIR for the selected candidate(s)
     rendered MLIR                     ◀──── (the existing render path)
fusion pass → rest of pipeline
```

**RPC implication:** the current single `instantiate` (legal-filter + priority + render in one call)
splits into two phases — **(a) list legal candidates + metadata**, then **(b) render a
named/selected candidate**. The daemon grows a candidate-listing method; the render path stays.

> **This is a design direction, not yet implemented.** The MVP's single-call priority select (§5.2)
> remains the working mechanism until the two-phase flow is built.

### 5.4 Candidate metadata for performance

A single `fusible=True/False` flag is **too weak** — fusion/perf passes need richer, structured
metadata to reason about a candidate without re-deriving it from rendered IR. Exact schema is
**TBD** (design it against what the fusion/perf passes actually consume); a working wishlist:

- op category (elementwise / reduction / expansion / movement / conversion / matmul …)
- loop-nest structure (levels; which are row/col/tile/lane loops); pointwise vs. has reduction axes
- expands/broadcasts rows or columns; input/output tile roles; read/write behavior; pure vs. side-effecting
- memory spaces used; layouts supported; preserves vs. changes shape/layout; in-place / post-update
- estimated vector/cube usage; temporary-buffer usage; optional cost/priority hints

**Ownership:** the performance-selection *algorithm* (heuristic / profiling / later model-based) is
**owned and designed by the compiler/PTOAS side** — not something we should over-design. PTODSL's
job is to **expose enough structured metadata** for that selector to work.

### 5.5 Next design step (before porting many ops)

Inspect tilelang templates + pto-isa/PTOAS TileOp implementations and **separate, per op**:
1. **functional conditions** — whether an implementation is legal at all (→ a constraint function);
2. **performance conditions** — when one legal impl beats another (→ metadata for the PTOAS selector).

`tmov` is the concrete next candidate: a real tilelang constraint (`UB2UB + ND2ND`) + likely multiple
movement/layout variants — a far better test of constraint-based legal selection than `tadd`'s
priority-only duplicates.

**Note on the render seam:** a fully type-erased template isn't achievable — dtype is concrete
(drives `vreg` lanes + `plt_b` width) and memory space is in the type. Render **parameterized by the
SpecKey**, keep **valid_shape dynamic** (physical dims dynamic where the op allows — elementwise yes;
DMA-stride/matmul need static); MLIR canonicalization folds concrete sizes downstream.

### 5.6 Survey findings — functional vs. performance, grounded (2026-06-12)

Surveyed tilelang templates (`lib/TileOps/*.py`), pto-isa kernels (`a2a3/`, `a5/` headers), and the
PTOAS fusion pass (`lib/PTO/Transforms/TileFusion/`). Each compile-time branch / constraint
falls into one of three classes:

- **FUNCTIONAL:** determines whether a candidate is legal.
- **PERFORMANCE:** multiple candidates are legal; this condition helps rank them.
- **BOTH:** one side is required for legality, while the other leaves multiple legal choices that
  should be ranked with kernel/fusion context.

| # | Condition type | Keys on | Class | PTO-ISA anchor |
|---:|---|---|---|---|
| 1 | Contiguity (1D vs. 2D traversal) | `ValidCol == Cols` or `Rows == 1` | **BOTH** — non-contiguous must use 2D; when contiguous, 1D and 2D are legal and 1D is normally faster | `a5/TBinOp.hpp:233-244`, `a2a3/TBinOp.hpp:259` |
| 2 | Post-update vs. no-post-update addressing | Contiguity / regular access | **BOTH** — both are legal for contiguous access; post-update uses fewer instructions, while generic addressing may be more fusion-friendly | `a5/TBinOp.hpp:94-119`, `a5/TBinOp.hpp:179-195` |
| 3 | Column / lane-length alignment | `Cols % elementsPerRepeat == 0` | **BOTH** — a non-multiple requires tail/count mode; an aligned width permits norm mode (fast) or count mode (generic) | `a2a3/TBinOp.hpp:198` |
| 4 | Repeat / stride hardware limits | `totalRepeats > REPEAT_MAX`, `stride/blk > REPEAT_STRIDE_MAX` | **FUNCTIONAL** — exceeding a limit forces element-wise or absolute addressing | `a2a3/TBinOp.hpp:117`, `:120`, `:135`, `:199` |
| 5 | Memory layout | ND / NZ / DN layout | **FUNCTIONAL** — selects the correct load/store implementation | `a2a3/TLoad.hpp:191-199`, `a2a3/TStore.hpp:134-143` |
| 6 | Fractal format / SFractal compact mode | Fractal / box layout | **FUNCTIONAL** — selects the required extract/insert path | `a2a3/TMov.hpp:147-165` |
| 7 | Data type | Element type | **FUNCTIONAL** — selects distinct intrinsics, reduction behavior, and mask width | `a2a3/TRowSum.hpp:94-141`, `a5/common.hpp:46` |
| 8 | Quantization mode | Source/destination dtype pair | **FUNCTIONAL** — selects the required `QuantMode`, such as `F322F16` or `int32 -> int8` | `a2a3/common.hpp:21-58` |
| 9 | Predicate width | `sizeof(T)` (`1/2/4`) | **FUNCTIONAL** — `plt_b8`, `plt_b16`, or `plt_b32` must match the dtype | `a5/common.hpp:46` |
| 10 | Reduction strategy | Row count | **PERFORMANCE** — binary-tree and sequential forms are correct; tree reduction is generally faster for large row counts | `a2a3/TColSum.hpp:62-82` |
| 11 | Small-shape fast path | `Rows * repeats < SMALL_RPT_BINOP` | **PERFORMANCE** — selects a lower-overhead implementation | `a2a3/TBinOp.hpp:230`, `:252` |
| 12 | Channel-split flag | `f32` NZ2NZ store, `c0 == 8` | **PERFORMANCE** — enables channel-split quantization | `a2a3/TStore.hpp:376-379` |

The design grouping is therefore:

| Group | Conditions | TileLib / PTOAS treatment |
|---|---|---|
| **BOTH** | Contiguity; post-update addressing; column/lane alignment | TileLib returns every legal variant with structured metadata; PTOAS chooses using local cost and fusion context |
| **FUNCTIONAL** | Hardware limits; layout; fractal format; dtype; quantization mode; predicate width | Encode as dtype signatures, hard constraint predicates, or required operand metadata during legal lookup |
| **PERFORMANCE** | Reduction strategy; small-shape path; channel split | Keep all legal variants visible and rank them on the MLIR side |

Additional op attributes follow the same rule: `precisionType` (`tdiv`/`texp`/`tlog`/…), `round_mode`
(`tcvt`), and `pad_value`/`enable_ub_pad` (`tload`) must first be checked for legality; whenever more
than one correct implementation remains, they become performance-selection inputs.

**Implication (the canonical realization of §5.3):** for a "both" case like contiguity, the TileLib
should expose **both** variants as legal candidates (e.g. `tadd_1d_fast` + `tadd_2d_generic`), each
tagged with metadata, and let PTOAS choose — *fast when standalone, fusion-friendly when a neighbor
can fuse*. This is precisely why performance selection needs global IR/fusion context and **cannot**
live in PTODSL.

**What the fusion pass actually keys on (→ which metadata matters most).** `PTOFusionPlan.cpp` /
`FusionAnalysis.cpp` / `FusionOpSemantics.cpp` today **re-derive** from op *names* + tile *shapes*:
op category (Elementwise / ScalarExpand / RowBroadcastBinary / ReduceRow / ReduceCol), a *proven
static* **iteration domain** (vRow/vCol — dynamic shapes are rejected), reduction direction,
data-flow deps, and hard boundaries (terminators/regions/calls/side-effects). So the highest-value
candidate-metadata fields (prioritizing §5.4's wishlist) are exactly what fusion reconstructs today:
- **HIGH (fusion re-derives these now):** `op_category`, `iteration_domain` (vRow/vCol + proven flag),
  `reduction_axes`, `is_pointwise`.
- **HIGH for perf paths:** `memory_space`, `layout_preserving`, `supports_in_place`,
  `pipeline_category` (cube/vector/MTE), `temp_buffer` usage.
- **MEDIUM:** tile-input/output arity, side-effect/purity, accumulation support, precision/dtype-pair.

**Properties the conditions key on (candidate-metadata field seeds):** dtype, layout (`b_layout`/
`s_layout`), memory-space, **contiguity**, valid-shape/alignment (cols vs lane count, dst-rows),
op-attrs (`precisionType`/`round_mode`/`cmp_mode`), rank/stride, `pad_value`. The first three are
already in our `TileSpec`; contiguity + alignment + op-attrs are the additions a richer schema needs.

Candidate granularity should correspond one-to-one with meaningful PTO-ISA `T*` implementation
variants that the compiler may need to distinguish. This is a mapping of semantics and metadata,
not a requirement to duplicate the C++ implementation inside PTODSL.

### 5.7 Fusion-aware performance selection

Performance selection needs to model the current fusion pass rather than relying on a standalone
per-op instruction estimate. Fusion has two decision levels: all hard gates must pass, then the
cost-model score must be positive.

#### Fusion hard gates

| # | Condition | What it checks | PTOAS anchor |
|---:|---|---|---|
| 1 | Fusible op/category | The op must be a plannable `Compute` op. Elementwise, scalar, expand/broadcast, and row/column reductions are supported; `treshape` is a local boundary and other ops are hard boundaries. | `FusionOpSemantics.cpp:17-30`, `:70-81` |
| 2 | Proven static iteration domain | Tile dimensions such as `(vRow, vCol)` must be statically provable; dynamic shapes are rejected. | `PTOFusionPlan.cpp:76-83`, `:291-294` |
| 3 | Same iteration-domain class | Group members must have the same `(vRow, vCol)`. Elementwise domains merge inputs/outputs; expand/broadcast uses outputs; reductions use inputs. | `FusionAnalysis.cpp:130-149`, `PTOFusionPlan.cpp:314-322` |
| 4 | No hard structural boundary | No terminator, region, call, or memory-side-effecting operation may separate the candidate from the group. | `PTOFusionPlan.cpp:85-99`, `PTOOpScheduling.cpp:79-99` |
| 5 | Direct data-flow dependency | The candidate must share an SSA tile value with, or have a DFG edge to, the group. Unrelated islands do not fuse. | `PTOFusionPlan.cpp:202-228`, `:381-384` |

#### Fusion cost model

After the hard gates pass:

```text
accept fusion if net_score > 0
```

| # | Score term | Effect | PTOAS anchor |
|---:|---|---|---|
| 6 | Dependency benefit | Adds a positive score for each incoming edge from the group. | `PTOFusionPlan.cpp:329-331` |
| 7 | Loop-merge benefit | Adds a positive score for appending an op; the DAG model uses `+4`. | `PTOFusionPlan.cpp:332`, `:392` |
| 8 | Live-tile penalty | Subtracts `max(0, liveTileCount - limit)`; the model-dependent limit is approximately `4` or `10`. | `PTOFusionPlan.cpp:333-334`, `:394` |
| 9 | VF-parameter penalty | Subtracts `max(0, vfParamCount - limit)`; the model-dependent limit is approximately `6` or `12`. | `PTOFusionPlan.cpp:335-336`, `:396` |

Downstream scheduling can move operations toward contiguity only when tile dependencies, hard
barriers, and side effects permit it (`PTOOpScheduling.cpp:101-153`). Last-use marking is likewise
blocked by hard barriers between group members (`PTOMarkLastUse.cpp:212-225`).

**Metadata consequence:** legal-candidate responses should carry enough information to estimate
the gates and score before rendering: operation/boundary category, iteration-domain class and static
dimensions, data-flow roles, side effects, temporary/live-tile pressure, VF parameter pressure,
loop/access structure, and producer/consumer compatibility. PTOAS remains authoritative because it
has the actual SSA graph and can validate or override candidate hints.

---

## 6. Phased plan

### Phase 0 — Verify & spike *(see §9 checklist)* — ✅ DONE
Confirm the reuse assumptions (engine emitters, func shape, attribute name, bindings) and regenerate
the golden. No large code.

### Phase 1 — Renderer via the engine *(highest risk; do first)* — ✅ DONE
> `_render_runtime.py`: binds entry args as `_TemplateTile(TileValue)` with explicit spec
> metadata (raw tile_buf types aren't introspectable — the regex/binding parse paths both miss),
> forces dynamic `valid_shape`, custom single-module+func-attr container. Body ops route to the
> engine. Known benign diffs vs golden: `tile_buf_addr` per-slice (not hoisted), constants
> re-emitted, `remained` carried as `index` (vs i32), rank-1 subview (vs rank-2) — all "same
> abstraction, not byte-identical". `plt_b32` needed no work (binding present).
In `_render_runtime.py` (from `_tile_template_tracing.py`):
1. **Bind entry args as `TileValue`** — change `bind_entry_arguments` to return `TileValue(arg)`
   instead of `_TileProxy(arg)` (metadata auto-parses from the `!pto.tile_buf` type — §9.4). Delete
   `_TileProxy`, `ensure_tile_ptr`, `materialize_linear_offset`, `_materialize_row_offset`, ptr cache.
2. **Author surface calls the engine** — `author.py` re-exports `_ops.vlds/vadd/vsts/make_mask` and
   `get_lanes`; `tile[row,col:]` is just `TileValue.__getitem__` → `memref.subview`; `valid_shape`
   is the engine's dynamic `pto.tile_valid_rows/cols`. No new lowering written.
3. **Match the golden's module/func shape** — emit a single `module {pto.target_arch}` containing
   the func, with `pto.tilelang.instance` (UnitAttr) + `pto.kernel_kind` **on the func**. The
   prototype's `ModuleStyle.NESTED` double-nests and puts `kernel_kind` on the inner module, and
   never sets `tilelang.instance` (§9.3) — add a small custom builder or post-process (~10 lines).
4. **`plt_b32` already works** — binding present (§9.1); the prototype's `make_mask` only threw when
   absent. No work.
5. Author the spike `tadd` body **without `vecscope`** (the golden has none); compare vs the golden
   structurally (normalize SSA names / drop tilelang `//` comment header — not a byte `diff`).

> **AST control-flow rewrite — ✅ ADOPTED (2026-06-11).** `_render_runtime.trace_entry` runs the
> body through `_ast_rewrite.rewrite_jit_function` (PR #769's rewrite), so templates use plain
> `for x in range(...)` — rewritten to `pto.for_(...).carry(...)` with loop-carried vars detected by
> liveness. `tilelib.author` re-exports `_control_flow.{for_,static_range,if_,yield_,const_expr}`;
> the bespoke `_ForCM`/`yield_state` was removed. Result: templates are verbatim tilelang bodies
> (only the `import` + decorator differ). Verified: `tadd` renders the same golden loop (outer
> `scf.for` + inner `scf.for … iter_args(%remained)`) as before; 12/12 tilelib tests pass.

### Phase 2 — Catalog layer (minimum to author) — ✅ DONE
`metadata.py` (`TileSpec`/dtypes/`TemplateMetadata`), `decorator.py` (`@tile_template`),
`author.py` (engine-routed body ops). Public surface exported from `tilelib/__init__.py`.

### Phase 3 — Registry + selector — ✅ DONE
`registry.py`: `register` + `select` (op/target → dtype-signature → priority; ties → error).
Proven with `templates/a5/tadd.py` (prio 0) + `tadd_hp.py` (prio 10): selection picks prio-10.
`constraints.py` deferred (stub-equivalent — `select` currently filters op/target/dtype only) until
a second *real* variant needs it in Phase 5.

### Phase 4 — Port the template library — ⏳ IN PROGRESS
Mechanically port `lib/TileOps/*_template.py` (~85) into `templates/a5/`: bodies near-verbatim,
keep per-op legality constraints (`tcolmax` row-major+1-row; `tnot` int-only; `tcvt` pair whitelist).
Order: elementwise → reductions → `tcvt`/`tsel`/`tmatmul`.
- ✅ **Binary elementwise (f32, default precision):** `tadd, tsub, tmul, tmax, tmin, tdiv`. Each is a
  verbatim tilelang body (`for…range`, `pto.vlds/v*/vsts`) with only the import + decorator changed;
  `tdiv` is default-precision only (HP path deferred). Covered by `test_tilelib_elementwise.py`.
- ✅ **Constraint mechanism + first reduction:** `constraints.py` (introspection eval ported from
  tilelang, `BLayout`/`SLayout` enums) + a hook in `registry.select`; `tcolmax` ported with its
  `_validate_tcolmax` predicate. Selection is now legality-driven. The reduction body (nested carry
  loops + carry-var-used-after-loop) renders correctly through the #769 rewrite.
- ⬜ **`tmov` — recommended next op.** Real legality constraint (`UB2UB + ND2ND`, rejects
  GM2UB/UB2GM/specialized layouts) + multiple movement/layout variants. It's the proper test of
  constraint-based *legal* selection (vs `tadd`'s priority-only duplicates) and the first op to
  classify functional vs. performance conditions per §5.5.
- ⬜ **Reduction siblings:** `tcolmin`/`tcolsum` (same body, swap `vmax`→`vmin`/`vadd`, same
  constraint) are trivial; `trow*` use cross-lane `vc*` (different body); `tcolargmax`/`argmin`
  track indices (different body).
- ⬜ `tcvt` (round-mode `context_attrs`), `tsel`, `tmatmul` (`@pto.cube` + `pto.mad`); broaden dtypes.
- ⏸ **HP-`tdiv` — speculative, deferred.** No kernel/test drives the template HP branch:
  `tdiv_precision_emitc.pto` is EmitC (→ pto-isa, no templates), and `test/lit/vpto/` has no
  `high_precision` case. The HP path also needs `pto.inline_proc` + 3 missing ops (`vmula`/`vshls`/
  `vshrs`) + a `get_op_attr` bridge + the 454-line `div_hp.py`. Default-precision `tdiv` ships; HP
  stays unported until a real VPTO consumer exists.

### Phase 5 — Wire to `ExpandTileOp` — ✅ DONE (for `tadd`)
> Proven 2026-06-11: `ptoas --tile-lib-backend=ptodsl` on `test/lit/vpto/fold_tile_buf_intrinsics.pto`
> expanded `pto.tadd` via the ptodsl daemon and lowered through vpto cleanly. Distinguished from
> tilelang by the output diff (ptodsl emits the base `castptr` inside the loop; tilelang hoists it)
> — confirming a different, ptodsl-served expansion. Required a poll-based daemon-startup wait
> (`TilelangDaemon.cpp`) since the ptodsl import exceeds the old fixed 1s.

**Contract (verified).** C++ chooses daemon vs subprocess by whether `daemonSocketPath` is set
(`ExpandTileOp.cpp:955-962`). The daemon protocol is AF_UNIX SOCK_STREAM, 4-byte big-endian
length-prefixed JSON, one request/connection; method `instantiate` with params
`{target, op, operand_specs, context_attrs}` → `{success, result|error}` (`daemon_client.py`).
`operand_specs` per-tile JSON = `{kind:"tile", dtype, shape[], valid_shape[], memory_space,
config{b_layout,s_layout,s_fractal_size,pad_value}}` (`ExpandTileOp.cpp:702-719`). The returned
func must carry `pto.tilelang.instance` (`ExpandTileOp.cpp:937-941`) — ours does. The per-call
*client* is `tilelang_dsl.daemon_helper`, a generic socket client → talks to our daemon unchanged.
The daemon *server* module is hardcoded `"tilelang_dsl.daemon"` at `TilelangDaemon.cpp:40`.

**5a — ptodsl daemon (DONE, pure Python).** `tilelib/serving/{wire,daemon,client,helper}.py`:
`TileLibDaemonServer` speaks the exact protocol, translates `operand_specs` → `TileSpec`s →
`render_best`, with an instance cache + `ping`/`get_stats`/`clear`. Verified in-process by
`tests/test_tilelib_daemon.py` (C++-shaped `tadd` JSON → socket RPC → structured MLIR, cache hit,
error path). No C++/rebuild needed.

**5b — C++ swap (TODO, needs rebuild).** Minimal flag-gated diff:
1. `TilelangDaemon.h/.cpp`: add a `daemonModule` param to `DaemonManager::start` (default
   `"tilelang_dsl.daemon"`); use it at the hardcoded `args` list.
2. `ptoas.cpp`: add `--tile-lib-backend=tilelang|ptodsl` (default tilelang); when `ptodsl`, pass
   `daemonModule="ptodsl.tilelib.serving.daemon"` to `start(...)` and ensure `ptodsl` is importable
   (pkgPath includes the ptodsl root, or rely on the installed package).
3. *(clean cutover, optional)* add an ExpandTileOp `helper-module` option (Passes.td) and use it in
   the helper args (`ExpandTileOp.cpp:810`), set to `ptodsl.tilelib.serving.helper` for ptodsl —
   otherwise the existing `tilelang_dsl.daemon_helper` client is reused (works, protocol-identical).

**5b test.** Rebuild, then run a real kernel (e.g. `test/lit/vpto/fold_tile_buf_intrinsics.pto`,
which has a `pto.tadd` 16x64 kernel) with `--tile-lib-backend=ptodsl` and compare lowering to the
default tilelang path. This is where the standalone-instance-func limitation resolves (the func is
inlined into the kernel) and true end-to-end lowering is exercised.

### Phase 6 — Cutover & retire tilelang-dsl
Parity-test ptodsl vs tilelang MLIR per op (instance cache makes A/B easy). Flip the `ExpandTileOp`
default to ptodsl; delete `tilelang-dsl` + `lib/TileOps` once green.

---

## 7. MVP (build first, in this order)

Prove the loop with `tadd` before any breadth:
0. Commit the golden fixture `ptodsl/tests/fixtures/tadd_a5_8x64_f32.golden.mlir` (from §9.2).
1. `_render_runtime.py` — Phase 1 (bind `TileValue`, call engine, match func shape/attrs).
2. `metadata.py`, `decorator.py`, `author.py`.
3. `templates/a5/tadd.py` — one real template **plus a duplicate at higher `priority`** to exercise
   selection (proves multi-version registration even with identical bodies).
4. `registry.py` — `register` + `select`.
5. `render.py` + CLI; `ptodsl/tests/test_tilelib_render.py` comparing rendered MLIR to the golden
   fixture **structurally** (normalize SSA names, drop the tilelang `//` comment header) — not a
   byte `diff`, since ptodsl SSA naming and the comment header will differ.

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
9. **Candidate-metadata schema (§5.4)** — what does the PTOAS fusion/perf selector actually need?
   `fusible` is too weak; the wishlist in §5.4 is a starting point. Design against real pass needs.
10. **Two-phase daemon RPC (§5.3)** — split the single `instantiate` into *list-legal-candidates +
    metadata* and *render-selected-candidate*. Define the candidate-metadata wire format.
11. **Perf-selector ownership** — the performance-selection *algorithm* is owned by the PTOAS/MLIR
    side (heuristic/profiling/model). PTODSL only supplies metadata; don't over-design the algorithm.

---

## 9. Verification checklist — RESOLVED (2026-06-10)

All four reuse assumptions confirmed; results recorded below.

1. **Bindings present? ✅ ALL PRESENT.** `PltB32Op/PltB16Op/PltB8Op/TileBufAddrOp/TileValidRowsOp/
   TileValidColsOp/VldsOp/VstsOp` all `True`. → Phase 1.4 (`plt_b32`) needs no new binding.
2. **Golden regenerable? ✅.** `runpy` render of `lib/TileOps/tadd_template.py` (dst/src0/src1 =
   8x64@ub) reproduces the expected abstraction (`tile_buf_addr→memref`, `tile_valid_rows/cols`,
   `memref.subview`, `vlds/vadd/vsts`, no `vecscope`, func attrs `pto.tilelang.instance` +
   `pto.kernel_kind<vector>`). The untracked repo-root `tadd_template.mlir` is byte-identical.
   *(Direct invocation fails — `lib/TileOps/math.py` shadows stdlib `math`; use `runpy`.)*
   **TODO:** commit a stable copy as `ptodsl/tests/fixtures/tadd_a5_8x64_f32.golden.mlir` so the
   regression test has a checked-in reference (don't diff against the scratch repo-root file).
3. **`_TraceBuilder` func shape — ⚠️ params ✅, module/func shape needs a small builder.** The
   prototype emits a `func.func` with `!pto.tile_buf` params (`compute_argument_types` +
   `TileSpec.mlir_type()`), but `ModuleStyle.NESTED` (`_tracing/module_builder.py:56-72`) produces
   `module > inner builtin.module(kernel_kind) > func` and **never sets `pto.tilelang.instance`**;
   the golden is a single `module(target_arch) > func(kernel_kind, tilelang.instance)`. → Phase 1.3
   adds a custom builder/post-process (func-level attrs can be set directly:
   `ir_fn.attributes["pto.tilelang.instance"] = UnitAttr.get()`). Confirm what `ExpandTileOp` reads
   `kernel_kind` from (func vs module) when Phase 5 lands.
4. **Engine reachability — ✅ CLEAN.** `TileValue.__init__` (`_surface_values.py:418-447`)
   auto-parses shape/dtype/memory_space/valid_shape from the `!pto.tile_buf` type via
   `parse_tile_type_metadata(value.type)`. So `TileValue(entry_arg)` is fully populated with **no
   extra metadata**, and `__getitem__` (→ `memref.subview`), `valid_shape` (→ dynamic
   `tile_valid_rows/cols`), and `_ops.vlds/vadd/vsts/make_mask` are directly callable. → Phase 1
   *deletes* the prototype emitters rather than fixing them.

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
