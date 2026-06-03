# TileLang ST Accuracy Validation Framework

## 1. Document Goal

This document describes how to use the current `test/tilelang_st` framework from the perspective of a TileLang library developer.

The goal of this framework is not simple IR regression. Instead, it answers two development-oriented questions:

1. After a newly written TileLang template-library implementation is expanded to PTO / VPTO / LLVM IR, is the final numeric result correct when run on the simulator or NPU?
2. If I need to add an ST case for a new op, what is the minimum set of files required, and which stages does the run flow go through?

The current framework already provides these capabilities:

- Drives `ptoas` directly from `.pto`, without manually writing `kernel.cpp` or intermediate `.ll`
- Supports multiple cases under one testcase
- Supports both `sim` and `npu` run modes
- Supports single-case filtering
- Supports testcases where the logical `src` and `dst` shapes differ, such as reductions like `trowsum`
- Isolates input, golden, and output files under `build/testcase/<testcase>/`, avoiding overwrites between different testcases

## 2. Framework Positioning

TileLang ST follows the directory organization style of `pto-isa` ST, but the compilation flow is different.

| Dimension | pto-isa ST | TileLang ST |
|---|---|---|
| kernel source | handwritten `kernel.cpp` | handwritten `.pto`, with `ptoas` expanding TileLang DSL templates |
| compile entry | `bisheng -xcce kernel.cpp` | `ptoas .pto -> fatobj` |
| device object integration into host | compiler directly generates fatobj in one step | `ptoas` directly generates a host-linkable fatobj |
| accuracy comparison | GTest / C++ comparison logic | `compare.py` + `numpy.allclose` |
| multi-case organization | multiple GTest cases | multiple kernel functions under one testcase plus a host case table |

In other words, TileLang ST is better suited for validating "end-to-end runtime correctness after library-template expansion" than for validating one standalone CCE `kernel.cpp`.

## 3. Current Execution Flow

The unified entry is:

```bash
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tadd
```

Cube kernels can also use the same entry directly, for example:

```bash
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tmatmul
```

The full flow is:

```text
run_st.py
  ├─ set_env_variables()
  │   └─ configure simulator / NPU runtime environment
  ├─ build_project()
  │   ├─ cmake -DRUN_MODE=... -DSOC_VERSION=... -DTEST_CASE=... -DPTOAS_BIN=...
  │   ├─ ptoas: <op>.pto -> <op>_kernel.o
  │   │    flags:
  │   │      --pto-arch=a5
  │   │      --pto-backend=vpto
  │   │      --enable-insert-sync
  │   │      --enable-tile-op-expand
  │   ├─ bisheng -xcce: launch.cpp + <op>_kernel.o -> lib<op>_kernel.so
  │   └─ bisheng -xc++: main.cpp -> <op>
  ├─ run_gen_data()
  │   └─ generate input/golden for each case under build/testcase/<testcase>/
  ├─ run_binary()
  │   └─ execute ../../bin/<testcase> [case] under build/testcase/<testcase>/
  └─ run_compare()
      └─ compare golden/output case by case under build/testcase/<testcase>/
```

### 3.1 Fatobj Direct Linking

TileLang ST no longer goes through the intermediate `kernel.ll -> device.o -> repack` path.

`ptoas` directly outputs a host-linkable fatobj object. `launch.cpp` only provides host-side kernel declarations and wrappers, and then `bisheng -xcce` links `launch.cpp` and the fatobj directly into `lib<op>_kernel.so`.

If fatobj output is not generated successfully, subsequent host linking naturally cannot succeed. During debugging, first check whether the `ptoas` output is complete.

### 3.2 Case Execution and Comparison Order

By default:

1. `gen_data.py` first generates input and golden files for all cases under the testcase.
2. `./bin/<testcase>` runs all cases in sequence.
3. `compare.py` then compares each case's `golden.bin` and `output.bin` in sequence.

If `-c <case_name>` is used, both running and comparison target only that case.

## 4. Directory Structure and Responsibilities

