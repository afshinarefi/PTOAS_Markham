# 01 — PTO/VPTO Dialect & Compiler Pass Pipeline

The compiler core: the MLIR dialect(s) and the ordered sequence of passes that turn `.pto`
into emitted code. For the CLI flags that drive this, see
[04-ptoas-cli-and-backends.md](04-ptoas-cli-and-backends.md).

## 1. Two dialects: PTO and VPTO

Both live under the `pto` MLIR namespace; they are two abstraction levels.

### PTO dialect — high-level tile world
Defs: `include/PTO/IR/PTOOps.td` (~6.5k lines), `PTOTypeDefs.td`, `PTODialect.td`, `PTOAttrs.td`,
`PTOInterfaces.td`. Operates on logical tiles and memory views. Op categories:

- **Pointer / view**: `pto.addptr`, `pto.castptr`, `pto.ptrtoint`/`inttoptr`,
  `pto.make_tensor_view`, `pto.partition_view`, `pto.tensor_view_addr`, `pto.tile_buf_addr`.
- **Tile management**: `pto.alloc_tile`, `pto.bind_tile`, `pto.materialize_tile`, `pto.subview`,
  `pto.set_validshape` / `pto.get_validshape`.
- **DMA / data movement**: `pto.tload`, `pto.tstore`, `pto.tprefetch[_async]`, `pto.ttrans`, `pto.tmov`.
- **Compute (TileOps)**: `pto.tmatmul[.bias/.acc/.mx]`, `pto.tgemv[...]`, and the ~90 elementwise/
  reduction `pto.t*` ops (`tadd`, `tsub`, `tmul`, `texp`, `tcolmax`, …) that `ExpandTileOp` expands.
- **Pipe / sync**: `pto.initialize_*_pipe`, `pto.tpush`/`tpop`/`tfree`, `pto.reserve_buffer`,
  `pto.record_event`/`wait_event` (high-level) → `pto.set_flag`/`wait_flag` (low-level after lowering).
- **Scalar / system**: `pto.load_scalar`/`store_scalar`, `pto.get_block_idx`, `pto.get_subblock_idx`, `pto.bitcast`.

Key **types** (`PTOTypeDefs.td`): `!pto.ptr<elem, space>`, `!pto.tensor_view<...>`,
`!pto.partition_tensor_view<...>`, `!pto.tile_buf<dxdxelem, space, valid_shape, config>` (the central
physical-tile type), `!pto.local_array`, `!pto.pipe`, `!pto.async_session`/`async_event`, FP8 `!pto.hif8`.

**Address spaces** (`PTOAttrs.td`): `GM` (global), `VEC` (UB/vector local), `MAT`, `LEFT`/`RIGHT`/`BIAS`/`SCALING` (L1 slots), `ACC` (L0C).
**Pipes** (`PIPE` enum): `PIPE_V` (vector), `PIPE_M` (matrix), `PIPE_S` (scalar), `PIPE_MTE1..5` (DMA engines), `PIPE_FIX`, `PIPE_ALL`.

### VPTO dialect — low-level vector world
Defs: `include/PTO/IR/VPTOOps.td` (~3.3k lines), `VPTOTypeDefs.td`, `VPTOInterfaces.td`. Maps almost
directly to hardware instructions. Op categories: vector load/store (`pto.vlds`, `pto.vsts`,
`pto.vldsx2`), vector arithmetic (`pto.vadd`, `pto.vmul`, …), SIMT (`pto.get_tid_*`, `pto.shuffle_*`,
`pto.syncthreads`), scalar mem (`pto.load`/`store`, `pto.ldg`/`stg`), DMA copies (`pto.copy_gm_to_ubuf`,
`pto.load_cbuf_to_ca/cb`, `pto.copy_matrix_cc_to_gm`), atomics, control-register config, and MAD
matrix ops (`pto.mad_semantic_*` / `pto.mad_raw_*`).
Key **types**: `!pto.vreg<count, elem>` (256-byte vector register), `!pto.mask<granularity>` (`b8`/`b16`/`b32`), `!pto.align`.

