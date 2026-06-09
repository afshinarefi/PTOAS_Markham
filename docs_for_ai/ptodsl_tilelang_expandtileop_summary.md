# Context summary: PTODSL / TileLang DSL / ExpandTileOp migration discussion

We are investigating the intended migration path from `tilelang-dsl` to the new `ptodsl` flow in the PTOAS project, especially how this affects `ExpandTileOp`, TileLib-style templates, and version selection.

## Current architecture understanding

There are two relevant Python DSL paths:

### 1. `tilelang-dsl`

- Currently used inside PTOAS, especially by `ExpandTileOp`.
- `ExpandTileOp` sees a TileOp such as `pto.tadd`, invokes a TileLang template, receives specialized MLIR, then parses/inlines it.
- Example template:

```python
import tilelang_dsl as pto

@pto.vkernel(target="a5", op="pto.tadd")
def template_tadd(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape

    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            lhs = pto.vlds(src0[row, col:])
            rhs = pto.vlds(src1[row, col:])
            summed = pto.vadd(lhs, rhs, mask)
            pto.vsts(summed, dst[row, col:], mask)
```

### 2. `ptodsl`

- New Python DSL path.
- Can emit PTO MLIR directly.
- Has examples like:
  - `tadd_launch.py`: high-level tile API using `pto.tile.load`, `pto.tile.add`, `pto.tile.store`.
  - `tadd_dsl.py`: low-level standalone vector example using explicit `castptr`, `addptr`, `vlds`, `vadd`, `vsts`.
  - `tadd_lowlevel.py`: raw MLIR Python binding version, manually constructing the same kind of IR as `tadd_dsl.py`.

## Important correction from Alan Wang

We asked the China team whether future PTODSL TileLib templates should look more like `tadd_dsl.py` with bare pointers, or more like TileLang templates using `src0[row, col:]`.

Alan clarified:

- Future PTODSL TileLib templates should **follow the TileLang-style tile indexing**, not the bare-pointer style.
- Avoid bare pointers like in `tadd_dsl.py`.
- The reason is compiler analysis:
  - Bare pointers make alias analysis difficult.
  - Missing tile information makes optimizations harder.
  - `tile[row, col:]` preserves tile information.
  - `tile[row, col:]` automatically calculates offsets.
  - It lowers to a memref-like object with shape/layout information.
  - This enables optimizations like loop fusion, load-store elimination, and other structured memory analyses without complex pointer alias analysis.
- `tadd_dsl.py` is just a standalone PTODSL example, not the intended TileLib template style.
- `tile[row, col:]` is already supported in current PTODSL.
- There is currently **no proposal/integration yet** for replacing `tilelang-dsl` inside `ExpandTileOp` with PTODSL. We likely need to design this from scratch.
- Existing `pto.simd`, `pto.cube`, and `pto.simt` subkernel concepts may serve as the interface between TileOps and micro-instruction-level implementations.
- Still open design questions:
  - How does `ExpandTileOp` match a TileOp with a PTODSL template?
  - How are acceptable data types, tile layouts, shapes, memory spaces, etc. constrained?
  - How are multiple versions of the same op registered and selected?

## Verified PTODSL support for `tile[row, col:]`

We inspected `ptodsl/ptodsl/_surface_values.py`.

Relevant grep result:

```bash
grep -R "def __getitem__" -n ptodsl | head -50
```

Returned:

```text
ptodsl/ptodsl/_surface_values.py:378:    def __getitem__(self, index: int):
ptodsl/ptodsl/_surface_values.py:479:    def __getitem__(self, key):
ptodsl/ptodsl/_kernel_compilation.py:47:    def __getitem__(self, launch_spec):
ptodsl/ptodsl/_tile_template_tracing.py:177:    def __getitem__(self, key):
```

In `_surface_values.py`, `TileValue.__getitem__` implements tile indexing.

Key logic:

```python
class TileValue(_SurfaceValue, Tile):
    ...

    def __getitem__(self, key):
        if not isinstance(key, tuple):
            key = (key,)
        if self.shape is None:
            raise RuntimeError("tile indexing requires tile shape metadata")

        if _is_tile_slice_key(key, self.shape):
            return _materialize_tile_slice(self, key)

        ...
```

The helper recognizes `tile[row, col:]`:

```python
def _is_tile_slice_key(key, shape):
    if len(shape) == 1:
        return len(key) == 1 and isinstance(key[0], slice)
    if len(shape) == 2:
        return len(key) == 2 and isinstance(key[1], slice)
    return False
```

Then `_materialize_tile_slice` handles the 2D case:

```python
def _materialize_tile_slice(tile: TileValue, key):
    ...
    row, col_slice = key
    if col_slice.stop is not None or col_slice.step is not None:
        raise TypeError("tile[row, col:] only supports an open-ended column slice")
    col = 0 if col_slice.start is None else col_slice.start
    return _build_tile_slice_view(
        tile,
        raw_offsets=[row, col],
        shape=[_dynamic_extent(tile.shape[1], col)],
    )
```

Then `_build_tile_slice_view` lowers it through memref:

```python
def _build_tile_slice_view(tile: TileValue, *, raw_offsets, shape):
    base_memref = _emit_tile_memref(tile)
    base_type = MemRefType(base_memref.type)
    ...
    slice_value = memref.SubViewOp(...)
    return TileSliceValue(slice_value, tile=tile, offsets=tuple(raw_offsets), shape=shape)
```