The current directory structure is:

```text
test/tilelang_st/
    ├── script/
│   ├── run_st.py
│   ├── run_all_st.py
│   └── run_ci.sh
└── npu/
    └── a5/
        └── src/st/
            ├── CMakeLists.txt
            └── testcase/
                ├── CMakeLists.txt
                ├── run_ptoas_to_file.cmake
                ├── st_common.py
                └── tadd/
                    ├── CMakeLists.txt
                    ├── cases.py
                    ├── tadd.pto
                    ├── launch.cpp
                    ├── main.cpp
                    ├── gen_data.py
                    └── compare.py
```

File responsibilities:

| File | Responsibility |
|---|---|
| `script/run_st.py` | Unified entry responsible for compiling, generating data, executing the binary, and comparing results |
| `script/run_all_st.py` | Entry for running all testcases |
| `script/run_ci.sh` | CI entry wrapper |
| `src/st/CMakeLists.txt` | Top-level CMake file that sets compiler, environment, and dependencies |
| `testcase/CMakeLists.txt` | Defines the `pto_tilelang_vec_st()` macro and registers all testcases |
| `testcase/run_ptoas_to_file.cmake` | Wraps the `ptoas` invocation and compiles `.pto` into fatobj |
| `testcase/st_common.py` | Python common module shared by all testcases: case validation, data-generation helpers, `result_cmp`, and terminal coloring |
| `testcase/<op>/cases.py` | **Single source of truth for case definitions**. Both `gen_data.py` and `compare.py` import from it. The default fields are `shape`/`valid_shape`; ops with different output shapes, such as `trowsum`, additionally add `dst_shape`/`dst_valid_shape` |
| `testcase/<op>/<op>.pto` | Kernel description for the testcase; usually one file contains functions for multiple cases |
| `testcase/<op>/launch.cpp` | Kernel declarations and launch wrappers |
| `testcase/<op>/main.cpp` | Host driver responsible for memory allocation, kernel launch, and output writeback. The `ACL_CHECK` macro is provided by the common header `test_common.h` |
| `testcase/<op>/gen_data.py` | Generates input and golden files, reading the case list from `cases.py` |
| `testcase/<op>/compare.py` | Per-testcase comparison script that decides which bin files to read, what shape to reshape to, which valid region to slice, and then calls the common `result_cmp()` |

## 5. Daily Usage

### 5.0 Prerequisites

Before running TileLang ST, confirm the following:

- The repository's `ptoas` has already been built; the default path is `build/tools/ptoas/ptoas`.
- `ASCEND_HOME_PATH` is set correctly.
- If you need to manually run `ptoas`, `bisheng`, or lit, prefer running:

```bash
source scripts/ptoas_env.sh
```

`run_st.py` supplements simulator / NPU environment variables at runtime, but it does not build `ptoas` for you.

### 5.1 Run an Existing Testcase

```bash
# Run all tadd cases on the simulator
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tadd

# Run all tadd cases on NPU
python3 test/tilelang_st/script/run_st.py -r npu -v a5 -t tadd

# Run only one case
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tadd -c f32_16x64

# Reuse the existing build directory without rebuilding
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tadd -w
```

### 5.2 Common Parameters

| Parameter | Meaning |
|---|---|
| `-r, --run-mode` | Run mode, `sim` or `npu` |
| `-v, --soc-version` | SoC version; currently only `a5` is supported |
| `-t, --testcase` | Testcase name, corresponding to `testcase/<name>/` |
| `-c, --case` | Run only one case |
| `-p, --ptoas-bin` | Specify the `ptoas` path |
| `-w, --without-build` | Skip build and directly reuse the existing `build/` |

### 5.3 Where Artifacts Are Located

Runtime data for a testcase is no longer written to the `build/` root. It is written to:

```text
test/tilelang_st/npu/a5/src/st/build/testcase/<testcase>/
```

Using `tadd` as an example:

```text
build/testcase/tadd/
├── gen_data.py
├── compare.py
├── f32_16x64/
│   ├── input1.bin
│   ├── input2.bin
│   ├── golden.bin
│   └── output.bin
└── f32_32x32/
    ├── input1.bin
    ├── input2.bin
    ├── golden.bin
    └── output.bin
```

This layout has these benefits:

- Different testcases will not overwrite each other because of identical case names.
- Developers can directly enter `build/testcase/<testcase>/` to inspect input, output, and golden files.
- When using `-w`, stale data from an old testcase is less likely to be mistaken for the current result.

### 5.4 Comparison Output

`compare.py` gives clear pass/fail prompts:

- pass: bold green
- fail: bold red

The comparison logic currently uses `numpy.allclose`. Recommended thresholds:

| dtype | Recommended eps |
|---|---|
| `float32` | `1e-6` |
| `float16` | `1e-3` |
| `bfloat16` | `1e-2` |
| `int8/int16/int32` | `0` |

## 6. Adding a New Op Testcase as a Library Developer

This section answers: "I developed a new TileLang library implementation; how do I validate it with the ST framework?"

Using a new `pto.tsub` as an example, the minimum required files are:

| File | Add/Modify | Description |
|---|---|---|
| `testcase/tsub/CMakeLists.txt` | add | Usually only one line: `pto_tilelang_vec_st(tsub)` |
| `testcase/tsub/cases.py` | add | **Single source of truth for case definitions**: each case must specify `name`/`dtype`/`shape`/`valid_shape`/`eps`; if the output shape differs, also add `dst_shape`/`dst_valid_shape` |
| `testcase/tsub/tsub.pto` | add | Defines one or more kernel functions for cases |
| `testcase/tsub/launch.cpp` | add | Declares each kernel function entry and provides a launch wrapper |
| `testcase/tsub/main.cpp` | add | Host driver responsible for the case table, memory copies, launch, and writing output to disk |
| `testcase/tsub/gen_data.py` | add | Generates input and golden for each case, importing `CASES` from `cases.py` |
| `testcase/tsub/compare.py` | add | The testcase decides which output data to compare, then calls the common `result_cmp()` |
| `testcase/CMakeLists.txt` | modify | Add `tsub` to `ALL_TESTCASES` |

Usually, there is no need to modify:

- `script/run_st.py`
- `src/st/CMakeLists.txt`
- `testcase/st_common.py`
- `testcase/run_ptoas_to_file.cmake`
- old `.ll` / `device.o` / `repack` artifacts under the `testcase` directory

unless you are changing the framework itself rather than adding a testcase.

## 7. Files to Change, Using `pto.tadd` as an Example

The current repository already has `tadd` as a complete sample. Use it as the template.

### 7.1 `testcase/tadd/CMakeLists.txt`

This file is usually the simplest:

```cmake
pto_tilelang_vec_st(tadd)
```

It means the common macro owns the full pipeline `tadd.pto -> tadd_kernel.o -> libtadd_kernel.so -> tadd`.

### 7.2 `testcase/tadd/tadd.pto`

This is the core file. Write the kernel forms to validate here.

The current `tadd.pto` has these characteristics:

- One file contains multiple cases.
- Each case corresponds to a `func.func @TADD_<dtype>_<rows>x<cols>(...)`.
- The function body explicitly writes `make_tensor_view`, `partition_view`, `alloc_tile`, `tload`, `pto.tadd`, and `tstore`.

If you are developing the `pto.tadd` library implementation, the most important first step is designing the cases you want to cover. For example:

- `f32` / `f16` / `bf16`
- Different tile shapes
- Boundary cases where valid rows/columns are not a full tile

The recommended function naming convention is:

```text
TADD_<dtype>_<rows>x<cols>
```

For example:

```text
TADD_f32_16x64
TADD_f32_32x32
```

### 7.3 `testcase/tadd/launch.cpp`

This file has only two responsibilities:

1. Declare kernel entries.
2. Provide `Launch*` wrappers for the host driver.

The currently recommended form is the same as `tadd`:

```cpp
#include <stdint.h>

#ifndef AICORE
#define AICORE [aicore]
#endif

extern "C" __global__ AICORE void TADD_f32_16x64(__gm__ float *a, __gm__ float *b, __gm__ float *c);

void LaunchTADD_f32_16x64(float *a, float *b, float *c, void *stream) {
    TADD_f32_16x64<<<1, nullptr, stream>>>((__gm__ float *)a, (__gm__ float *)b, (__gm__ float *)c);
}
```

Notes:

- `launch.cpp` does not need to include PTO headers.
- `AICORE` is defined locally as `[aicore]`.
- The kernel declaration here must match the `pto.kernel` function signature in `tadd.pto`, so `bisheng -xcce` can directly link the fatobj.
- The kernel parameter order must stay consistent with the function signature in `.pto`.

### 7.4 `testcase/tadd/main.cpp`

This file is responsible for host-side scheduling.

The main tasks are:

1. Declare all `LaunchTADD_*` wrappers.
2. List each case in `kCases[]` with its name, launch function, input/output shape, valid shape, and element size.
3. In `RunCase()`:
   - Read inputs from `./<case>/input*.bin`.
   - Copy inputs to device with `aclrtMemcpy`.
   - Call `tc.launch(...)`.
   - Run `aclrtSynchronizeStream`.
   - Copy output back to host.
   - Write `./<case>/output.bin`.

The current `tadd/main.cpp` case table is:

```cpp
struct TestCase {
    const char *name;
    LaunchFn    launch;
    size_t      rows;       // allocated tile rows
    size_t      cols;       // allocated tile cols
    size_t      validRows;  // effective computation rows  (<= rows)
    size_t      validCols;  // effective computation cols  (<= cols)
    size_t      elemSize;
};

static const TestCase kCases[] = {
    {"f32_16x64", LaunchTADD_f32_16x64, 16, 64, 16, 64, sizeof(float)},
    {"f32_32x32", LaunchTADD_f32_32x32, 32, 32, 32, 32, sizeof(float)},
};
```

Note: the `ACL_CHECK` macro has moved to the common header `test_common.h` and should be included after `acl/acl.h`; it does not need to be redefined in each testcase's `main.cpp`.

When adding a case, update this table at the same time.

- For same-shape ops such as `tadd`, fields must remain consistent with `shape` / `valid_shape` in `cases.py`.
- For ops such as `trowsum` where the output shape differs, the host side needs to compute input size and output size separately.

### 7.5 `testcase/tadd/cases.py`

This is the **single source of truth** for case definitions. Both `gen_data.py` and `compare.py` import `CASES` from it.

Each case must include these fields:

```python
"name"
"dtype"
"shape"
"valid_shape"
"eps"
```

```python
CASES = [
    {
        "name": "f32_16x64",          # case identifier; matches the runtime subdirectory and the name in main.cpp kCases[]
        "dtype": np.float32,           # numpy dtype
        "shape": (16, 64),             # allocated tile dimensions (rows, cols)
        "valid_shape": (16, 64),       # valid computation region (valid_rows, valid_cols)
        "eps": 1e-6,                   # numpy.allclose tolerance
    },
]
```

`valid_shape` is required. It must be written explicitly even when the valid shape is equal to the tile shape.

If the output shape differs, the following two fields can be added:

```python
CASES = [
    {
        "name": "f32_16x64",
        "dtype": np.float32,
        "shape": (16, 64),             # input tensor shape
        "valid_shape": (16, 64),       # input valid region
        "dst_shape": (16, 1),          # output tensor shape, visible on GM
        "dst_valid_shape": (16, 1),    # output valid region
        "eps": 1e-5,
    },
]
```

This is also the recommended form for `trowsum`. Note that `dst_shape` describes the actual result shape after writeback to GM, not the physical expanded shape of an on-chip tile.

### 7.6 `testcase/tadd/gen_data.py`

This file generates input and golden files for each case. It imports `CASES` from `cases.py`
and helper functions (`setup_case_rng`, `save_case_data`) from `st_common.py`.

