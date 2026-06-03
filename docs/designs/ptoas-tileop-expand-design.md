# Tile Lib Vector Library Design

## Chapter 1. Background and Problem

### 1.1 Current Compilation Stack and Compile-Time Problem

The current PTOAS flow can express tile-level vector operations directly in PTO IR, but library-like TileOp implementations are still expensive to maintain when each operation is hand-expanded in C++ lowering code. Every new operation tends to require changes across parsing, verification, expansion, test cases, and examples.

The compile-time issue is also practical: if each operation is lowered through a large amount of generated IR or through repeated bespoke expansion logic, template reuse becomes hard and compile latency increases. The design goal is to keep the high-level TileOp surface compact while moving reusable operation bodies into a Python-authored Tile Lib.

### 1.2 Challenges for Vector Library Implementation in PTOAS

The main challenges are:

- Tile operations need access to tile metadata such as shape, valid shape, dtype, and memory layout.
- Some values are compile-time constants and can control Python-level staging; other values are runtime SSA values and must remain in generated IR.
- Templates must be specialized by static information to avoid recompiling the same implementation repeatedly.
- The expansion must preserve PTO/VPTO semantics, including `alloc_tile`, `partition_view`, `tload`, tile computation, and `tstore`.
- The result should remain compatible with later inline and intrinsic-folding passes.

## Chapter 2. Approach: Develop Tile Lib in Python

### 2.1 Overall Idea

Tile Lib templates are authored in a Python TileLang DSL. PTOAS keeps the user-facing TileOp in the input program, then an Expand TileOp pass selects and instantiates the corresponding Python template. The instantiated template emits PTO/VPTO IR, which is then inlined and folded into the surrounding program.

At a high level:

```text
PTO TileOp
  -> Expand TileOp
  -> materialized TileLang template function
  -> Inline
  -> Fold TileBuf Intrinsics
  -> regular PTO/VPTO IR
```

### 2.2 TADD Template Example

A `pto.tadd` template should read two tiles, operate only over the valid region, and write the result tile:

```python
@pto.vkernel(target="a5", op="pto.tadd")
def template_tadd(lhs: pto.Tile, rhs: pto.Tile, dst: pto.Tile):
    with pto.vecscope():
        mask = pto.valid_mask(dst)
        a = pto.vlds(lhs, mask=mask)
        b = pto.vlds(rhs, mask=mask)
        c = pto.vadd(a, b, mask=mask)
        pto.vsts(c, dst, mask=mask)
```

This example is illustrative. The actual template should follow the concrete DSL surface implemented in the repository.

### 2.3 Value Model and Staging Semantics

The DSL must separate compile-time static values from runtime dynamic SSA values.

#### Compile-Time Static

Compile-time static values are known while the Python template runs. They can be used for Python control flow, specialization keys, and template selection. Examples include:

- tile rank
- static shape and valid shape
- element dtype
- target architecture
- operation attributes passed as static parameters

#### Runtime Dynamic

Runtime dynamic values are MLIR SSA values. They must not control Python-level branching unless they are staged into IR control flow. Examples include:

- runtime offsets
- runtime loop induction variables
- runtime pointer values
- values loaded from memory

#### Formal Constraints

- Python `if` / `for` may branch only on compile-time static values.
- Runtime dynamic values must be represented through generated IR operations.
- Template specialization must include every static value that can affect emitted IR.
- Runtime values must remain operands in the emitted IR instead of being folded into Python constants.

#### Effect on Control Flow

If a branch condition depends on static shape, the Python template can expand only the selected branch. If it depends on an SSA value, the template must emit an IR-level branch.

```python
# Static shape: Python can expand directly.
if tile.shape[0] <= 16:
    emit_small_tile_path()
else:
    emit_large_tile_path()
```

### 2.4 TileLang DSL Syntax Reference

#### 2.4.1 Basic Scalar Types

The DSL should expose scalar type names that map directly to PTO types:

| DSL Type | Meaning |
|---|---|
| `pto.f16` | 16-bit float |
| `pto.bf16` | bfloat16 |
| `pto.f32` | 32-bit float |
| `pto.i8` / `pto.u8` | 8-bit integer |
| `pto.i16` / `pto.u16` | 16-bit integer |
| `pto.i32` / `pto.u32` | 32-bit integer |

#### 2.4.2 Vector and Mask Types

