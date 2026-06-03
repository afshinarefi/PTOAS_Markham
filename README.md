# ptoas (PTO Assembler & Optimizer)

## 1. Introduction

**ptoas** (`ptoas`) is a specialized compiler toolchain built on **LLVM/MLIR (llvmorg-19.1.7)** *(commit cd708029e0b2869e80abe31ddb175f7c35361f90)* for **PTO Bytecode** (Programming Tiling Operator Bytecode).

As the bridge between upper-level AI frameworks and NPU/GPGPU/CPU hardware backends, `ptoas` is built as an **out-of-tree** project and provides complete C++ and Python interfaces. Its main responsibilities are:

1. **IR parsing and verification**: parses `.pto` input files and verifies the semantic correctness of PTO Dialect operations.
2. **Compiler optimizations (passes)**: runs Da Vinci architecture-specific optimization passes, such as operator fusion and automatic synchronization insertion.
3. **Code generation (lowering)**: lowers PTO IR to the `EmitC` / `Linalg` dialects and eventually emits code that can call the `pto-isa` C++ library.
4. **Python bindings**: provides seamlessly integrated Python modules. By integrating with MLIR Core bindings, frameworks such as **PyPTO**, **TileLang**, and **CuTile** can build, manipulate, and compile PTO Bytecode directly from Python.

---

## 2. Directory Structure

```text
PTOAS/
├── include/
│   └── PTO/               # PTO Dialect headers and TableGen definitions (.td)
├── lib/
│   ├── PTO/               # Dialect core implementation (IR) and pass logic (Transforms)
│   ├── CAPI/              # C language API exposure
│   └── Bindings/Python/   # Python binding C++ implementation (pybind11)
├── python/                # Python module build scripts and helper code
├── test/
│   └── samples/           # Test cases
├── tools/
│   ├── ptoas/             # ptoas command-line tool entry point (output: ptoas)
│   └── ptobc/             # ptobc command-line tool entry point (output: ptobc)
└── CMakeLists.txt         # Top-level build configuration

```

---

## 3. Build Instructions

**Important**: this project strictly depends on **LLVM llvmorg-19.1.7**.


### 3.0 Configuration

To simplify the build flow, **first adjust and run the following commands for your local environment**. Later steps refer to these variables directly.

```bash
# ================= Configuration area (edit this section) =================
# Set your workspace root. Creating a dedicated directory for LLVM and PTOAS is recommended.
export WORKSPACE_DIR=$HOME/llvm-workspace

# LLVM source and build paths
export LLVM_SOURCE_DIR=$WORKSPACE_DIR/llvm-project
export LLVM_BUILD_DIR=$LLVM_SOURCE_DIR/build-shared

# PTOAS source and install paths
export PTO_SOURCE_DIR=$WORKSPACE_DIR/PTOAS
export PTO_INSTALL_DIR=$PTO_SOURCE_DIR/install
# =======================================================

# Create the workspace directory
mkdir -p $WORKSPACE_DIR

```

### 3.1 Prerequisites

* **OS**: Linux (Ubuntu 20.04+ recommended)
* **Compiler**: GCC >= 9 or Clang (with C++17 support)
* **Build System**: CMake >= 3.20, Ninja
* **Python**: 3.8+
* **Python Packages**: `pybind11`, `numpy`
```bash
python3 -m pip install pybind11==2.12.0 numpy

```

> Note: the current LLVM/MLIR Python bindings are not compatible with `pybind11` 3.x.
> If LLVM compilation reports errors such as `def_property family does not currently support keep_alive`,
> run the downgrade command above first.



### 3.2 Step 1: Build LLVM/MLIR (Dependency)

Download the LLVM source, check out the `llvmorg-19.1.7` tag, and build it in **shared library** mode so the Python bindings link correctly.

```bash
# 1. Download LLVM source
cd $WORKSPACE_DIR
git clone https://github.com/llvm/llvm-project.git
cd $LLVM_SOURCE_DIR

# 2. [Important] Check out llvmorg-19.1.7
git checkout llvmorg-19.1.7

# 3. Configure CMake (build shared libraries and enable Python bindings)
cmake -G Ninja -S llvm -B $LLVM_BUILD_DIR \
    -DLLVM_ENABLE_PROJECTS="mlir;clang" \
    -DBUILD_SHARED_LIBS=ON \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DPython3_EXECUTABLE=$(which python3) \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_TARGETS_TO_BUILD="host"

# 4. Build LLVM. This step takes a while.
ninja -C $LLVM_BUILD_DIR

```

### 3.3 Step 2: Build PTOAS (Out-of-Tree)

Download the PTOAS source and build it against the LLVM 19 build created above.

