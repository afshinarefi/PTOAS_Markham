# 00 — PTOAS Overview

## What PTOAS is

**PTOAS** (`ptoas` = "PTO Assembler & Optimizer") is an **out-of-tree LLVM/MLIR compiler**
(pinned to `llvmorg-19.1.7`) for **PTO Bytecode** — *Programming Tiling Operator Bytecode*.
It sits between upper-level AI frameworks (PyPTO, TileLang, CuTile) and Ascend NPU / GPGPU /
CPU backends. Its job (README.md:1–20):

1. Parse and verify `.pto` IR (the PTO MLIR dialect).
2. Run Ascend-specific optimization passes (fusion, automatic sync insertion, memory planning).
3. Lower PTO IR to `EmitC`/`Linalg` and emit C++ (or, on the VPTO path, LLVM/objects) that
   calls the **`pto-isa`** C++ tile library.
4. Provide Python bindings so frameworks can build/compile PTO bytecode from Python.

Target hardware generations: **A3** (910C) and **A5** (950); the `pto-isa` library it emits
calls into also covers A2, Kirin 9030/X90, and a CPU simulator.

## The map — how the parts connect

```
   AUTHORING (Python)                       COMPILER (C++/MLIR)                 RUNTIME LIB (C++)
   ┌────────────────────┐
   │ ptodsl  (NEW)      │  @pto.jit, traces Python ──┐
   │ user-facing FE     │                            │ emits .pto
   └────────────────────┘                            ▼
                                          ┌──────────────────────────┐
   .pto bytecode  ───────────────────────▶│  ptoas  (tools/ptoas)    │
                                          │  PTO/VPTO MLIR dialect    │
                                          │  + pass pipeline          │
                                          └──────────┬───────────────┘
                                                     │ pass: ExpandTileOp
                                                     │ (expands pto.t* tile ops)
                                                     ▼
   ┌────────────────────┐   RPC over socket   ┌──────────────────────┐
   │ tilelang-dsl (OLD) │◀────────────────────│  Tilelang daemon      │
   │ template engine    │  specialized MLIR   │  (tools/ptoas)        │
   │ lib/TileOps/*.py   │────────────────────▶│                       │
   └────────────────────┘                     └──────────┬───────────┘
                                                          │ lowering → EmitC / VPTO-LLVM
                                                          ▼
                                              ┌──────────────────────┐      ┌──────────────┐
                                              │  C++ source / object  │ ───▶ │  pto-isa lib │
                                              │  (+ host stubs)       │ link │  (separate)  │
                                              └──────────────────────┘      └──────────────┘
```

So there are **two Python DSLs in the tree today**, doing different jobs:

| | `ptodsl` (new) | `tilelang-dsl` (legacy) |
|--|----------------|--------------------------|
| Location | `ptodsl/` | `tilelang-dsl/` + `lib/TileOps/*.py` |
| Role | **Frontend**: a human writes a kernel, it traces Python → emits `.pto` | **Compiler-internal**: invoked *inside* `ptoas` by the `ExpandTileOp` pass to generate the vector/cube body for a tile op |
| Runs | before `ptoas` | during `ptoas` (via a daemon subprocess) |
| Author API | `@pto.jit`, `pto.tile.*`, `@pto.cube/@pto.simd/@pto.simt` | `@pto.vkernel(op="pto.tadd", target="a5")`, `pto.vlds/vadd/vsts`, `tile[row, col:]` |
| Detail | [02-ptodsl-frontend.md](02-ptodsl-frontend.md) | [03-tilelang-dsl-and-expandtileop.md](03-tilelang-dsl-and-expandtileop.md) |

The two surfaces are deliberately **similar** (both use `tile[row, col:]` indexing, both have
simd/cube/simt notions) but are **separate codebases** that must be updated in lockstep —
which is the pain point #739 addresses.

## The plan (GitHub discussion #739)

Title: *"Migrate tileLang-dsl & PTO-dsl"*. Two goals:

- **Goal 1 — One DSL.** Replace `tilelang-dsl` with `ptodsl` as the *sole* DSL foundation.
  `ptodsl` should play **both** roles: the end-to-end authoring frontend **and** the
  "TileLib" library that `ExpandTileOp` calls to generate vector/cube lowerings. Kill the
  dual-maintenance burden.