Vector values and masks are runtime values. They are created by vector load, compute, comparison, and mask-construction APIs. Mask values should carry enough shape or lane information to emit correct predication.

#### 2.4.3 Tile Data Types

`pto.Tile` represents a tile buffer with dtype, shape, valid shape, and memory-space metadata. It should provide accessors for:

- `shape`
- `valid_shape`
- `element_type`
- address space
- staged pointer or tile-buffer handle

#### 2.4.4 Vector Operation Interfaces

The DSL should provide operation wrappers for common vector operations such as:

```python
pto.vlds(tile, mask=None)
pto.vsts(value, tile, mask=None)
pto.vadd(lhs, rhs, mask=None)
pto.vsub(lhs, rhs, mask=None)
pto.vmul(lhs, rhs, mask=None)
pto.vmax(lhs, rhs, mask=None)
pto.vmin(lhs, rhs, mask=None)
```

Each wrapper should emit the corresponding PTO/VPTO operation, preserving operand types and attributes.

#### 2.4.5 Control Flow

Static control flow is evaluated by Python. Dynamic control flow must emit MLIR control-flow operations. Template authors should avoid mixing these two concepts.

#### 2.4.6 Multi-Operator Templates (template slots)

Template slots allow one template body to support multiple related ops:

```python
@pto.vkernel(
    target="a5",
    ops=["pto.tadd", "pto.tsub"],
    templates={"compute": {"pto.tadd": "vadd", "pto.tsub": "vsub"}},
)
def template_binary(lhs: pto.Tile, rhs: pto.Tile, dst: pto.Tile):
    op = pto.tpl("compute")
    ...
```

The selected operation becomes part of the specialization key.

## Chapter 3. PTOAS Compiler: TileOp Expand

### 3.1 Compilation Flow

The compiler flow is:

```text
input .pto
  -> parse and verify TileOp
  -> Expand TileOp
  -> import or materialize Python template
  -> specialize by static operands and attrs
  -> emit template MLIR
  -> inline template function
  -> fold tile_buf / tensor_view intrinsics
  -> continue normal PTOAS pipeline
```

### 3.2 Expand TileOp Pass Workflow

The pass identifies TileOps that have registered templates, builds a specialization key, looks up or instantiates the template, replaces the TileOp with a call to the instantiated template, and records the generated function in the module.

#### 3.2.1 Specialization Key and Cache

The specialization key should include every static property that affects emitted IR:

- operation name or selected template slot
- target architecture
- source and destination dtypes
- shape and valid shape
- static op attributes such as rounding mode
- layout or address-space information when relevant

The cache maps this key to an instantiated template function so identical cases reuse the same materialized IR.

#### 3.2.2 Template Instantiation Process

Instantiation should:

1. Load the Python template module.
2. Bind template arguments from the TileOp operands and attributes.
3. Run the template under staging rules.
4. Collect emitted MLIR/PTO IR.
5. Insert the materialized function into the module.
6. Replace the original TileOp with a call.

### 3.3 IR Structure of an Instantiated Template Function

An instantiated function should have a stable symbol name derived from the specialization key. Its arguments should correspond to runtime operands, while static data should be encoded in function body IR or attributes.

```mlir
func.func private @tilelib_tadd_f32_16x64(%lhs: !pto.tile, %rhs: !pto.tile, %dst: !pto.tile) {
  // generated PTO/VPTO body
  return
}
```

### 3.4 Input/Output Examples for the Three Passes

#### 3.4.1 Input (TileOp)

```mlir
pto.tadd %lhs, %rhs, %dst : !pto.tile, !pto.tile, !pto.tile
```

#### 3.4.2 After Expand TileOp

```mlir
func.call @tilelib_tadd_f32_16x64(%lhs, %rhs, %dst)
  : (!pto.tile, !pto.tile, !pto.tile) -> ()
```

#### 3.4.3 After Inline

The call is replaced by the generated template body.

#### 3.4.4 After Fold TileBuf Intrinsics

##### tile_buf Folding

Temporary tile-buffer helper intrinsics are folded into concrete PTO operations or removed when they are staging-only artifacts.

##### tensor_view Folding

Tensor-view helper intrinsics are folded into the address, shape, and partition information required by the final IR.

##### General Rules

- Remove staging-only helpers.
- Preserve runtime SSA values.
- Do not fold dynamic values into static constants.
- Keep verifier-visible types and attributes consistent.