> **Tile world vs memref world** is the central mental model. PTO IR starts in the "tile world"
> (`!pto.tile_buf`/`!pto.tensor_view`). The `pto-view-to-memref` pass lowers it to a "memref world"
> (memref + binding metadata) so memory planning and sync analysis can run; `pto-materialize-tile-handles`
> re-wraps memrefs as tile handles just before backend emission.

## 2. The pass pipeline (order)

Built in `tools/ptoas/ptoas.cpp` (pipeline construction ≈ lines 1720–1866; VPTO branch ≈ 1461–1576).
Pass declarations in `include/PTO/Transforms/Passes.td`; implementations in `lib/PTO/Transforms/`.
Architecture is auto-detected from the module's `pto.target_arch` attr or `--pto-arch`
(`driver.cpp:77–89`).

### Stage 1 — Frontend lowering & normalization
| Pass | File | Does |
|------|------|------|
| `pto-assign-default-frontend-pipe-id` | `PTOAssignDefaultFrontendPipeIdPass.cpp` | Default `id=0` on frontend TPUSH/TPOP (back-compat) |
| `pto-lower-frontend-pipe-ops` | `PTOLowerFrontendPipeOpsPass.cpp` | Frontend pipe ops → internal pipe IR |
| `pto-infer-validate-pipe-init` | `PTOInferValidatePipeInitPass.cpp` | Infer/validate `nosplit` pipe-init config |
| `pto-lowering-sync-to-pipe` | `LoweringSyncToPipe.cpp` | `record_event`/`wait_event` → `set_flag`/`wait_flag` |
| `pto-infer-layout` *(opt)* | `InferPTOLayout.cpp` | Compute ND/DN/NZ layout for static `make_tensor_view` |
| `pto-a5-normalize-tmov` | `PTOA5NormalizeTMovPass.cpp` | Rewrite unsafe A5 vec→vec col_major TMOV |
| `pto-validate-inttoptr-uses` | `PTOValidateIntToPtrUses.cpp` | Restrict `inttoptr` results to scalar load/store |

### Stage 2 — Frontend fusion (A5 + level2/3, only when `--enable-op-fusion`)
| Pass | Does |
|------|------|
| `pto-fusion-plan` | Build conservative tile-fusion groups (`pto.fusion.group_id`/`order`) |
| `pto-op-scheduling` | Compact fusion groups into contiguous block spans |
| `pto-mark-last-use` | Annotate last-use bit masks for scheduled groups |

### Stage 3 — Shared mainline: view → memref + memory planning
| Pass | File | Does |
|------|------|------|
| `pto-view-to-memref` | `PTOViewToMemref.cpp` | `tile_buf`/`tensor_view` → memref + binding metadata |
| `pto-plan-memory` | `PTOPlanMemory.cpp` | Assign physical local addresses (alloc → address literals). **Skipped at level3** |
| `pto-resolve-reserved-buffers` | `PTOResolveReservedBuffersPass.cpp` | Resolve `reserve_buffer`/`import_reserved_buffer`, align pipe-flag bases |

### Stage 4 — Synchronization insertion (choose exactly one)
| Pass | File | When |
|------|------|------|
| `pto-insert-sync` | `InsertSync/*.cpp` | **Default** — dependency analysis → set_flag/wait_flag |
| `pto-bufid-sync` | `PTOBufidSync.cpp` | A5 alternative — get_buf/rls_buf wrapping |
| `pto-inject-barrier-all-sync` | `PTOInjectBarrierAllSync.cpp` | Conservative fallback — `PIPE_ALL` barrier before each mem-effect op |
| `pto-graph-sync-solver` | `PTOGraphSyncSolver.cpp` | ⚠️ Experimental — graph/event-coloring solver (bishengir port) |

### Stage 5 — Materialization (seam point)
| Pass | File | Does |
|------|------|------|
| `pto-materialize-tile-handles` | `PTOMaterializeTileHandles.cpp` | Re-wrap local memrefs as `pto.materialize_tile` handles |
| *CSE* (built-in) | — | Common subexpression elimination |

This is the **seam IR** — the shared pre-backend snapshot. Dump it with `--pto-print-seam-ir` /
`--pto-seam-ir-file`. Both backends below consume it.

