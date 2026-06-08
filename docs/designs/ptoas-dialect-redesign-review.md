<!--
Copyright (c) 2026 Huawei Technologies Co., Ltd.
This program is free software, you can redistribute it and/or modify it under the terms and conditions of
CANN Open Software License Agreement Version 2.0 (the "License").
Please refer to the License for details. You may not use this file except in compliance with the License.
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
See LICENSE in the root of the software repository for the full text of the License.
-->

# PTOAS Dialect Redesign Review

## Problem

PTOAS currently has one effective dialect namespace, `pto`, carrying several
abstraction levels:

- High-level tile ops: `pto.tadd`, `pto.tload`, `pto.tstore`,
  `pto.trowsum`, and related tile instructions.
- Descriptor/view ops: `pto.make_tensor_view`, `pto.partition_view`,
  `pto.alloc_tile`.
- Low-level VPTO micro ops: `pto.vlds`, `pto.vadd`, `pto.vsts`, masks, flags,
  MTE ops, and `pto.vecscope`.
- Backend-specific control, synchronization, and memory details.

Even though the source is split into `PTOOps.td` and `VPTOOps.td`,
`VPTOOps.td` is included into the same `PTO_Dialect`. This is file
organization, not a real dialect boundary.

That makes optimization hard because tile ops are too high-level for loop
transformations, while VPTO ops are already too low-level and hardware-shaped.
The missing layer is an explicit structured compute IR between tile intent and
VPTO micro instructions.

### Current Design Problems

#### Unclear Dialect Boundaries

- `pto` mixes frontend descriptors, tile library ops, memory planning hooks,
  synchronization, scalar pointer ops, and VPTO micro ops.
- `!pto.tile_buf` is both a source-level tile value and a memory-planning or
  backend storage object.
- `!pto.ptr`, `!pto.vreg`, `!pto.mask`, MTE ops, and tile ops share the same
  dialect identity, so pass legality cannot easily say "PTO is still
  high-level" or "PTO is now VPTO".
- Tile and micro authoring can coexist intentionally, but the compiler has no
  hard IR boundary that distinguishes the two levels.

#### Misplaced Abstraction

- `pto.tadd` is too high-level for generic MLIR loop fusion because its
  iteration domain is implicit in `tile_buf` valid shape.
- `pto.vadd` and `pto.vlds` are too low-level for algebraic fusion because
  masks, vector register width, and memory pipes are already exposed.
- `pto.fusion.group_id`, `pto.fusion.order`, and `pto.last_use` are backend
  scheduling and codegen metadata, not a middle IR representation of fused
  computation.
- Some tile op semantics are encoded in Python TileLang templates, which makes
  them opaque to MLIR analyses.

#### Where This Hurts

- Lowering has to recover semantics from many op-specific templates and type
  conventions.
- Verification is split across op verifiers, type conventions, and pass
  assumptions.
- Testing fusion mostly checks annotations and final C++ `last_use`, not fused
  loop semantics.
- Optimization is constrained to block-local tile chains with proven static
  domains, not general structured compute.
- The same dialect contains ops from authoring, optimization, and final
  backend stages, so pass pipelines have to rely on ad hoc checks instead of
  dialect conversion legality.

## Direct Answers

### 1. Is Current Fusion Like Loop Fusion?

No. The current fusion path is not loop fusion.

The current path is:

```text
pto-fusion-plan
  -> pto-op-scheduling
  -> pto-mark-last-use
  -> normal tile lowering
```

`pto-fusion-plan` groups supported tile compute ops such as `tadd`, `tsub`,
`tmul`, `tdiv`, `tmax`, `tmin`, `texp`, `texpands`, and some row-expand ops.
`pto-op-scheduling` moves grouped ops into contiguous block-local spans when
safe. `pto-mark-last-use` annotates tile operands with `pto.last_use`.

Later, tile ops are still expanded through TileLang templates by
`pto-expand-tile-op`, then inlined. There is no generated fused loop nest like:

```mlir
for i, j:
  tmp = a[i, j] + b[i, j]
  out[i, j] = tmp * c[i, j]
```

The current "fusion" is closer to conservative scheduling plus lifetime/backend
hinting. It may help generated C++ or library calls use
`[[pto::last_use(... )]]`, but it is not MLIR loop fusion.

Recommendation:

