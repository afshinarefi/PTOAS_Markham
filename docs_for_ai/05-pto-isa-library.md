# 05 — `pto-isa` (the C++ tile library)

> **Separate repo:** `/home/mani/Desktop/pto-isa` (not part of the PTOAS checkout). This is the
> runtime/library target — the C++ that PTOAS-generated code calls. Understanding it is what
> resolves the "version selection" ambiguity in #739.

## 1. What it is

**PTO Tile Library** — "Parallel Tile Operation (PTO), a virtual ISA for tile-oriented programming
defined by Ascend CANN" (pto-isa `README.md`). It defines **90+ standard tile instructions** and
provides per-generation C++ implementations, so operator authors get one tile programming model that
ports across Ascend generations. Stated philosophy: *not* to hide low-level capability, but to raise
the abstraction level **while preserving room for performance tuning** (tile size, tile shape,
instruction ordering).

Already integrated by PyPTO and TileLang-Ascend. Open-sourced 2025-12-27; notable additions since:
reduction + MX instructions (2026-01-30), conv/quant/comm instructions (2026-02-28), **A5 support +
async comm + a CostModel performance simulator (2026-03-30)**.

## 2. Layout & arch targets

`include/pto/`:
- `npu/a2a3/` — Ascend A2 (910B) & A3 (910C)
- `npu/a5/` — Ascend A5 (950)
- `npu/kirin9030/`, `npu/kirinX90/` — Kirin variants
- `npu/comm/`, `npu/kernels/` — communication ISA + kernels
- `cpu/` — CPU simulator (functional verification / debugging)
- `common/` — shared types (e.g. `GlobalTensor`), constants, utilities

Also: `docs/`, `tests/`, `demos/`, `kernels/`, a CostModel, and `docs_for_ai/`.

## 3. "Version selection" here = **compile-time C++ template choice**

This is the crux. Take binary ops:

- **A2/A3** (`include/pto/npu/a2a3/TBinOp.hpp:20–72`): variants `Bin1LCountMode` / `Bin2LCountMode`
  (1D-contiguous vs 2D-row-strided), `Bin1LNormMode[Small]`, `Bin2LNormMode{ColVLAlign,Head,Tail}`.
- **A5** (`include/pto/npu/a5/TBinOp.hpp:20–150+`): `TBinOps_1D_NoPostUpdate` vs
  `TBinOps_1D_PostUpdate` (absolute addressing vs auto-increment POST_UPDATE), plus
  `TBinOps_2D_NoPostUpdate`, `TBinOps_2D_PostUpdate_FullRepeats[Tail]`.

These are selected **at compile time by C++ template instantiation** — *not* at runtime, *not* by a
cost model in the normal path. PTOAS picks one via lowering and the `--vpto-lowering-strategy`
flag (`post-update`/`no-post-update`); the rest is template specialization inside the headers,
invisible to MLIR/PTOAS.

### Reconciling with the user's belief
The user said *version selection in pto-isa is mainly functional, nothing to tune for performance.*
Accurate, with nuance:
- **Mostly functional/legality-driven.** Many variants are forced by correctness, not free perf
  choices — e.g. a `validCols` not a multiple of the lane count *requires* tail handling. The choice
  is "which legal form fits this shape/layout," not "which is faster."
- **But not literally nothing to tune.** The library deliberately keeps tuning dimensions (tile size,
  tile shape, instruction ordering) and ships a CostModel simulator. Those knobs exist; they're just
  not surfaced to PTOAS today.
- **#739's point** is precisely that these choices are currently *late and hidden* (C++ compile-time
  constants); the goal is to make legal versions **MLIR-visible at `ExpandTileOp`** so structured IR
  can be optimized before final lowering, starting rule-based and adding a cost model only later.

## 4. How generated code links to it

- PTOAS EmitC output calls into `namespace pto` C++ templates; the central buffer type is
  `GlobalTensor<Element_, Shape_, Stride_, Layout_>` (`include/pto/common/pto_tile.hpp:248+`), whose
  shape/stride params may be DYNAMIC (filled at runtime).
- PTOAS post-processes hoisted `GlobalTensor` declarations (e.g. null-ptr init for the
  no-default-constructor case) (`ptoas.cpp:1193–1235`).
- The toolchain discovers the `pto-isa` include path via CANN toolchain resource discovery
  (`tools/ptoas/ObjectEmission.h:52`); generated C++ is then compiled + linked against the headers.
- Arch selection (A2/A3 vs A5) is resolved **inside pto-isa** via template specialization — PTOAS
  just emits calls to the generic instruction types for the chosen arch.

## 5. Status / notes
- Mature, open-source, multi-arch. The piece relevant to PTOAS's roadmap is that its
  implementation-variant selection is **compile-time and hidden**, which is what #739 aims to lift
  into the compiler.
- One example open item: `include/pto/npu/a5/TPow.hpp:499` TODO (vcmax optimization for exponent calc).
