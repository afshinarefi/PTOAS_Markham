# PTODSL TileLib Migration Effort Inventory

> **Scope:** migrate the implementations that currently exist under `lib/TileOps/` to
> `ptodsl/ptodsl/tilelib/templates/`. This document does not propose new TileOp versions,
> new algorithms, or broader semantics.
>
> **Snapshot:** 2026-06-29. The inventory covers all 100 `lib/TileOps/*_template.py`
> families. A family is placed in the highest-effort group needed to reproduce its
> current TileLang implementation, not an easier subset of that implementation.

## 1. Current Baseline

The following families already have PTODSL TileLib templates:

- `tadd`
- `tsub`
- `tmul`
- `tmax`
- `tmin`
- `tcolmax`
- `tdiv` default precision only

The current `tdiv` port is intentionally partial. Full parity with TileLang includes the
high-precision branch and therefore appears again in Group 4.

The working baseline proves these features:

- rank-2 UB `Tile` operands;
- row-major/none-box layouts;
- `tile[row, col:]` subviews;
- dynamic `valid_shape`;
- nested `range(...)` loops and ordinary loop-carried state;
- `make_mask`, `vlds`, simple vector arithmetic, and `vsts`;
- legal-candidate metadata and compiler-selected rendering.

## 2. Classification Rules

The groups describe the first shared capability that blocks a faithful port.

| Group | Meaning | Expected work |
|---|---|---|
| 1 | Body already fits the current TileLib runtime | Per-template import, decorator, metadata, constraint, and test changes |
| 2 | PTODSL core already implements the required operations | Extend `tilelib/author.py` and public exports, then port templates |
| 3 | A reusable PTODSL or TileLib capability is missing | Implement one shared runtime, metadata, control-flow, or raw-op feature before porting the family |
| 4 | The family crosses a larger architectural or algorithmic boundary | Treat as a separate migration milestone, not routine template conversion |

This is an effort classification, not a statement that every template in one group has identical
complexity. Each port still needs an MLIR comparison against the TileLang result.

## 3. Group 1: Per-Template Changes Only

These bodies use the same Tile-only vector surface that already works. They should not require a
new PTODSL lowering feature.

| Families | Notes |
|---|---|
| `tcolexpand`, `tcolexpandadd`, `tcolexpandmax`, `tcolexpandmin`, `tcolexpandmul`, `tcolexpandsub` | Existing `vlds` plus binary vector operation plus `vsts` structure |
| `tcolmin`, `tcolprod`, `tcolsum` | Same reduction structure already proven by `tcolmax` |

Typical work:

1. Change the import to `ptodsl.tilelib`.
2. Replace `@pto.vkernel` with `@pto.tile_template`.
3. Express current dtype/layout/memory constraints in TileLib metadata.
4. Preserve the current body.
5. Add selection and rendered-MLIR tests.

## 4. Group 2: TileLib Author-Surface Extensions

PTODSL core already has the required raw operations. The main shared work is exposing compatible
wrappers, enums, dtype constructors, and constraint inputs through `tilelib/author.py` and
`tilelib/__init__.py`.

| Families | Main author-surface additions |
|---|---|
| `tabs`, `tneg`, `tnot`, `trelu` | `vabs`, `vneg`, `vnot`, `vrelu` |
| `tand`, `tor`, `txor` | `vand`, `vor`, `vxor` |
| `tcolexpandexpdif` | `vexp`, `vexpdif`, part-mode enum |
| `tpartmax`, `tpartmin` | `vbr`, `mem_bar`, barrier enums |
| `trsqrt` | `vbr`, `vsqrt`, f16/f32 scalar constructors |
| `tsel` | Predicate load/set/interleave/unpack operations and enums |
| `tshl`, `tshr` | `vshl`, `vshr` |
| `trowexpand`, `trowexpandadd`, `trowexpandmax`, `trowexpandmin`, `trowexpandmul`, `trowexpandsub`, `trowexpandexpdif` | `vdup`, existing vector operations, and richer constraint operand views |
| `trowmax`, `trowmin`, `trowsum` | `bytewidth`, `vbr`, `vcmax`/`vcmin`/`vcadd`, `vsel`, and `vcvt` |

This group should be handled in small shared batches. For example, add and test the unary vector
exports once, then port `tabs`, `tneg`, `tnot`, and `trelu`.

The legacy constraints for some row-expansion templates accept Tile-like objects and inspect
`.config`. The current TileLib constraint evaluator exposes flattened `{operand}_config` values.
Either adapt those predicates during the port or add one reusable read-only operand-spec view.
This is constraint plumbing, not a new MLIR lowering feature.

## 5. Group 3: Missing Shared PTODSL Capability

These families remain vector-oriented, but a faithful port needs functionality that is not
currently available in the PTODSL TileLib path.

### 5.1 Mixed Tile and scalar parameters

Current TileLib rendering requires every template parameter to be `Tile`, and the daemon drops
non-tile operand specs. Add scalar specialization, argument typing, binding, dtype matching, and
constraint context before porting:

- `tadds`, `tands`, `tcmps`
- `texpand`, `tfmods`
- `tlrelu`
- `tmaxs`, `tmins`, `tmuls`
- `tors`, `trems`
- `tsels`
- `tshls`, `tshrs`
- `tsubs`, `txors`

### 5.2 Context attributes

`ExpandTileOp` already sends `context_attrs`, but the TileLib body has no `get_op_attr` equivalent
and the registry does not add those attributes to the constraint context.

- `tcmp`
- `tcmps` also needs mixed-scalar support above

The first implementation should provide one specialization context API used by both constraints
and template bodies. Do not add per-op global variables.