- Keep the current pass as a low-risk backend hint path.
- Add a real structured fusion path that creates explicit fused computation IR.
- Do not describe the current pass as loop fusion in docs or design reviews.

### 2. Is There a Need to Convert from `linalg.generic` to `vector`?

Not as a mandatory project-wide step.

Use `linalg.generic` for pure structured tensor or tile computations where the
semantics are naturally elementwise, broadcast, or reduction. Use MLIR `vector`
dialect as an optional transient lowering for portable vectorization
experiments.

However, final A5 VPTO wants explicit vector registers, masks, vector scopes,
MTE, and synchronization. Standard `vector.transfer_read` / `vector.add` does
not naturally model all VPTO constraints.

Recommendation:

- Use `linalg.generic` selectively for structured optimization.
- Use `vector` selectively if it helps with canonical vectorization.
- Lower to a project-owned `vpto` dialect for final micro-ISA semantics.
- Do not make `linalg -> vector` a required stage for every PTO op.

Tradeoff:

- `linalg` and `vector` give access to existing MLIR transformations.
- They can also hide hardware-specific details that VPTO lowering needs.
- A PTO-specific structured dialect can preserve both optimization structure
  and hardware lowering metadata.

### 3. Is It Possible to Convert to Affine Loops?

Yes, but only for a subset.

Good affine candidates:

- Static or symbol-bounded tile loops.
- Elementwise tile ops over rectangular valid regions.
- Row and column reductions with affine indexing.
- `partition_view` / `memref.subview` cases with linear offsets and strides.

Risky or non-affine cases:

- Gather/scatter and indirect indexing.
- Data-dependent bounds.
- Complex fractal or layout remapping unless represented as affine maps.
- Predicate packing, special mask layout, or hardware-specific vector
  distribution.
- Dynamic valid-shape cases if bounds are not valid affine symbols.

Recommendation:

- Lower eligible middle-IR regions to `affine.for` only after a verifier proves
  affine legality.
- Lower the rest to `scf.for`.
- Treat affine as an optimization route, not the universal middle
  representation.

### 4. How Much Benefit Does the Proposal Provide?

The benefit is moderate to high, but not automatic.

High-benefit cases:

- Elementwise chains, because intermediate tile materialization can be removed.
- Broadcast plus elementwise chains.
- Simple reductions followed by elementwise ops.
- Better CSE and canonicalization around views, shapes, and scalar constants.
- More reliable fusion tests because fused computation becomes explicit.

Limited-benefit cases:

- Highly hardware-specific micro kernels already hand-written in VPTO.
- DMA/sync-heavy kernels where memory movement dominates.
- Ops whose semantics only exist as Python template bodies.
- Non-affine or irregular data movement.

Recommendation:

- The proposal is good, but incomplete if it is only
  `PTO -> linalg.generic -> affine -> VPTO`.
- Add a PTO-specific structured middle layer to preserve tile layout, valid
  region, memory space, and legal VPTO lowering decisions.

### 5. Other Refactoring Ideas

The most important change is not just splitting `pto` and `vpto`; it is
introducing a structured tile-compute dialect before VPTO.

Recommended architecture:

```text
pto source tile dialect
  -> ptile structured tile dialect
  -> linalg/scf/affine/vector where profitable
  -> vpto micro dialect
  -> LLVM/BiSheng/device artifact
```

Additional recommendations:

- Move VPTO micro types and ops into a real `vpto` dialect.
- Keep `pto` as the source/user tile ISA.
- Add semantic interfaces to existing tile ops before doing a large dialect
  split.
- Use declarative op semantics for common tile ops instead of relying only on
  Python templates.
- Keep template fallback for complex or fast-evolving tile ops.

## Goals

- Keep `pto` as the user-facing tile/kernel dialect.
- Split VPTO micro instructions into a real `vpto` dialect.
- Add a middle structured dialect for tile-local compute graphs and
  loop/vector optimization.
- Make fusion a semantic transformation, not only metadata.
- Preserve hardware-specific concepts only where they belong: tile layout in
  tile dialect, vector registers/masks/pipes in VPTO.
- Provide a migration path that keeps current tests and backend behavior alive.

## Non-goals

- Do not force every PTO op through `linalg.generic`.
- Do not model VPTO as standard MLIR `vector` ops only.
- Do not rely on affine/polyhedral optimization for all kernels.
- Do not remove current tile templates immediately.
- Do not redesign all synchronization and memory planning in the first phase.