- **Goal 2 — Constraint-aware version selection.** Make every available operator *version*
  explicitly discoverable by the compiler, so `ExpandTileOp` can auto-select an implementation
  from full IR context (dtype, tile shape, memory space, layout, fusion pattern).

Requirements called out: (A) port the `lib/TileOps` template library to `ptodsl` using
`ptodsl`'s abstractions rather than copying old template patterns; (B) implement multiple
high-performance variants per op (axis merging, post-update fusion, layout/tile-size/memory-space
variants); (C) build the selection mechanism that runs *during* `ExpandTileOp` where full IR
context is available.

**Status of the plan itself: not started.** Per the team and confirmed by
inspection, there is currently **no proposal/integration** wiring `ptodsl` into `ExpandTileOp`;
it needs to be designed. The design notes the team has so far are in
[ptodsl_tilelang_expandtileop_summary.md](ptodsl_tilelang_expandtileop_summary.md). Key
clarifications from that record:

- Future `ptodsl` TileLib templates should keep **TileLang-style tile indexing**
  (`src0[row, col:]`), *not* bare-pointer style (`addptr`/`castptr`) — the bare-pointer
  `tadd_dsl.py` is just a standalone demo, not the template style. Tile indexing lowers to
  `memref.SubViewOp` and preserves shape/layout metadata for compiler analysis.
- `pto.simd` / `pto.cube` / `pto.simt` subkernels are the intended bridge between a TileOp
  and its micro-instruction implementation.

## On "version selection" — the ambiguity the user flagged

The user's belief: *version selection in `pto-isa` is mainly **functional** (legality/correctness),
not a performance-tuning knob.* The exploration supports this with nuance:

- In **`pto-isa` (C++)** today, the variants (1D-contiguous vs 2D-strided, post-update vs
  no-post-update — see [05-pto-isa-library.md](05-pto-isa-library.md)) are selected at
  **compile time via C++ template instantiation**, hidden from MLIR/PTOAS. Many of these
  choices are forced by **legality** (e.g. a non-multiple-of-lane `validCols` *requires* tail
  handling — not a free perf choice). So "mostly functional" is fair.
- Caveat: `pto-isa` *does* retain explicit tuning dimensions (tile size, tile shape,
  instruction ordering) and as of 2026-03-30 ships a **CostModel** performance simulator
  (pto-isa README news). So it's not "nothing to tune" — but the tuning is not currently
  surfaced to PTOAS/MLIR.
- The #739 ambition is to make these version choices **visible at the `ExpandTileOp`/MLIR
  level** so structured MLIR can be optimized before final lowering, with a first cut that is
  **deterministic/rule-based** (filter legal templates → pick best specialization → instantiate
  → canonicalize), and a cost model only later.

## End-to-end flow in one line

`.pto` → parse/verify → frontend pipe/sync normalization → (optional A5 fusion) →
view→memref + memory planning → sync insertion → tile-handle materialization → **backend split**:
EmitC→C++ (cube/default) **or** VPTO→LLVM/object → link against `pto-isa`.
Full detail in [01-compiler-pipeline.md](01-compiler-pipeline.md).

## Glossary

| Term | Meaning |
|------|---------|
| **PTO** | Programming Tiling Operator. The high-level tile dialect (`pto.t*` ops on `!pto.tile_buf`). |
| **VPTO** | "Vector PTO" — the low-level dialect (vector regs `!pto.vreg`, masks, ptrs) and the alternate LLVM backend. |
| **TileOp** | A high-level op like `pto.tadd`, `pto.tmatmul` that must be *expanded* into a micro-instruction body. |
| **ExpandTileOp** | The pass that expands a TileOp by calling a DSL template and inlining the result. |
| **TileLib** | The library of per-op templates (`lib/TileOps/*_template.py`) that ExpandTileOp draws from. |
| **Tilelang daemon** | A long-lived Python subprocess `ptoas` spawns so each `ExpandTileOp` invocation is an RPC instead of a cold Python start. |
| **Seam IR** | The shared pre-backend IR snapshot, consumed by both the EmitC and VPTO backends. |
| **a3 / a5** | Ascend hardware generations (910C / 950). |
| **pto-isa** | Separate C++ "PTO Tile Library" repo; the runtime the emitted code calls. |
| **simd / cube / simt** | The three hardware compute roles: vector unit / matrix (cube) unit / scalar-programmable group. |