### Stage 6 — Backend split
**EmitC backend** (`--pto-backend=emitc`, default):
| Step | File | Does |
|------|------|------|
| `createEmitPTOManualPass(A3\|A5)` | `PTOToEmitC.cpp` | PTO IR → EmitC (typed C++ calls); arch-specific |
| `emit-c-form-expressions` + CSE | MLIR built-in | Build C expressions |
| C++ post-process | `CppPostprocess.cpp` | Drop dead EmitC, materialize CFG, topo-order functions, rewrite marker strings (tile get/set value, async events, ptr scalar) → C++ |
| Translate EmitC → C++ | MLIR built-in | Emit final `.cpp` (or object) |

**VPTO backend** (`--pto-backend=vpto`):
| Pass | File | Does |
|------|------|------|
| `vpto-expand-wrapper-ops` | `VPTOExpandWrapperOps.cpp` | Expand VPTO wrapper ops (bridge/DMA/cube/MAD-semantic) to low-level VPTO |
| canonicalize + CSE | built-in | — |
| `vpto-ptr-normalize` | `VPTOPtrNormalize.cpp` | Normalize ptr-like values to `!pto.ptr` |
| `vpto-ptr-cast-cleanup` | `VPTOPtrCastCleanup.cpp` | Collapse transient ptr↔memref bridge casts |
| reconcile unrealized casts + CSE | built-in | — |
| `pto-infer-vpto-vecscope` | `PTOInferVPTOVecScope.cpp` | Infer missing `pto.vecscope` regions for vector clusters |
| `pto-validate-vpto-emission-ir` | `PTOValidateVPTOIR.cpp` | Verify final emission-stage VPTO legality |
| VPTO LLVM emit | `VPTOLLVMEmitter.cpp`, `VPTOCANN900LLVMEmitter.cpp` | LLVM IR → (Bisheng-LLVM) object / fatobj + optional CANN host stub |

### Where ExpandTileOp fits
`pto-expand-tile-op` (`ExpandTileOp.cpp`) and its companions `pto-fold-tile-buf-intrinsics`
(`FoldTileBufIntrinsics.cpp`), `pto-inline-libcall` (`PTOInstantiateAndInlineOpLib.cpp`),
`pto-lower-to-oplib-calls` (`PTOLowerToOpLibCalls.cpp`) are the bridge from a high-level
`pto.t*` TileOp to a concrete micro-instruction body, by calling the **tilelang-dsl** templates
through the Tilelang daemon. Full detail in
[03-tilelang-dsl-and-expandtileop.md](03-tilelang-dsl-and-expandtileop.md).

## 3. End-to-end diagram

```
.pto / .ptobc
   │ parse + detect arch (a3/a5)
   ▼
[1] frontend lowering & normalization
   ▼
[2] (A5 + level2/3 + --enable-op-fusion) fusion plan / schedule / mark-last-use
   ▼
[3] view→memref → plan-memory (skip @level3) → resolve-reserved-buffers
   ▼
[4] sync insertion  (insert-sync | bufid-sync | barrier-all | graph-solver)
   ▼
[5] materialize-tile-handles + CSE        ◀── SEAM IR (shared) ──▶
   ├───────────────── EmitC backend ──────────────┐   └─── VPTO backend ───┐
   │ emit-pto-manual(A3|A5) → form-expr → CSE      │   │ expand-wrapper      │
   │ → C++ post-process → EmitC→C++                │   │ → ptr-normalize     │
   ▼                                               │   │ → vecscope-infer    │
 C++ source / object  ──── link ────▶ pto-isa lib  │   │ → validate → LLVM   │
                                                       ▼
                                                 object/fatobj + host stub
```

## 4. Status / notes
- **Default mainline (EmitC, A3/A5, insert-sync)** is the mature path.
- ⚠️ `pto-graph-sync-solver` is experimental (alternative to insert-sync).
- ⚠️ VPTO backend infrastructure is present and exercised but is the newer/less-default path.
- TFREE verification pass (`pto-verify-tfree`, `PTOVerifyTFreePass.cpp`) exists but is
  **commented out** of the default pipeline in `ptoas.cpp` (~line 1730).
- `--enable-tile-op-expand` is **deprecated**; TileOp expansion is now gated by `--pto-backend`
  selection (`ptoas.cpp:351–356`).