## Proposed Design

### Dialect Responsibilities

```text
+-----------------------------+
| pto                         |
| User/source tile ISA        |
| tensor views, tile handles, |
| tile ops, kernel attrs      |
+--------------+--------------+
               |
               v
+-----------------------------+
| ptile                       |
| Structured tile compute IR  |
| explicit domains, maps,     |
| effects, fusion regions     |
+--------------+--------------+
        |              |
        v              v
+-------------+   +-------------+
| linalg/scf  |   | affine      |
| generic opt |   | proven only |
+-------------+   +-------------+
        \              /
         v            v
+-----------------------------+
| vpto                        |
| A5 micro ISA: vreg, mask,   |
| MTE, vecscope, sync, pipes  |
+-----------------------------+
```

Recommended dialects:

- `pto`: stable user-facing tile dialect.
- `ptile`: new middle dialect for structured tile-local compute.
- `vpto`: real low-level micro dialect, moved out of `PTO_Dialect`.
- Optional `pto_pipeline`: only if synchronization and pipeline ops become large
  enough to split from `vpto`.

### `pto` Dialect

Responsibilities:

- Source-level tile instructions.
- Tensor and partition view construction.
- Tile allocation and lifetime.
- Kernel attributes and authoring-level structure.
- Compatibility with existing `.pto` files.

Representative ops:

- `pto.make_tensor_view`
- `pto.partition_view`
- `pto.alloc_tile`
- `pto.tload`
- `pto.tstore`
- `pto.tadd`, `pto.tsub`, `pto.tmul`, `pto.tdiv`
- `pto.tadds`, `pto.tmuls`
- `pto.trowsum`, `pto.trowmax`, `pto.tcolsum`
- `pto.treshape`

Types and attributes:

- `!pto.ptr<elem, space>`
- `!pto.tensor_view<...>`
- `!pto.partition_tensor_view<...>`
- `!pto.tile_buf<loc, shape x elem, valid=..., layout=...>`
- Tile layout/config attributes.
- Kernel and target attributes.

Important rule:

- `pto` should not own low-level vector-register and predicate-register types
  long term.

### `ptile` Dialect

Responsibilities:

- Structured, optimizable tile-local computation.
- Explicit iteration domains and indexing maps.
- Fusion, canonicalization, and optional lowering to `linalg`, `affine`, or
  `scf`.
- Preservation of tile layout and valid-region information needed by VPTO
  lowering.

Proposed operation set:

```mlir
ptile.program
ptile.region
ptile.tile_view
ptile.load_tile
ptile.store_tile
ptile.compute
ptile.generic
ptile.elementwise
ptile.broadcast
ptile.reduce
ptile.matmul_tile
ptile.materialize_tile
ptile.fusion_group
ptile.yield
```

Proposed types:

```mlir
!ptile.tile<32x32xf32, loc=ub, layout=row_major, valid=32x32>
!ptile.view<?x?xf32, space=gm, layout=...>
!ptile.scalar<f32>
```

Proposed attributes:

```mlir
#ptile.indexing_map<(i, j) -> (i, j)>
#ptile.iterator_types<parallel, parallel>
#ptile.compute_kind<elementwise>
#ptile.compute_kind<row_reduce>
#ptile.compute_kind<col_reduce>
#ptile.lowering_hint<vector_width=64, mask=b32, pipe=V>
#ptile.layout<row_major>
#ptile.valid_shape<32x32>
```

Suggested traits and interfaces:

- `DestinationStyleOpInterface` for compute ops.
- `MemoryEffectOpInterface`.
- `TilingInterface`.
- `LoopLikeOpInterface` where applicable.
- Custom `TileIterationDomainInterface`.
- Custom `TileLayoutInterface`.
- Custom `VPTOLoweringInterface`.

Verification rules:

- All fused members must share compatible iteration domains or have explicit
  broadcast/reduction maps.
- Destination valid region must define the iteration space unless the op
  explicitly says otherwise.
- Element types and valid shapes must match op family constraints.
- Layout/fractal attributes must either be layout-transparent or explicitly
  lowerable.
- No `vpto` vector register, mask, MTE, or `vecscope` ops are allowed inside
  `ptile`.
- `ptile -> affine` is allowed only when maps and bounds are affine.