And `TileSliceValue` is documented as:

```python
class TileSliceValue(_SurfaceValue):
    """Author-facing memref view produced by `tile[row, col:]` style indexing."""
```

So `src0[row, col:]` does not become raw pointer arithmetic directly. It becomes:

```text
TileValue
  -> TileSliceValue
  -> _pto.TileBufAddrOp(...)
  -> memref.SubViewOp(...)
```

This confirms Alan’s point: PTODSL already supports structured tile slicing and preserves memref/tile metadata.

## Corrected mental model

Earlier, we thought the future PTODSL TileLib template might look closer to `tadd_dsl.py`:

```python
ptr_src = pto.castptr(...)
off = scalar.muli(...)
va = pto.vlds(pto.addptr(ptr_src, off), ...)
vc = pto.vadd(...)
pto.vsts(...)
```

After Alan’s clarification and inspecting `_surface_values.py`, the corrected model is:

```text
Future PTODSL TileLib template should look closer to TileLang body style:

with pto.simd():
    lhs = pto.vlds(src0[row, col:])
    rhs = pto.vlds(src1[row, col:])
    out = pto.vadd(lhs, rhs, mask)
    pto.vsts(out, dst[row, col:], mask)

but implemented inside PTODSL, using PTODSL registration/tracing/integration,
not through the old tilelang-dsl system.
```

So the migration target is not:

```text
tilelang template -> bare-pointer tadd_dsl.py
```

Instead:

```text
tilelang template
  -> PTODSL-native TileLib template
     preserving tile[row, col:] / memref-style access
     using pto.simd / pto.cube / pto.simt subkernels
```

## Version selection discussion

We discussed whether version selection should be seen as a performance feature.

Final conclusion:

- Version selection should be framed primarily as:
  - legality / applicability
  - compile-time specialization
  - exposing implementation choices to PTOAS/MLIR
- Performance is a consequence, but not necessarily the main conceptual API.
- For example, a version may only be legal for:
  - a dtype
  - a tile layout
  - a memory space
  - a contiguous tile
  - a particular shape/rank
  - a fusion/post-update pattern
- If multiple versions are legal, a performance heuristic or cost model may choose among them later.
- But the first design should probably be deterministic/rule-based:
  - filter legal templates
  - select the best matching specialization
  - instantiate
  - canonicalize/fold

Important distinction:

```text
Current PTO-ISA:
  C++ templates already choose good internal paths using compile-time constants.
  This happens late and is hidden from MLIR/PTOAS.

Future PTODSL TileLib:
  version choice should be visible at ExpandTileOp/MLIR level.
  The selected template emits structured MLIR that can be optimized before final lowering.
```

## PTO-ISA version examples discussed

We discussed examples like A5 binary ops using `TBinOp.hpp` and `BinaryInstr`.

Possible versions:
- 1D contiguous version
- 2D strided version
- post-update version
- no-post-update version

Important nuance:

- Some choices are not really “performance choices”; they are forced by legality.
- Example: if `validCols = 70`, there must be tail handling. That is not a free performance choice.
- Better examples:
  - If a tile is contiguous, both a generic 2D traversal and a flattened 1D traversal can be legal; 1D is likely better.
  - If memory access is regular, both explicit address arithmetic and post-update style may be legal; post-update may be better.
- But in current PTO-ISA, these choices are usually hard-coded via C++ template conditions and compile-time constants, not through a compiler-visible cost model.

## Things to design for PTODSL + ExpandTileOp integration

Alan said there is no proposal yet, so likely design is needed:

### 1. Template registration

- How do we register a PTODSL template for `pto.tadd`?
- Decorator? Table? Python registry?
- Include target, op name, dtype constraints, layout constraints, shape constraints.

### 2. Template matching

`ExpandTileOp` sees a concrete TileOp and extracts context:

- op name
- target
- dtype
- tile rank/shape/valid shape
- memory space
- layout/stride
- fusion context

Then it finds legal PTODSL templates/versions.

### 3. Version selection

- Filter by hard constraints.
- Initially use deterministic priority/rule-based choice.
- Later possibly add cost model.

### 4. Instantiation interface

- How does `ExpandTileOp` pass concrete tile operands and metadata into PTODSL?
- Does PTODSL return:
  - a function?
  - a region?
  - replacement MLIR ops?
- How are generated symbols named/cached?

### 5. Subkernel interface

- Use `pto.simd`, `pto.cube`, `pto.simt` as the bridge from TileOp to micro-instructions.
- Need design for vector/cube templates.

### 6. Optimization pipeline

- Generated template should preserve tile/memref info.
- Then MLIR passes can run:
  - loop fusion
  - load-store elimination
  - alias/dependence analysis
  - canonicalization
  - lowering to pointer/vector instructions later.

## Main takeaway

```text
PTODSL TileLib templates should not use bare pointer/addptr style as the main abstraction.

They should keep tile[row, col:] style because PTODSL supports it and lowers it to memref.SubViewOp,
preserving tile shape/layout information for compiler analysis.

The pointer-style tadd_dsl.py is only a standalone example showing PTODSL can emit low-level vector IR.

The missing work is to design the integration between ExpandTileOp and PTODSL TileLib:
registration, matching, constraints, version selection, instantiation, and optimization pipeline.
```
