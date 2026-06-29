# PTODSL TileLib Migration Effort Inventory

> **Scope:** migrate the implementations that currently exist under `lib/TileOps/` to
> `ptodsl/ptodsl/tilelib/templates/`. This document does not propose new TileOp versions,
> new algorithms, or broader semantics.
>
> **Snapshot:** 2026-06-29. The inventory covers all 100 `lib/TileOps/*_template.py`
> families. A family is placed in the highest-effort group needed to reproduce its
> current TileLang implementation, not an easier subset of that implementation.

## 1. Current Baseline

Thirty-nine families now have PTODSL TileLib templates for their current TileLang bodies. The
initial baseline and Group 1 families are:

- `tadd`
- `tsub`
- `tmul`
- `tmax`
- `tmin`
- `tcolmax`
- `tcolexpand`
- `tcolexpandadd`
- `tcolexpandmax`
- `tcolexpandmin`
- `tcolexpandmul`
- `tcolexpandsub`
- `tcolmin`
- `tcolprod`
- `tcolsum`

`tdiv` default precision is also available, but that port is intentionally partial. Full parity
with TileLang includes the high-precision branch and is counted in Group 4.

The initial elementwise and Group 1 registrations cover the established `f32` baseline. Group 2
ports preserve their explicit TileLang dtype sets where present and use the A5 verifier-supported
sets for generic templates.

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

### 2.1 Counts

| Classification | Family count | Notes |
|---|---:|---|
| Migrated family bodies | 39 | Groups 1 and 2 are complete; `tdiv` default precision is additional partial coverage |
| Group 1 remaining | 0 | All 9 per-template migrations are implemented |
| Group 2 remaining | 0 | All 24 author-surface migrations are implemented |
| Group 3: missing shared capability | 31 | Reusable PTODSL/TileLib feature required |
| Group 4: separate milestones | 30 | Includes full `tdiv` parity |
| **Total current TileLang families** | **100** | Every `lib/TileOps/*_template.py` family appears once in the full-parity classification |

### 2.2 TileLang is the reference, not a blank page

Most migration work should not be designed from scratch. TileLang already defines:

- the accepted Python authoring API and operation signatures;
- legal dtype, layout, memory-space, mode, and attribute combinations;
- descriptor registration, specialization, constraints, and selection;
- scalar, Tile, TensorView, and PartitionTensorView parameter behavior;
- vector/cube kernel classification;
- semantic validation and the expected MLIR operations;
- the current high-precision, conversion, random, sorting, DMA, and cube algorithms.

The main references are:

| TileLang source | What to reuse as the behavioral contract |
|---|---|
| `tilelang-dsl/python/tilelang_dsl/kernel.py` | `@vkernel`, `@ckernel`, `@inline_proc`, descriptors, specialization, constraints, and candidate selection |
| `tilelang-dsl/python/tilelang_dsl/types.py` | Scalar/dtype vocabulary, pointer and vector types, `TileConfig`, `TileSpecialization`, enums, `constexpr`, and `get_op_attr` surface |
| `tilelang-dsl/python/tilelang_dsl/frontend_ast.py` | Supported source syntax and compile-time-control-flow rules |
| `tilelang-dsl/python/tilelang_dsl/semantic.py` | Parameter binding, context-attribute resolution, operation validation, Tile/view metadata access, and inline-procedure semantics |
| `tilelang-dsl/python/tilelang_dsl/lowering.py` | Expected MLIR operation forms, scalar/view argument types, and vector-versus-cube function attributes |
| `tilelang-dsl/python/tilelang_dsl/support_matrix.py` | Existing TileLang API coverage |
| `lib/TileOps/` and helper files such as `div_hp.py` | The algorithms and current template bodies being migrated |

Use these files to preserve behavior, but do not copy TileLang's complete AST/semantic/lowering
engine into PTODSL. PTODSL already has its own tracing, surface values, control flow, and `_ops.py`
lowering. The migration should port the missing contract or adapter and route emission through the
PTODSL engine.

| Group | What TileLang already does | What PTODSL should add |
|---|---|---|
| 1 | Registers the descriptor, evaluates existing constraints, and lowers an otherwise compatible body | TileLib metadata/decorator entry plus parity tests |
| 2 | Exposes public operation names/enums and validates their signatures before lowering | Thin `author.py` exports/adapters over existing PTODSL `_ops.py`; reuse TileLang signatures as tests |
| 3 | Binds mixed operands, resolves context attributes, exposes Tile configuration, implements inline helpers, and lowers the missing raw operations | Port each missing shared contract into PTODSL once, then reuse it across the affected families |
| 4 | Defines cube/view/DMA ABIs and contains the complete complex algorithms | Add the necessary PTODSL architecture in a focused milestone, then adapt the existing TileLang bodies rather than rewriting the algorithms |

## 3. Group 1: Per-Template Changes Only (9 families, complete)

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

The ports are registered from `templates/a5/__init__.py` and covered by
`ptodsl/tests/test_tilelib_group1.py`. The tests check selection, structured rendered MLIR, each
family's vector operation, and the one-row output constraint for column reductions. The existing
VPTO inputs for all nine families also compile through `--tile-lib-backend=ptodsl`.