Canonicalization and folding:

- Fold identity `ptile.materialize_tile`.
- Compose `partition_view` and `tile_view` offsets.
- Remove dead intermediate tile materializations inside fused groups.
- Fuse producer-consumer `ptile.elementwise`.
- Fold scalar splat/broadcast into elementwise body.
- CSE equal tile views and constants.
- Convert static valid-shape queries to constants.
- Sink stores after fused compute when no intervening use exists.

### `vpto` Dialect

Responsibilities:

- A5 micro-ISA representation.
- Vector register and mask types.
- Explicit vector scopes.
- MTE, vector arithmetic, predicate operations, scalar/SIMT operations, and
  synchronization.
- Final backend handoff to VPTO LLVM/BiSheng emission.

Representative ops:

- `vpto.vecscope`
- `vpto.vlds`
- `vpto.vsts`
- `vpto.vadd`, `vpto.vsub`, `vpto.vmul`, `vpto.vdiv`
- `vpto.vadds`, `vpto.vmuls`
- `vpto.pset`, `vpto.plt`
- `vpto.mte_gm_ub`, `vpto.mte_ub_gm`
- `vpto.set_flag`, `vpto.wait_flag`
- `vpto.barrier`

Types:

```mlir
!vpto.vreg<64xf32>
!vpto.mask<b32>
!vpto.align
!vpto.ptr<f32, ub>
```

The project may decide whether `ptr` remains shared in `pto` or moves to a
common dialect. The cleanest long-term model is a shared low-level memory type
or a `vpto.ptr` type for micro IR.

## Examples

### Example 1: Elementwise Chain

Current IR:

```mlir
%tmp0 = pto.alloc_tile : !pto.tile_buf<vec, 32x32xf32>
%tmp1 = pto.alloc_tile : !pto.tile_buf<vec, 32x32xf32>

pto.tadd ins(%a, %b : !pto.tile_buf<vec, 32x32xf32>,
                          !pto.tile_buf<vec, 32x32xf32>)
         outs(%tmp0 : !pto.tile_buf<vec, 32x32xf32>)
pto.tmul ins(%tmp0, %c : !pto.tile_buf<vec, 32x32xf32>,
                            !pto.tile_buf<vec, 32x32xf32>)
         outs(%tmp1 : !pto.tile_buf<vec, 32x32xf32>)
```

Current fusion result:

```mlir
pto.tadd ... {pto.fusion.group_id = 0 : i64, pto.fusion.order = 0 : i64}
pto.tmul ... {pto.fusion.group_id = 0 : i64, pto.fusion.order = 1 : i64}
```

This is metadata only. It does not produce a fused computation body.

Proposed middle IR:

```mlir
ptile.generic ins(%a, %b, %c)
              outs(%out)
              indexing_maps = [
                affine_map<(i, j) -> (i, j)>,
                affine_map<(i, j) -> (i, j)>,
                affine_map<(i, j) -> (i, j)>,
                affine_map<(i, j) -> (i, j)>]
              iterator_types = ["parallel", "parallel"] {
^bb0(%av: f32, %bv: f32, %cv: f32, %old: f32):
  %s = arith.addf %av, %bv : f32
  %r = arith.mulf %s, %cv : f32
  ptile.yield %r : f32
}
```

Lowering:

```text
pto.tadd/tmul
  -> ptile.generic
  -> linalg.generic or affine.for/scf.for
  -> vectorized loop plan
  -> vpto.vecscope + vpto.vlds/vpto.vadd/vpto.vmul/vpto.vsts
```

Why this is better:

- The intermediate tile `%tmp0` is not materialized unless needed.
- Fusion is actual computation fusion.
- The fused body can be tested and optimized directly.

### Example 2: Broadcast Scalar Add

Current IR:

```mlir
pto.tadds ins(%a, %alpha : !pto.tile_buf<vec, 32x32xf32>, f32)
          outs(%out : !pto.tile_buf<vec, 32x32xf32>)
```

Proposed middle IR:

```mlir
ptile.elementwise ins(%a, %alpha) outs(%out)
    maps = [
      affine_map<(i, j) -> (i, j)>,
      affine_map<(i, j) -> ()>,
      affine_map<(i, j) -> (i, j)>] {
^bb0(%x: f32, %alpha_value: f32, %old: f32):
  %r = arith.addf %x, %alpha_value : f32
  ptile.yield %r : f32
}
```