```bash
# 1. Download PTOAS source
cd $WORKSPACE_DIR
git clone https://gitcode.com/cann/pto-as.git PTOAS
cd $PTO_SOURCE_DIR

# 2. Get the pybind11 CMake path
export PYBIND11_CMAKE_DIR=$(python3 -m pybind11 --cmakedir)

# 3. Configure CMake
# Note: this uses the variables defined in section 3.0, so no manual edits are needed here.
cmake -G Ninja \
    -S . \
    -B build \
    -DLLVM_DIR=$LLVM_BUILD_DIR/lib/cmake/llvm \
    -DMLIR_DIR=$LLVM_BUILD_DIR/lib/cmake/mlir \
    -DPython3_EXECUTABLE=$(which python3) \
    -DPython3_FIND_STRATEGY=LOCATION \
    -Dpybind11_DIR="${PYBIND11_CMAKE_DIR}" \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DMLIR_PYTHON_PACKAGE_DIR=$LLVM_BUILD_DIR/tools/mlir/python_packages/mlir_core \
    -DCMAKE_INSTALL_PREFIX="$PTO_INSTALL_DIR"

# 4. Build and install
ninja -C build
ninja -C build install

# 5. Inspect build artifacts
# Build output, useful for local development and debugging
$PTO_SOURCE_DIR/build/python/
├── mlir
│   ├── _mlir_libs
│   │   └── _pto.cpython-*.so
│   └── dialects
│       ├── pto.py
│       └── _pto_ops_gen.py

# Install output, including Python dialect files and the native extension
$PTO_INSTALL_DIR/
└── mlir
    ├── dialects
    │   ├── pto.py
    │   └── _pto_ops_gen.py
    └── _mlir_libs
        └── _pto.cpython-*.so

# CLI tools
$PTO_SOURCE_DIR/build/tools/ptoas/ptoas
$PTO_SOURCE_DIR/build/tools/ptobc/ptobc

```

---

## 4. Runtime Environment

After the build completes, configure environment variables so the system can find the Python packages and dynamic libraries. You can add the following commands to `.bashrc` or a startup script.

```bash
# --- Runtime variable configuration, based on the paths defined above ---

# 1. Python path: combine MLIR Core and PTO Core
#    This lets Python find mlir.dialects.pto correctly during import.
export MLIR_PYTHON_ROOT=$LLVM_BUILD_DIR/tools/mlir/python_packages/mlir_core
export PTO_PYTHON_ROOT=$PTO_INSTALL_DIR/
export PYTHONPATH=$PTO_PYTHON_ROOT:$MLIR_PYTHON_ROOT:$PYTHONPATH

# 2. Library path: make sure LLVM and PTO dynamic libraries can be loaded.
export LD_LIBRARY_PATH=$LLVM_BUILD_DIR/lib:$PTO_INSTALL_DIR/lib:$LD_LIBRARY_PATH

# 3. PATH: add ptoas / ptobc to the command-line path.
export PATH=$PTO_SOURCE_DIR/build/tools/ptoas:$PTO_SOURCE_DIR/build/tools/ptobc:$PATH

```

---

## 5. Usage

### 5.1 Command-Line Tools (CLI)

```bash
# Parse and print PTO IR
ptoas test/lit/pto/empty_func.pto

# Run the AutoSyncInsert pass
ptoas test/lit/pto/empty_func.pto --enable-insert-sync -o outputfile.cpp

# Select target hardware architecture (A3 / A5)
ptoas test/lit/pto/empty_func.pto --pto-arch=a5 -o outputfile.cpp

# Select build level. level3 disables PlanMemory/InsertSync.
ptoas test/lit/pto/empty_func.pto --pto-level=level3 -o outputfile.cpp

# Show the current ptoas release version
ptoas --version

```

### 5.2 Python API

After the environment variables are configured, the PTO Dialect is loaded as part of `mlir.dialects`.

```python
from mlir.ir import Context, Module, Location
# [Important] Import pto from mlir.dialects. This is the standard out-of-tree binding pattern.
from mlir.dialects import pto

with Context() as ctx, Location.unknown():
    pto.register_dialect(ctx, load=True)
    module = Module.create()
    print("PTO Dialect registered successfully!")

```

### 5.3 Run Tests

```bash
# Run the Python binding test
cd $PTO_SOURCE_DIR/test/samples/MatMul/
python3 ./tmatmulk.py > ./tmatmulk.pto

# Run the ptoas test
$PTO_SOURCE_DIR/build/tools/ptoas/ptoas ./tmatmulk.pto -o ./tmatmulk.cpp
```

### 5.4 Board Validation

This flow automatically generates an NPU validation case from the `.cpp` output produced by `ptoas` under `test/samples`, then runs it on an NPU. The example below reuses `MatMul/tmatmulk.cpp` generated in section 5.3.

> For host-side compile-only validation on a machine without an NPU card, see [docs/no_npu_compile_only_guide_zh.md](docs/no_npu_compile_only_guide_zh.md).


```bash
# 1) Generate the npu_validation test directory. This creates npu_validation/ under the current sample directory.
# A2/A3 example:
python3 test/npu_validation/scripts/generate_testcase.py \
  --input test/samples/MatMul/tmatmulk.cpp \
  --run-mode npu \
  --soc-version Ascend910B1

# A5 example:
python3 test/npu_validation/scripts/generate_testcase.py \
  --input test/samples/MatMul/tmatmulk.cpp \
  --run-mode npu \
  --soc-version Ascend950

# 2) Run validation. run.sh does not require extra arguments.
test/samples/MatMul/npu_validation/tmatmulk/run.sh
```

Notes:
- `tmatmulk_kernel.cpp / main.cpp / golden.py / compare.py / run.sh / CMakeLists.txt` are generated under `test/samples/MatMul/npu_validation/tmatmulk/`.
- `golden.py` generates random inputs by default and defaults outputs to all zeros. It only guarantees that input/output counts, shapes, data types, and kernel parameters match.
- `compare.py` compares `golden*.bin` with `output*.bin` and reports an error on mismatch.

---