Using `pto.tadd` as an example, the core logic for each case is:

```python
golden = np.zeros(shape, dtype=dtype)
vr, vc = case["valid_shape"]
golden[:vr, :vc] = (input1[:vr, :vc] + input2[:vr, :vc]).astype(dtype, copy=False)
```

The golden result is computed only inside the `valid_shape` region; values outside the region remain zero.

For ops such as `trowsum` where the output shape differs, `gen_data.py` should generate `golden` according to `dst_shape` and perform the reduction according to `valid_shape`. For example:

```python
shape = case["shape"]
valid_shape = case["valid_shape"]
dst_shape = case["dst_shape"]
dst_valid_shape = case["dst_valid_shape"]
input1 = np.random.randint(1, 10, size=shape).astype(dtype)
golden = np.zeros(dst_shape, dtype=dtype)
golden[:dst_valid_shape[0], 0] = np.sum(
    input1[:valid_shape[0], :valid_shape[1]], axis=1
).astype(dtype, copy=False)[:dst_valid_shape[0]]
```

The comparison stage also reads and reshapes `golden.bin` and `output.bin` according to `dst_shape` / `dst_valid_shape`.

Each case uses an independent random seed. `setup_case_rng` is based on `hash(case["name"])`, so adding or reordering cases does not affect test data for existing cases.

### 7.7 `testcase/<op>/compare.py`

The comparison script is no longer placed in a common directory; each testcase maintains its own copy.

The purpose is straightforward:

- The common layer only provides an interface such as `result_cmp(golden, output, eps)` to compare already-prepared data.
- The testcase itself decides which bin files to read, what shape to reshape to, and which valid region to slice.

Using `tadd` as an example, the core logic in `compare.py` is:

```python
golden = np.fromfile(os.path.join(case_dir, "golden.bin"), dtype=case["dtype"]).reshape(shape)
output = np.fromfile(os.path.join(case_dir, "output.bin"), dtype=case["dtype"]).reshape(shape)
ok = result_cmp(golden[:vr, :vc], output[:vr, :vc], case["eps"])
```

For `trowsum`, it can reshape by `dst_shape` and compare only the valid `rows x 1` region.

This split is closer to the `ResultCmp` idea in `pto-isa`: the common layer is responsible only for "how to compare", not for "which data region should be compared".

## 8. Adding Only One Case Under Existing `tadd`

If the `tadd` testcase already exists and you only want to add a new case, such as `f32_8x128`, you usually only need to update four files:

| File | Required Change |
|---|---|
| `testcase/tadd/cases.py` | Add a new entry to `CASES`, including `name`/`dtype`/`shape`/`valid_shape`/`eps` |
| `testcase/tadd/tadd.pto` | Add a `func.func @TADD_f32_8x128(...)` |
| `testcase/tadd/launch.cpp` | Add the `extern "C"` kernel declaration and `LaunchTADD_f32_8x128` |
| `testcase/tadd/main.cpp` | Add `{"f32_8x128", LaunchTADD_f32_8x128, 8, 128, 8, 128, sizeof(float)}` to `kCases[]` |

No changes are needed in:

- `testcase/tadd/gen_data.py`, which automatically reads from `cases.py`
- `testcase/tadd/compare.py`, which automatically reads from `cases.py`
- `testcase/tadd/CMakeLists.txt`
- `testcase/CMakeLists.txt`
- `run_st.py`

## 9. Cross-File Consistency Constraints

This is the easiest place to make mistakes when adding a testcase.

### 9.1 Naming Consistency

The following names must match exactly:

| Location | Example |
|---|---|
| kernel function name in `.pto` | `@TADD_f32_16x64` |
| kernel declaration in `launch.cpp` | `TADD_f32_16x64` |
| wrapper name in `launch.cpp` / `main.cpp` | `LaunchTADD_f32_16x64` |
| case name in `main.cpp` | `f32_16x64` |
| case name in `gen_data.py` / `compare.py` | `f32_16x64` |
| runtime directory name | `build/testcase/tadd/f32_16x64/` |