Lowering choices:

- Lower to `linalg.generic` if staying generic.
- Lower directly to `vpto.vadds` if the op maps exactly to a VPTO vector-scalar
  instruction.

Why this is better:

- Scalar-vs-tile semantics become explicit.
- The op can fuse with neighboring elementwise tile ops.
- The backend can still select the direct vector-scalar instruction.

### Example 3: Row Reduction

Current IR:

```mlir
pto.trowsum ins(%a : !pto.tile_buf<vec, 32x32xf32>)
            outs(%out : !pto.tile_buf<vec, 32x1xf32>)
```

Proposed middle IR:

```mlir
ptile.reduce kind = #ptile.reduce<add>
  ins(%a : !ptile.tile<32x32xf32>)
  outs(%out : !ptile.tile<32x1xf32>)
  dimensions = [1]
```

Lowering:

```text
ptile.reduce
  -> linalg.generic with reduction iterator, if legal
  -> affine.for/scf.for nest
  -> vpto reduction sequence or template fallback
```

Why this is better:

- Reductions become visible to fusion and canonicalization.
- A following scalar multiply or add can be fused into the reduction epilogue.
- The verifier can check that output shape matches the reduced dimension.

### Example 4: Tile Load, Compute, Store

Current IR:

```mlir
%a = pto.alloc_tile : !pto.tile_buf<vec, 32x32xf32>
%b = pto.alloc_tile : !pto.tile_buf<vec, 32x32xf32>
%c = pto.alloc_tile : !pto.tile_buf<vec, 32x32xf32>

pto.tload ins(%aview : !pto.partition_tensor_view<32x32xf32>)
          outs(%a : !pto.tile_buf<vec, 32x32xf32>)
pto.tload ins(%bview : !pto.partition_tensor_view<32x32xf32>)
          outs(%b : !pto.tile_buf<vec, 32x32xf32>)
pto.tadd ins(%a, %b : !pto.tile_buf<vec, 32x32xf32>,
                        !pto.tile_buf<vec, 32x32xf32>)
         outs(%c : !pto.tile_buf<vec, 32x32xf32>)
pto.tstore ins(%c : !pto.tile_buf<vec, 32x32xf32>)
           outs(%cview : !pto.partition_tensor_view<32x32xf32>)
```

Proposed staged IR:

```mlir
%a = ptile.load_tile %aview : !ptile.view<32x32xf32> -> !ptile.tile<32x32xf32>
%b = ptile.load_tile %bview : !ptile.view<32x32xf32> -> !ptile.tile<32x32xf32>

%c = ptile.generic ins(%a, %b) outs(%init)
       iterator_types = ["parallel", "parallel"] {
^bb0(%x: f32, %y: f32, %old: f32):
  %r = arith.addf %x, %y : f32
  ptile.yield %r : f32
}

ptile.store_tile %c, %cview : !ptile.tile<32x32xf32>, !ptile.view<32x32xf32>
```

Lowering:

```text
ptile.load_tile  -> vpto.mte_gm_ub
ptile.generic    -> vpto.vecscope with vector load/add/store loop
ptile.store_tile -> vpto.mte_ub_gm
sync insertion   -> vpto.set_flag / vpto.wait_flag or bufid sync
```

Why this is better:

- Data movement and computation are separate but structured.
- Compute fusion can happen between load and store.
- Sync insertion can operate after compute/data movement boundaries are known.

## Lowering Strategy

Recommended pipeline:

```text
parse pto
canonicalize pto views/shapes
verify pto source legality
convert pto tile compute -> ptile
ptile canonicalize/CSE
ptile fusion
optional ptile -> linalg.generic
optional linalg fusion/canonicalization
legal subset -> affine.for
fallback -> scf.for
lower ptile/linalg/scf/affine -> vpto
vpto canonicalize/verify
insert sync / bufid sync / graph sync
emit VPTO / C++ / device artifact
```

The pipeline should keep a fallback path:

```text
unsupported pto tile op -> current TileLang template expansion
supported pto tile op   -> ptile structured lowering
```

This avoids blocking migration on modeling every tile op at once.

### Recommended Lowering Policy

- `pto -> ptile`: semantic lowering from source tile ops to structured compute.
- `ptile -> linalg`: only for pure structured elementwise/broadcast/reduction
  cases.
