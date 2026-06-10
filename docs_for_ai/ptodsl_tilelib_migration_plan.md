# PTODSL TileLib Migration Planning Doc

## 0. Purpose

This document summarizes the current understanding and proposed next steps for migrating the existing `tilelang-dsl` TileLib/template flow into the new `ptodsl` infrastructure, especially for the `ExpandTileOp` path in PTOAS.

The main goal is to replace the current `ExpandTileOp -> tilelang-dsl -> generated MLIR` path with an `ExpandTileOp -> PTODSL TileLib -> generated MLIR` path, while preserving the useful tile/memref abstraction that enables compiler analysis and optimization.

---

## 1. What PR #769 changed

PR #769 (`feat(ptodsl): add AST preprocess control flow`) changes the PTODSL frontend/control-flow authoring style.

Before this PR, PTODSL examples often needed explicit builder-style control flow such as:

```python
with pto.for_(c0, c16, step=c1) as row:
    ...
```

After this PR, PTODSL should support a control-flow style closer to old `tilelang-dsl`, such as:

```python
for row in range(0, valid_rows, 1):
    ...
```

This matters for TileLib migration because current TileLang templates are already written in normal Python control-flow style. After this PR, the migration can theoretically copy the template function body much more directly.

### 1.1 Confirmed implication from Zhendong

Zhendong clarified:

> After this PR is merged, PTODSL should have the same control flow style as the old tilelang-dsl. Theoretically, you can copy the function body directly during migration.

So the target migration is not to rewrite TileLib templates into bare pointer/addptr style. Instead, it is to preserve the high-level tile access style and migrate the template infrastructure around it.

---

## 2. Flows already tested

### 2.1 PTODSL high-level tile flow works

The following PTODSL example works:

```bash
python3 ptodsl/examples/tadd_launch.py --emit-mlir > /tmp/tadd_dsl.mlir
ptoas /tmp/tadd_dsl.mlir -o /tmp/tadd.cpp 2> /tmp/tadd_stderr.log
```

This confirms that the current `ptodsl` frontend can emit MLIR and PTOAS can lower the generated MLIR to C++ for this high-level tile example.

This flow is:

```text
ptodsl/examples/tadd_launch.py
  -> emits MLIR
  -> ptoas lowers MLIR
  -> C++ output
```

This is useful as a standalone PTODSL frontend validation, but it is not the full TileLib/`ExpandTileOp` migration path.

### 2.2 Current TileLang template rendering works

The current TileLang template rendering path also works using:

```bash
python3 - <<'PY'
import runpy, sys
sys.argv = [
    "render_template_mlir.py",
    "lib/TileOps/tadd_template.py",
    "--tile", "dst=8x64@ub",
    "--tile", "src0=8x64@ub",
    "--tile", "src1=8x64@ub",
    "-o", "/tmp/tadd.mlir",
]
runpy.run_path("lib/TileOps/render_template_mlir.py", run_name="__main__")
PY
```

This generates `/tmp/tadd.mlir` from the existing `lib/TileOps/tadd_template.py`.

The rendered MLIR preserves tile/memref structure. It contains:

```mlir
pto.tile_buf_addr
memref.subview
pto.vlds
pto.vadd
pto.vsts
```

rather than immediately lowering to:

```mlir
pto.castptr
pto.addptr
```

This is important because it confirms the current template flow produces structured MLIR suitable for compiler analysis.

### 2.3 Important workaround for `render_template_mlir.py`

Running the script directly like this can fail:

```bash
python3 lib/TileOps/render_template_mlir.py lib/TileOps/tadd_template.py ...
```

The failure happens because `lib/TileOps/math.py` shadows Python's standard library `math` module when `lib/TileOps` is placed first in `sys.path`.

The `runpy.run_path(...)` invocation above avoids this issue.

---

## 3. Current `tilelang-dsl` flow

Today, `ExpandTileOp` can expand a TileOp by invoking `tilelang-dsl`.

The current flow is roughly:

```text
PTOAS / ExpandTileOp
  sees TileOp, e.g. pto.tadd
  builds specialization info
  calls tilelang-dsl helper
  tilelang-dsl finds the template for the op
  tilelang-dsl renders specialized MLIR
  PTOAS parses/clones/inlines/folds the generated function
```

A current TileLang template looks like:

```python
import tilelang_dsl as pto

@pto.vkernel(
    target="a5",
    op="pto.tadd"
)
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

### 3.1 Why `tile[row, col:]` matters

Alan clarified that we should preserve this style:

```python
src0[row, col:]
```

rather than using bare pointer arithmetic.

The reason is that `tile[row, col:]` keeps tile information alive in the IR. It can lower to a memref/subview object with shape, layout, memory-space, and offset information. This makes compiler optimizations easier:

- loop fusion
- load-store elimination
- dependence analysis
- alias reasoning
- structured memory optimization

Bare pointer style such as:

```python
ptr = pto.castptr(...)
ptr2 = pto.addptr(ptr, off)
```

loses much of the tile structure early and makes alias analysis harder.

---

## 4. What should be added to PTODSL

The missing work is not mainly the template body. After PR #769, the template body can be close to the existing TileLang body.

The missing work is the **TileLib infrastructure inside PTODSL**.

PTODSL should add:

1. A PTODSL-native template decorator / registration API.
2. A registry of templates by op name, target, and version.
3. Metadata/constraints attached to each template/version.
4. A selection API used by `ExpandTileOp`.
5. A rendering/instantiation API that takes concrete TileOp context and emits specialized MLIR.
6. Integration with `pto.simd`, `pto.cube`, and `pto.simt` subkernels as the interface between TileOps and micro-instruction-level implementations.
7. A return protocol so PTOAS can receive generated MLIR and integrate it into the pass pipeline.

---

## 5. Proposed PTODSL template/decorator design

Current TileLang decorator:

```python
@pto.vkernel(
    target="a5",
    op="pto.tadd"
)
def template_tadd(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    ...
```

Proposed PTODSL TileLib decorator:

```python
@pto.tile_template(
    op="pto.tadd",
    target="a5",
    name="tadd_basic_2d",
    dtypes=[
        (pto.f32, pto.f32, pto.f32),
        (pto.f16, pto.f16, pto.f16),
        (pto.i32, pto.i32, pto.i32),
    ],
    layouts=["row_major"],
    memory_spaces=["vec"],
    priority=0,
    fusible=True,
)
def tadd_basic_2d(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
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

The exact decorator name is open. Possible names:

```python
@pto.tile_template(...)
@pto.op_template(...)
@pto.tilelib_template(...)
```

The important point is that the decorator should both:

1. Register the function as an implementation of a TileOp.
2. Attach metadata used for matching, legality checking, and version selection.

---

## 6. Where decorator parsing/registration should be implemented

The decorator and metadata parsing should be implemented in PTODSL, not PTOAS.

A possible structure:

```text
ptodsl/
  ptodsl/
    tilelib/
      __init__.py
      registry.py
      metadata.py
      constraints.py
      render.py
      a5/
        __init__.py
        tadd.py
        tmul.py
        trem.py
```

### 6.1 Responsibilities in PTODSL

PTODSL should own:

- template decorator definition
- template metadata parsing
- template registry
- candidate lookup by op/target
- constraint matching
- priority/fusibility metadata
- rendering selected template to MLIR

### 6.2 Responsibilities in PTOAS / ExpandTileOp

PTOAS should own:

- extracting concrete TileOp context from MLIR
- sending that context to PTODSL TileLib
- receiving generated MLIR
- parsing/cloning/inserting the generated function or replacement
- running inline/fold/canonicalization passes

PTOAS should not hard-code per-op TileLib implementation details.

Bad design:

```cpp
if (op == "pto.tadd" && dtype == f32 && shape == 8x64) {
    call_tadd_basic_2d();
}
```

Better design:

```text
ExpandTileOp builds generic TileOp context
PTODSL TileLib registry selects template/version using metadata
ExpandTileOp receives generated MLIR
```

---

## 7. Version selection metadata

Zhendong clarified:

> Currently we only have one basic implementation for each OP, so there lacks mechanism to select version based on performance. I hope you could complete the design. The key point is we don't want the version selection logics in PTOAS to be tightly coupled with the TileLib implementation. You may want to attach some metadata to each version like fusibility or priority.

So version selection should be metadata-driven.

### 7.1 Metadata categories

There should be two categories of metadata:

#### Hard constraints

These decide whether a template is legal for a concrete TileOp.

Examples:

```python
op="pto.tadd"
target="a5"
dtypes=[(pto.f32, pto.f32, pto.f32)]
layouts=["row_major"]
memory_spaces=["vec"]
rank=2
requires=["contiguous"]
```

#### Selection hints

These rank multiple legal templates.

Examples:

```python
priority=10
fusible=True
supports_post_update=True
tags=["basic", "2d"]
```

### 7.2 Selection algorithm

A simple initial algorithm:

```text
1. lookup candidates by op and target
2. filter by hard constraints
3. if no legal candidate: error
4. if one legal candidate: choose it
5. if multiple legal candidates: choose highest priority
6. render selected template
```

Later, this can be extended with a cost model.

### 7.3 Functional vs performance selection

Current TileLib mostly has one basic implementation per op. Therefore, initial version selection is mostly functional/constraint-based.

However, the metadata system should allow future performance selection among multiple legal versions using priority, fusibility, or cost hints.

---

## 8. How to connect the new flow to `ExpandTileOp`

The proposed new flow:

```text
PTOAS / ExpandTileOp
  -> sees concrete TileOp
  -> extracts TileOp context
  -> calls PTODSL TileLib registry/render API
  -> receives generated specialized MLIR
  -> parses/clones/inlines/folds
```

### 8.1 TileOp context sent to PTODSL

`ExpandTileOp` should send a generic context object containing:

```text
op name
target
operand names
operand dtypes
operand tile shapes
operand valid shapes
memory spaces
layouts
strides/fractal/pad info if available
fusion/post-update context if available
extra context attrs
```

This is similar to the current `SpecKey` concept used by `ExpandTileOp` for `tilelang-dsl`.

### 8.2 PTODSL API shape

A possible PTODSL-side API:

```python
from ptodsl.tilelib import registry

entry = registry.select(
    op="pto.tadd",
    target="a5",
    operand_specs=[...],
    context_attrs={...},
)

mlir_text = entry.render(
    operand_specs=[...],
    context_attrs={...},
)
```

Or one combined API:

```python
mlir_text = registry.render_best(
    op="pto.tadd",
    target="a5",
    operand_specs=[...],
    context_attrs={...},
)
```

### 8.3 PTOAS-side behavior

`ExpandTileOp` should not know implementation-specific rules. It should only:

1. Build the context.
2. Call PTODSL.
3. Receive MLIR.
4. Parse and integrate it.

---

## 9. MVP proposal

The MVP should be intentionally small. Use `pto.tadd` only.

### 9.1 Goal

Create two PTODSL TileLib template entries for `pto.tadd`.

The second implementation can initially duplicate the first template body but use different metadata. This proves that:

- multiple template versions can be registered
- metadata is parsed
- candidates can be looked up
- constraints can be matched
- a version can be selected
- selected template can be rendered to MLIR

### 9.2 File layout for MVP

Possible layout:

```text
ptodsl/ptodsl/tilelib/
  __init__.py
  registry.py
  metadata.py
  constraints.py
  render.py
  a5/
    __init__.py
    tadd.py
```

### 9.3 Example MVP templates

```python
from ptodsl import pto
from ptodsl.tilelib import tile_template


@tile_template(
    op="pto.tadd",
    target="a5",
    name="tadd_basic_2d",
    dtypes=[(pto.f32, pto.f32, pto.f32)],
    layouts=["row_major"],
    memory_spaces=["vec"],
    priority=0,
    fusible=True,
    tags=["basic", "2d"],
)
def tadd_basic_2d(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
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


@tile_template(
    op="pto.tadd",
    target="a5",
    name="tadd_basic_2d_high_priority_placeholder",
    dtypes=[(pto.f32, pto.f32, pto.f32)],
    layouts=["row_major"],
    memory_spaces=["vec"],
    priority=10,
    fusible=False,
    tags=["placeholder", "duplicate-body"],
)
def tadd_basic_2d_high_priority_placeholder(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    # For MVP, intentionally duplicate the first implementation.
    # The purpose is to validate multi-version registration/selection.
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

### 9.4 MVP selection behavior

For MVP, selection can be simple:

```text
if multiple legal templates:
    choose highest priority
```

Expected result:

```text
tadd_basic_2d_high_priority_placeholder
```

is selected because its priority is `10`, while the first template has priority `0`.

### 9.5 MVP test command idea

After implementing the registry and renderer, a test command could look like:

```bash
python3 -m ptodsl.tilelib.render \
  --op pto.tadd \
  --target a5 \
  --tile dst=8x64@ub:f32 \
  --tile src0=8x64@ub:f32 \
  --tile src1=8x64@ub:f32 \
  -o /tmp/ptodsl_tadd_tilelib.mlir
```

Expected generated MLIR should preserve the same abstraction level as current `tilelang-dsl` output:

```mlir
pto.tile_buf_addr
memref.subview
pto.vlds
pto.vadd
pto.vsts
```

not bare pointer arithmetic:

```mlir
pto.castptr
pto.addptr
```

---

## 10. Next steps

### Step 1: Confirm PTODSL post-PR #769 behavior

After PR #769 is merged/rebased into the working branch, test whether a PTODSL template body can use old TileLang-style control flow directly:

```python
for row in range(0, valid_rows, 1):
    ...
```

without rewriting it into:

```python
with pto.for_(...):
    ...
```

### Step 2: Locate and reuse existing PTODSL tile indexing support

`ptodsl/ptodsl/_surface_values.py` already supports `tile[row, col:]` through:

```text
TileValue.__getitem__
_materialize_tile_slice
_build_tile_slice_view
TileSliceValue
memref.SubViewOp
```

This should be reused for the TileLib migration.

### Step 3: Implement minimal `tile_template` decorator

Start with:

```python
@tile_template(op, target, name, dtypes, layouts, memory_spaces, priority, fusible, tags)
```

The decorator should register the Python function plus metadata in a global/module registry.

### Step 4: Implement registry lookup and constraint matching

The registry should support:

```python
lookup(op, target)
select(op, target, operand_specs, context_attrs)
```

Start with simple hard constraints and priority.

### Step 5: Implement render path

Implement a renderer that:

1. Receives op/context specs.
2. Creates PTODSL tile placeholder arguments.
3. Invokes/traces the selected template.
4. Emits a standalone `func.func` MLIR with `pto.tilelang.instance`-like or new equivalent attribute.
5. Returns MLIR text.

### Step 6: Add a standalone PTODSL TileLib render command

Before integrating with PTOAS, create a standalone CLI similar to current `render_template_mlir.py`.

Example:

```bash
python3 -m ptodsl.tilelib.render ...
```

This allows testing without touching `ExpandTileOp` first.

### Step 7: Integrate with `ExpandTileOp`

Modify `ExpandTileOp` so it can call the PTODSL TileLib renderer instead of `tilelang-dsl`.

Initial integration can be behind a flag:

```text
--use-ptodsl-tilelib
```

or selected by target/backend.

### Step 8: Validate generated MLIR equivalence

For `tadd_template.py`, compare:

```text
current tilelang-dsl rendered MLIR
vs
new PTODSL TileLib rendered MLIR
```

They do not need to be textually identical, but should have the same abstraction level and semantics:

```text
tile_buf_addr
memref.subview
vlds/vadd/vsts
```

### Step 9: Run PTOAS lowering

Feed the generated PTODSL TileLib MLIR into PTOAS and verify downstream passes can parse/inline/fold/lower it.

### Step 10: Expand to one more op

After `pto.tadd`, migrate another simple op such as:

```text
pto.tmul
pto.tsub
pto.trem
```

This validates dtype constraints and more complex body patterns.

---

## 11. Open questions

1. What should the exact decorator name be?
   - `@pto.tile_template`
   - `@pto.op_template`
   - `@pto.tilelib_template`

2. Should the registry live under:
   - `ptodsl.tilelib`
   - `ptodsl.pto.tilelib`
   - another module?

3. Should generated functions keep the attribute:
   - `pto.tilelang.instance`
   
   or should PTODSL introduce a new one such as:
   - `pto.tilelib.instance`
   - `pto.ptodsl.instance`

4. How much of current `tilelang-dsl` rendering/helper code should be reused vs rewritten?

5. Should matching happen fully inside PTODSL, or should `ExpandTileOp` do some pre-filtering before calling PTODSL?

6. What metadata is necessary for v1?
   - likely: op, target, dtype, memory space, layout, priority
   - later: fusibility, post-update, cost, shape constraints

7. Should generated MLIR be returned as:
   - text
   - bytecode
   - Python MLIR module serialized to text
   - in-process object if embedded Python is used

---

## 12. Main takeaway

The implementation work should focus on the PTODSL TileLib infrastructure, not rewriting the template bodies into low-level pointer style.

The intended direction is:

```text
old tilelang-dsl templates
  -> PTODSL-native template files
  -> same/similar function bodies
  -> metadata-rich decorator
  -> registry + constraint matching + version selection
  -> render structured MLIR during PTOAS run
  -> return MLIR to ExpandTileOp
  -> PTOAS inline/fold/canonicalize
```

The MVP should prove this using two registered `pto.tadd` templates with duplicate bodies but different metadata, so the selection/metadata/rendering mechanism can be tested before implementing real alternative versions.