Where TileLang supplies dtype signatures or legality predicates in a template decorator, the port
should translate those declarations into TileLib metadata; it should not rediscover the rules from
generated MLIR.

## 4. Group 2: TileLib Author-Surface Extensions (24 families, complete)

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

This group was handled in small shared batches: shared author exports first, followed by related
template families and focused render tests.

For every exported operation, use TileLang's public signature plus its semantic validation as the
compatibility reference. The implementation should normally be a thin call into the already
existing PTODSL `_ops.py` function, not a port of TileLang's lowering machinery.

The legacy constraints for some row-expansion templates accept Tile-like objects and inspect
`.config`. The current TileLib constraint evaluator exposes flattened `{operand}_config` values.
The ports adapt those predicates to the flattened context without adding a second operand view.

The ports are registered from `templates/a5/__init__.py` and covered by
`ptodsl/tests/test_tilelib_group2.py`. The implementation:

- adds thin TileLib author wrappers over existing PTODSL operations and enums;
- adapts TileLang mask `.astype(...)` calls in `tsel` to PTODSL `pbitcast`;
- translates row-expansion layout predicates to the flattened TileLib constraint context;
- fixes PTODSL `vcadd` result inference so `i16` row sums widen to `i32` before conversion back;
- verifies all 24 existing VPTO inputs through `--tile-lib-backend=ptodsl`.

## 5. Group 3: Missing Shared PTODSL Capability (31 families)

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

TileLang's existing path is the model:

- `VKernelDescriptor` records the parameter specifications in `kernel.py`;
- `SemanticKernel` binds scalar parameters in `semantic.py`;
- `lowering.py` renders scalar function arguments and scalar expressions.

PTODSL already has runtime scalar values and arithmetic. The missing piece is carrying scalar
operand specs through the TileLib daemon and `_TemplateTrace`, not inventing scalar semantics.

### 5.2 Context attributes

`ExpandTileOp` already sends `context_attrs`, but the TileLib body has no `get_op_attr` equivalent
and the registry does not add those attributes to the constraint context.

- `tcmp`
- `tcmps` also needs mixed-scalar support above

The first implementation should provide one specialization context API used by both constraints
and template bodies. Do not add per-op global variables.

TileLang stores context attributes on the specialized descriptor/kernel and resolves
`pto.get_op_attr(name, default)` in `SemanticKernel._analyze_get_op_attr`. Port that ownership
model: specialization context enters once and is read during tracing.

### 5.3 Tile configuration and padding metadata

The render-time Tile object currently lacks the TileLang `.config` and `.pad_value` contract, while
`TileSpec.mlir_type()` hardcodes row-major/none-box/Null padding.

- `tfillpad`
- `tfillpad_expand`
- `tfillpad_inplace`
- `tmov`

This requires preserving concrete tile configuration through daemon decoding, specialization, and
the render-time Tile wrapper.

TileLang's `TileConfig`, `TileSpecialization`, and semantic Tile attribute handling define the
required fields and their meaning. PTODSL should map the existing operand-spec JSON into an
equivalent read-only authoring view instead of creating a second configuration vocabulary.

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

For these operations, TileLang's semantic checks and lowering cases provide the accepted operand
types, modes, result types, and emitted PTO op. The PTODSL work is a corresponding `_ops.py`
wrapper plus binding coverage; the operation semantics are already specified.

### 5.5 Small inline helper procedures

- `tpartadd`
- `tpartmul`

TileLang uses `@pto.inline_proc` helpers for these implementations. PTODSL currently rewrites only
the selected entry template. A small reusable helper-tracing mechanism, or a deliberate rewrite to
explicit PTODSL control flow, is needed before calling these near-verbatim ports.

`kernel.py:inline_proc` and TileLang's semantic handling show how helper parameters, return values,
and nested control flow behave. A PTODSL implementation can be smaller because PTODSL executes
Python helpers while tracing, but each helper that contains runtime control flow must pass through
the same AST rewrite as the entry template.

## 6. Group 4: Separate Migration Milestones (30 families)

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

TileLang already provides the blueprint:

- `@ckernel` marks the cube kernel family in `kernel.py`;
- `lowering.py` emits `pto.kernel_kind<cube>`;
- `semantic.py` models TensorView/PartitionTensorView shape, stride, memory-space, and pointer
  behavior;
- the existing templates state the required layout and DMA/cube operation sequence.

The PTODSL milestone is therefore ABI/specialization integration and operation parity, not a new
matmul or DMA design.

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

The algorithms already exist in `div_hp.py`, `exp_hp.py`, `sqrt_hp.py`, `math.py`, and the
templates themselves. TileLang's `@inline_proc`, `constexpr`, context-attribute, and raw-op support
show what those algorithms require. Port the support they consume; do not rederive the numerical
algorithms.

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

Again, the current TileLang files are the executable specification. They identify every dtype
path, predicate transform, loop structure, mode, and helper call. The work is to make those paths
expressible through PTODSL and compare the rendered MLIR, not to design replacement algorithms.

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
