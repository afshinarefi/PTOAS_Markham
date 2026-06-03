# PTOAS Build Guide With Installed LLVM

This document follows the structure of [README.md](../README.md) section 3 and applies when:

- LLVM/MLIR `19.1.7` has already been built and installed.
- The LLVM installation path is fixed at `/opt/llvm`.
- `/opt/llvm` is a shared directory, and the `ptoas` installation step should not write into it.

## 3.0 Environment Variable Setup

First define the variables following the approach in README section 3.0. The difference is that this setup no longer uses the LLVM source directory or LLVM build tree, and instead uses the LLVM install tree directly.

```bash
# ================= Configuration area (adjust for your environment) =================
export WORKSPACE_DIR=$HOME/llvm-workspace

# LLVM has already been installed; point directly to the install root.
export LLVM_INSTALL_DIR=/opt/llvm

# Keep LLVM_BUILD_DIR for compatibility with scripts/lit variable names in the repository.
export LLVM_BUILD_DIR=$LLVM_INSTALL_DIR

# ptoas source and install paths
export PTO_SOURCE_DIR=$WORKSPACE_DIR/PTOAS
export PTO_INSTALL_DIR=$PTO_SOURCE_DIR/install-optllvm
# ============================================================

mkdir -p "$WORKSPACE_DIR"
```

Notes:

- `LLVM_BUILD_DIR` is kept only for compatibility with existing variable names in the repository; it actually points to the LLVM install root `/opt/llvm`.
- Put `PTO_INSTALL_DIR` under PTOAS's own directory to avoid mixing it with the shared LLVM installation.

## 3.1 Environment Preparation

Follow README section 3.1, and make sure these dependencies are available:

- Linux
- GCC >= 9 or Clang
- CMake >= 3.20
- Ninja
- Python 3.8+
- `pybind11`
- `numpy`

```bash
pip3 install pybind11 numpy
```

## Skip 3.2

README section 3.2 covers downloading and building LLVM/MLIR. In this scenario, LLVM is already installed at `/opt/llvm`, so this section can be skipped.

Verified:

```bash
/opt/llvm/bin/llvm-config --version
```

Output:

```text
19.1.7
```

## 3.3 Step 2: Build ptoas

Follow the flow from README section 3.3, but change `LLVM_DIR` and `MLIR_DIR` to
`/opt/llvm/lib/cmake/...`.

`MLIR_PYTHON_PACKAGE_DIR` still points to LLVM's MLIR Python package. PTOAS
`pto.py`, `_pto_ops_gen.py`, and `_pto.cpython-*.so` are installed to
`CMAKE_INSTALL_PREFIX`; they are not written into the shared LLVM installation directory.

```bash
cd "$PTO_SOURCE_DIR"

# 1. Get pybind11's CMake path.
export PYBIND11_CMAKE_DIR=$(python3 -m pybind11 --cmakedir)

# 2. Configure CMake.
cmake -G Ninja \
    -S . \
    -B build \
    -DLLVM_DIR=$LLVM_INSTALL_DIR/lib/cmake/llvm \
    -DMLIR_DIR=$LLVM_INSTALL_DIR/lib/cmake/mlir \
    -DPython3_EXECUTABLE=$(which python3) \
    -DPython3_FIND_STRATEGY=LOCATION \
    -Dpybind11_DIR="${PYBIND11_CMAKE_DIR}" \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DMLIR_PYTHON_PACKAGE_DIR="$LLVM_INSTALL_DIR/python_packages/mlir_core" \
    -DCMAKE_INSTALL_PREFIX="$PTO_INSTALL_DIR"

# 3. Build and install.
ninja -C build
cmake --install build
```

## Key Artifacts After Build

With the configuration above, the key artifact locations are:

- build directory:
  - `$PTO_SOURCE_DIR/build/tools/ptoas/ptoas`
  - `$PTO_SOURCE_DIR/build/tools/ptobc/ptobc`
  - `$PTO_SOURCE_DIR/build/python/mlir/_mlir_libs/_pto.cpython-*.so`
  - `$PTO_SOURCE_DIR/build/python/mlir/dialects/pto.py`
- install directory:
  - `$PTO_INSTALL_DIR/bin/ptoas`
  - `$PTO_INSTALL_DIR/mlir/_mlir_libs/_pto.cpython-*.so`
  - `$PTO_INSTALL_DIR/mlir/dialects/pto.py`
  - `$PTO_INSTALL_DIR/share/ptoas/oplib/level3`

## Additional Runtime Environment

### Use `ptoas` From The build Directory

```bash
export PATH=$PTO_SOURCE_DIR/build/tools/ptoas:$PATH
export PYTHONPATH=$LLVM_INSTALL_DIR/python_packages/mlir_core:$PTO_SOURCE_DIR/build/python:$PYTHONPATH
export LD_LIBRARY_PATH=$LLVM_INSTALL_DIR/lib:$PTO_SOURCE_DIR/build/lib:$LD_LIBRARY_PATH
```

### Use `ptoas` From The install Directory

```bash
export PATH=$PTO_INSTALL_DIR/bin:$PATH
export PYTHONPATH=$LLVM_INSTALL_DIR/python_packages/mlir_core:$PTO_INSTALL_DIR:$PYTHONPATH
export LD_LIBRARY_PATH=$LLVM_INSTALL_DIR/lib:$PTO_INSTALL_DIR/lib:$LD_LIBRARY_PATH
```

Notes:

- The installed `ptoas` still needs to load LLVM/MLIR shared libraries from `/opt/llvm/lib`.
- If `$PTO_INSTALL_DIR/bin/ptoas` is run directly without `LD_LIBRARY_PATH=$LLVM_INSTALL_DIR/lib:...`, it will report missing `libMLIR*.so`.

## Local Validation Results

The current repository has been validated with this combination:

- `LLVM_DIR=/opt/llvm/lib/cmake/llvm`
- `MLIR_DIR=/opt/llvm/lib/cmake/mlir`
- `MLIR_PYTHON_PACKAGE_DIR=/opt/llvm/python_packages/mlir_core`
- `CMAKE_INSTALL_PREFIX=$PTO_INSTALL_DIR`

Minimal validation results:

- build `ptoas --version` outputs `ptoas 0.22`.
- build `ptoas` successfully processes `test/lit/pto/empty_func.pto`.
- installed Python bindings import correctly with `PYTHONPATH=/opt/llvm/python_packages/mlir_core:$PTO_INSTALL_DIR`.
- installed `ptoas` runs correctly when used with `LD_LIBRARY_PATH=/opt/llvm/lib:$PTO_INSTALL_DIR/lib`.
