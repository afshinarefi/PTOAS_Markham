# 04 — The `ptoas` CLI & backends

`ptoas` is the command-line driver. Source: `tools/ptoas/` — `ptoas.cpp` (flags + pipeline
construction), `driver.cpp` (module load + arch detection), `ObjectEmission.cpp`,
`VPTOHostStubEmission.cpp`, `TilelangDaemon.cpp`. A second tool `tools/ptobc/` handles `.pto`↔`.ptobc`
binary bytecode round-tripping. The pipeline this driver builds is documented in
[01-compiler-pipeline.md](01-compiler-pipeline.md).

## 1. Key flags (verified against `ptoas.cpp:440–500`)

| Flag | Values (default) | Effect |
|------|------------------|--------|
| `--pto-arch` | `a3` \| `a5` (**a3**) | Target Ascend generation. Auto-detected from module `pto.target_arch` if not set (`driver.cpp:77–89`). Selects arch-specific `EmitPTOManual` + A5-only passes. |
| `--pto-level` | `level1` \| `level2` \| `level3` (**level2**) | Build level — gates passes/validation (see §2). |
| `--pto-backend` | `emitc` \| `vpto` (**emitc**) | Final backend after the seam IR (see §3). |
| `--emit-pto-ir` | bool (false) | Emit PTO IR text after lowering instead of C++. |
| `--emit-vpto` | bool (false) | Write final post-pass VPTO IR to `-o`. |
| `--vpto-lowering-strategy` | `post-update` \| `no-post-update` (**post-update**) | Which `pto-isa` vector variant the VPTO path targets (a compile-time template choice — see [05](05-pto-isa-library.md)). |
| `--vpto-print-ir` / `--dump-vpto-ir` | bool | Print post-pass VPTO IR to stderr. |
| `--pto-print-seam-ir` / `--pto-seam-ir-file <path>` | bool / path | Dump the shared pre-backend seam IR (the EmitC/VPTO fork point). |
| `--enable-op-fusion` | bool | Enable Stage-2 frontend fusion. **Requires level2/3** (`ptoas.cpp:1605–1612`); A5 only. |
| `--enable-tile-op-expand` | bool | **Deprecated** — TileOp expansion is now controlled by `--pto-backend` (`ptoas.cpp:351–356`). |

## 2. What `--pto-level` gates

- **level1 / level2**: enable `pto-plan-memory` (local memory planning) (`ptoas.cpp:1749–1754`).
- **level3**: **skips** memory planning; requires every `pto.alloc_tile` to carry an explicit `addr`
  operand (forbidden in level1/2) (`ptoas.cpp:1681–1702`); `pto.tassign` only legal at level3
  (`ptoas.cpp:1644–1648`). I.e. level3 = "addresses already resolved upstream".
- `--enable-op-fusion` is rejected unless level2/3.

## 3. Backends & output modes

The pipeline runs a **shared mainline** up to the **seam IR**, then forks on `--pto-backend`:

**EmitC backend (default)** — `ptoas.cpp:1820–1865`:
- `createEmitPTOManualPass(A3|A5)` → EmitC → `form-expressions` → CSE → C++ post-processing
  (`CppPostprocess.cpp` rewrites marker calls like tile `SetValue`/`GetValue`/`data`/`SetValidShape`
  into real `pto-isa` member calls) → emit C++ text or object.
- Generated C++ links against the `pto-isa` library (`GlobalTensor<...>` template class etc.).

**VPTO backend** — `--pto-backend=vpto`, `ptoas.cpp:1461–1576` / `1800–1817`:
- VPTO-specific passes (wrapper expansion, ptr normalize/cleanup, vecscope inference, validation) →
  VPTO LLVM emitter → Bisheng-LLVM object/**fatobj** + optional CANN **host stub**
  (`VPTOHostStubEmission.cpp`, `driver.cpp:538–568`).

**IR-only outputs**: `--emit-pto-ir` (PTO IR text), `--emit-vpto` (VPTO IR), `--pto-seam-ir-file`
(seam IR) — for inspection/testing without full codegen.

Useful pass-dump recipe for PTODSL TileLib version selection plus A5 fusion debugging:

```bash
ptoas --pto-arch=a5 --pto-backend=vpto --emit-vpto \
  --tile-lib-backend=ptodsl --pto-level=level2 \
  --enable-op-fusion \
  --mlir-print-ir-after=pto-low-level-loop-fusion \
  --mlir-print-ir-after=pto-expand-tile-op \
  ptodsl/tests/inputs/TMulTAdd_Attribute.mlir -o /dev/null &> out.log
```

In the `pto-expand-tile-op` dump, `func.call @template_tmul...` and
`func.call @template_tadd...` reveal which TileLib templates were selected. The
`pto-low-level-loop-fusion` dump shows the post-expansion fusion result.

## 4. Pipeline construction summary

`ptoas.cpp` builds one `PassManager`: shared mainline (`~1726–1798`) → conditional auto-sync (exactly
one of insert-sync / bufid-sync / barrier-all / graph-solver, `~1761–1776`) → materialize tile handles
+ CSE (seam, `~1792–1798`) → backend branch. `driver.cpp` handles input load and arch detection and
orchestrates the VPTO multi-module job (cube + vector LLVM modules + host stub).

## 5. Status / notes
- EmitC + A3/A5 is the default, mature path.
- VPTO backend is functional but newer; `--vpto-lowering-strategy` is the one knob that selects a
  `pto-isa` implementation variant from the CLI.
- The `ExpandTileOp` path (and thus the Tilelang daemon) is engaged as part of expansion; see
  [03-tilelang-dsl-and-expandtileop.md](03-tilelang-dsl-and-expandtileop.md).