### 3.5 Template Directory and Deployment

Templates should live in a predictable TileOps directory, for example:

```text
PTOAS/lib/TileOps/
  tadd_template.py
  tcvt_template.py
  ...
```

The compiler should locate templates through a configured search path and fail with an actionable diagnostic when a template is missing.

### 3.6 Adding a Template for a New Operator

To add a new operator template:

1. Define or update the TileOp in PTO IR.
2. Add verifier coverage for its operands and attributes.
3. Add a TileLang template under `lib/TileOps/`.
4. Register the template with the template loader.
5. Add lit tests for expansion and folding.
6. Add ST coverage when numeric behavior matters.
7. Update user-facing documentation and examples.

## Chapter 4. Prerequisite Work

### 4.1 Python DSL Extensions

Required DSL work includes Tile metadata accessors, vector op wrappers, template slots, staged values, static/dynamic value checks, and diagnostics that point to the template source location.

### 4.2 PTOAS Compiler: Expand TileOp Pass

The pass needs template lookup, specialization-key construction, cache management, template materialization, call replacement, and deterministic symbol naming.

### 4.3 PTOAS Compiler: Fold TileBuf Intrinsics Pass

The folding pass should eliminate staging helper operations after inline, fold tile-buffer and tensor-view metadata access, and reject cases where runtime values are incorrectly used as static values.

### 4.4 Tests and Documentation

Testing should cover parser/verifier behavior, template expansion, cache reuse, inline/folding, generated VPTO IR, and end-to-end ST correctness.

#### 4.4.1 ST Accuracy Validation

ST validation checks that TileLib templates produce numerically correct results on simulator or NPU after the full PTOAS compile path.

##### Complete Execution Flow Overview

```text
.pto testcase
  -> ptoas --pto-backend=vpto --enable-tile-op-expand --enable-insert-sync
  -> fat object
  -> host runner build
  -> gen_data.py
  -> run binary
  -> compare.py
```

##### Files Required for a New Testcase: Seven Files Plus One Registration Change

For a new testcase such as `tsub`, add:

| File | Purpose |
|---|---|
| `testcase/tsub/CMakeLists.txt` | Register the testcase build |
| `testcase/tsub/cases.py` | Single source of truth for case definitions |
| `testcase/tsub/tsub.pto` | PTO kernels for each case |
| `testcase/tsub/launch.cpp` | Kernel declarations and launch wrappers |
| `testcase/tsub/main.cpp` | Host driver and case table |
| `testcase/tsub/gen_data.py` | Input and golden generation |
| `testcase/tsub/compare.py` | Output comparison |
| `testcase/CMakeLists.txt` | Add the testcase to the global list |

##### Cross-File Consistency Constraints

The following must stay synchronized:

- case names in `cases.py`, `.pto`, `launch.cpp`, `main.cpp`, `gen_data.py`, and `compare.py`
- kernel function names and wrapper names
- dtype, shape, valid shape, and output shape
- host argument order and `.pto` function argument order
- comparison threshold and golden-generation semantics

##### Run Commands

```bash
# Run all tsub cases on the simulator.
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tsub

# Run all tsub cases on NPU.
python3 test/tilelang_st/script/run_st.py -r npu -v a5 -t tsub

# Run a single case.
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tsub -c f32_16x64

# Reuse an existing build and skip rebuild; only regenerate data, run, and compare.
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tsub -c f32_16x64 -w
```

##### Recommended Development and Validation Rhythm

1. Start with one small representative case.
2. Run that case on simulator.
3. Inspect generated IR and output/golden data.
4. Add more shapes and dtypes.
5. Run the full testcase.
6. Run on NPU when simulator results are stable.

##### Debugging Suggestions

- If `ptoas` fails, inspect the `.pto` file, verifier diagnostics, and template instantiation.
- If linking fails, check fatobj generation and kernel symbol names.
- If comparison fails, inspect `golden.bin`, `output.bin`, host argument order, and valid-shape slicing.
- If single-case and full-case behavior differ, check case directory isolation and host resource cleanup.

##### Adding a Case Under an Existing Testcase

For an existing testcase, adding a new case usually requires updating:

- `cases.py`
- the `.pto` file
- `launch.cpp`
- `main.cpp`

`gen_data.py` and `compare.py` should read from `cases.py` whenever possible, so they usually do not need case-specific edits.