### 5.3 Tile configuration and padding metadata

The render-time Tile object currently lacks the TileLang `.config` and `.pad_value` contract, while
`TileSpec.mlir_type()` hardcodes row-major/none-box/Null padding.

- `tfillpad`
- `tfillpad_expand`
- `tfillpad_inplace`
- `tmov`

This requires preserving concrete tile configuration through daemon decoding, specialization, and
the render-time Tile wrapper.

### 5.4 Missing raw operations

These are not solved by an `author.py` re-export because at least one required operation has no
PTODSL wrapper yet:

| Families | Missing examples |
|---|---|
| `tcolargmax`, `tcolargmin` | `vintlv` |
| `trowargmax`, `trowargmin` | `vdintlv` |
| `trowprod` | `vintlv` |
| `tfmod` | `vtrc` |
| `trem` | `vmod`, `vtrc` |
| `tprelu` | `vprelu` |

### 5.5 Small inline helper procedures

- `tpartadd`
- `tpartmul`

TileLang uses `@pto.inline_proc` helpers for these implementations. PTODSL currently rewrites only
the selected entry template. A small reusable helper-tracing mechanism, or a deliberate rewrite to
explicit PTODSL control flow, is needed before calling these near-verbatim ports.

## 6. Group 4: Separate Migration Milestones

These families should not be mixed into routine elementwise migration work.

### 6.1 Cube, DMA, TensorView, and specialized memory spaces

Current TileLib rendering hardcodes `kernel_kind="vector"`, rank-2 UB Tiles, and Tile-only
parameters. These families need cube-kernel metadata, mixed Tile/TensorView/PartitionTensorView
arguments, non-UB memory spaces, specialized layouts, and DMA/cube operation parity.

- `textract`
- `tgemv`, `tgemv_acc`, `tgemv_bias`, `tgemv_mx`
- `tinsert`
- `tload`
- `tmatmul`, `tmatmul_acc`, `tmatmul_bias`, `tmatmul_mx`
- `tmov2bias`, `tmov2left`, `tmov2right`, `tmov2scale`, `tmov2vec`
- `tmov_fp`
- `tstore`

PTODSL core already contains several `mad`, `mte_*`, and pointer operations, but that does not make
these import-only ports. The TileLib function ABI and specialization model must represent their
operands first.

### 6.2 Full high-precision math implementations

These implementations combine context attributes with helper libraries such as `div_hp.py`,
`exp_hp.py`, and `sqrt_hp.py`. Those helpers use `@pto.inline_proc`, compile-time dtype dispatch,
and additional vector operations.

- full `tdiv`
- full `tdivs`
- `tcolexpanddiv`
- `trowexpanddiv`
- `texp`
- `tlog`
- `trecip`
- `tsqrt`

Default-precision subsets may be useful temporary ports, but they do not count as migration of the
current TileLang implementation.

### 6.3 Large conversion, random, and sorting implementations

- `tcvt`
- `trandom`
- `tmrgsort`
- `tsort32`

These are large multi-path implementations with combinations of context attributes, many dtype
variants, inline helpers, complex loop state, predicate transformations, and currently missing
raw operations such as `vci`, `vintlv`, `vbitsort`, `vmrgsort4`, `vaddc`, and `vtrc`.

Port the shared capabilities against smaller Group 3 templates first. Otherwise these files make
it difficult to tell whether a failure comes from the frontend, an operation wrapper, or the
algorithm itself.

## 7. Cross-Cutting Syntax and API Gaps

These are the concrete differences likely to appear while porting the groups above.

### Compile-time control flow

TileLang:

```python
if pto.constexpr(condition):
    ...
```

PTODSL currently recognizes:

```python
if pto.const_expr(condition):
    ...
```

The spelling change is mechanical, but dtype constants and Tile metadata used by the condition must
also be represented consistently.

### Runtime control flow

Supported today:

- nested `for ... in range(...)`;
- simple runtime `if`/`elif`/`else`;
- ordinary loop-carried variables;
- `with pto.vecscope()`.

Current limitations:

- no runtime `while`;
- no `break`, `continue`, or runtime `for ... else`;
- no dynamic Python short-circuit `and`/`or`;
- no dynamic ternary expression;
- induction variables cannot escape a rewritten loop;
- last-iteration-only values may require explicit `pto.for_(...).carry(...)`.

The current TileLang template corpus does not make `while` or `break` a broad blocker, but complex
conversion, random, and sorting templates are more likely to expose carry and expression limits.

### Raw operation coverage

The current TileLang templates call 115 distinct `pto.*` callables:

- 12 are directly exposed by the current TileLib author surface;
- 58 have PTODSL core implementations but are not exposed through TileLib;
- the remainder includes decorators/types plus genuinely missing operations.

Therefore, do not add duplicate lowering code to `author.py`. Re-export or thinly adapt existing
`_ops.py` functions where they already exist, and add new core wrappers only for verified gaps.

## 8. Recommended Order

1. Finish Group 1 and establish one rendered-MLIR parity test per family shape.
2. Expand `author.py` in coherent operation batches and migrate Group 2.
3. Add mixed scalar operands, then migrate the scalar variants in Group 3.
4. Add the specialization-context API and migrate `tcmp` before attempting `tcvt` or
   high-precision math.
5. Preserve Tile configuration/padding and migrate the fill/move families.
6. Add missing vector wrappers using small Group 3 templates as focused tests.
7. Treat cube/DMA, full high-precision math, and conversion/sort/random as separate milestones.

This order grows shared capability only when a current TileLang implementation requires it. It
avoids inventing future versions or generality that no existing template consumes.