- `ptile -> affine`: only after affine legality is proven.
- `ptile -> scf`: general structured fallback.
- `ptile/scf/affine -> vpto`: target-specific lowering that selects vector
  width, masks, vector scopes, and micro ops.
- `vpto -> backend`: existing VPTO emission path.

## Risks

- Full `pto -> linalg.generic` may erase hardware information too early.
- Affine legality will cover less than expected unless view/layout maps are
  formalized.
- Splitting `vpto` into a new dialect is mechanically large: ODS, C++
  namespaces, Python bindings, tests, docs, and generated files must all move.
- Template-based TileOps currently encode semantics outside MLIR; structured
  optimization cannot reason about those until each op has a declarative
  semantic model.
- A middle dialect creates another lowering contract that needs strong verifier
  coverage.
- A partially migrated system can become confusing if `pto`, `ptile`, and
  `vpto` are not guarded by clear pipeline legality checks.

## Migration Plan

### Minimal-risk First Step

- Keep existing `pto` syntax.
- Add operation interfaces to tile ops:
  - iteration domain,
  - indexing maps,
  - compute family,
  - layout behavior,
  - memory effects.
- Replace fusion metadata-only planning with an optional `ptile.fusion_group`
  IR dump for supported ops.
- Keep current `pto.fusion.*` and `pto.last_use` path for backend compatibility.
- Add tests proving that `tadd -> tadd`, diamond, broadcast, and reduction
  cases lower to equivalent current VPTO/C++.

### Medium-term Redesign

- Create real `vpto` dialect and move `VRegType`, `MaskType`, `AlignType`,
  `vecscope`, vector ops, MTE ops, sync ops, and micro ops there.
- Introduce `ptile.generic`, `ptile.elementwise`, and `ptile.reduce`.
- Convert supported `pto.t*` ops to `ptile`.
- Add `ptile -> linalg` only for ops whose indexing maps are natural linalg
  maps.
- Add `ptile -> vpto` direct lowering for hardware-specific fast paths.
- Add pass legality checks that reject unexpected abstraction levels at each
  pipeline boundary.

### Long-term Cleanup

- Make `pto` only the source/user tile ISA.
- Make `ptile` the only optimization IR for tile compute.
- Make `vpto` the only micro/backend dialect.
- Gradually retire Python template semantics for simple
  elementwise/broadcast/reduction ops.
- Keep templates for complex or fast-evolving instructions until they have
  declarative models.
- Update docs so "PTO Tile Instruction", "PTO structured tile IR", and
  "VPTO micro Instruction" are distinct layers.

### Tests to Add

- Dialect boundary verifier tests:
  - no `vpto` ops in `pto` or `ptile` regions before lowering,
  - no `pto` tile ops after `pto -> ptile`,
  - no `ptile` ops after `ptile -> vpto`.
- `pto -> ptile` conversion tests for:
  - `tadd`,
  - `tadds`,
  - `tmul`,
  - `texp`,
  - `trowsum`.
- Fusion tests checking one `ptile.generic` instead of only
  `pto.fusion.group_id`.
- Affine legality positive and negative tests.
- Fallback tests proving unsupported tile ops still use current template path.
- End-to-end equivalence tests against existing `test/lit/tile_fusion` and
  `test/vpto`.
- Verifier tests for dynamic valid shapes, incompatible layouts, reduction
  shape mismatch, and illegal broadcast maps.

## Concise Final Proposal

Keep `pto` as the public tile dialect, split VPTO into a real `vpto` dialect,
and add a structured middle dialect, preferably `ptile`, for tile-local
computation. Do not make `linalg.generic` the only middle IR. Use it
opportunistically after PTO-specific tile semantics are explicit.

The current fusion pass is useful but shallow: it groups, schedules, and marks
last use; it does not build fused loop bodies. The redesign should make fusion
explicit in IR through `ptile.generic` and `ptile.reduce`, then lower legal
subsets through `linalg`, `affine`, or `scf`, and finally to `vpto`.

The highest-value first implementation is elementwise/broadcast fusion for
`tadd`, `tsub`, `tmul`, `tdiv`, `tmax`, `tmin`, `texp`, `tadds`, `tmuls`, and
similar ops. That gives real optimization benefit without requiring the whole
Tile ISA to be redesigned at once.