### 9.2 Parameter Order Consistency

The kernel parameter order in `.pto`, the declaration order in `launch.cpp`, and the launch-wrapper parameter order in `main.cpp` must be consistent.
If the semantics of `tadd` are `(a, b) -> c`, then the host side and compare logic must also use that order.

### 9.3 Consistency of shape, valid_shape, dst_shape, and dtype

The shape information and `dtype` in `cases.py` are the single source of truth on the Python side; `gen_data.py` and `compare.py` read from it automatically.

- For most ops, `shape`/`valid_shape` are enough.
- For ops such as `trowsum` where the output shape differs, additionally maintain `dst_shape`/`dst_valid_shape`.

However, `main.cpp` `kCases[]` on the C++ side and the tensor/tile shapes in `.pto` still need to be kept manually consistent with `cases.py`.
Otherwise the run may succeed, but the result may still be wrong and debugging will be time-consuming.

## 10. Recommended Development and Validation Rhythm

As a library developer, iterate with this rhythm:

1. Start with one minimal case, such as `f32_16x64`.
2. Run a single case on the simulator:

```bash
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tadd -c f32_16x64
```

3. After changing `.pto` or host code, if you confirm it is only a small change, use:

```bash
python3 test/tilelang_st/script/run_st.py -r sim -v a5 -t tadd -c f32_16x64 -w
```

4. After the single case is stable, add more shape / dtype cases.
5. Then run the full `tadd`.
6. Finally, switch to `-r npu` if needed.

## 11. Debugging Suggestions

### 11.1 Where to Look for Compile Failures

- `ptoas` failure: first check the `.pto` file itself, TileLang template instantiation, and whether `--enable-insert-sync` is missing.
- fatobj generation failure: first check `ptoas` stderr and whether the `.pto` semantics are complete.
- `launch.cpp` / `main.cpp` link failure: first check shared-library and ACL runtime dependencies, and symbol-name consistency.

### 11.2 Where to Look for Runtime Failures

- `main.cpp` reports file-read failure: first confirm that `build/testcase/<testcase>/<case>/input*.bin` exists.
- Kernel runs but compare fails: first inspect the difference between `output.bin` and `golden.bin`, then check `.pto` semantics and host parameter order.
- One case passes when run alone but fails in a full run: first suspect case-directory isolation, host resource release, or shared state across cases.

### 11.3 Typical Debug Files

| File | Purpose |
|---|---|
| `build/testcase/<testcase>/<testcase>_kernel.o` | Inspect the final fatobj generated by `ptoas` |
| `build/testcase/<testcase>/<case>/golden.bin` | Confirm whether the Python-side oracle is correct |
| `build/testcase/<testcase>/<case>/output.bin` | Confirm the actual runtime output |
| `testcase/<op>/main.cpp` | Confirm host-side parameter order, shape, and file paths |
| `testcase/<op>/compare.py` | Confirm whether the comparison threshold is reasonable |

## 12. One-Sentence Summary

For library developers, the TileLang ST framework is a fixed end-to-end validation pipeline:

```text
write .pto -> integrate the testcase six-file set -> run_st.py compiles and runs -> inspect input/golden/output under build/testcase/<op>/ -> decide whether the library implementation is correct
```

If you want to validate `pto.tadd`, the most important thing is keeping these pieces synchronized:

- Case definitions in `cases.py` (name/dtype/shape/valid_shape/eps): the single source of truth on the Python side
- Kernel function names and tile shapes in `tadd.pto`
- Kernel declarations and wrappers in `launch.cpp`
- `kCases[]` in `main.cpp`, where rows/cols/validRows/validCols must match `cases.py`
- Golden-computation logic in `gen_data.py`, which depends on op semantics such as addition/subtraction

The case list and comparison threshold in `compare.py` and `gen_data.py` are both read automatically from `cases.py`; they do not need separate maintenance.

Once these pieces are consistent, the framework can help you run the end-to-end correctness of a TileLang library implementation reliably.
