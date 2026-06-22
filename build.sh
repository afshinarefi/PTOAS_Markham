PYTHON=/opt/homebrew/bin/python3.13
LLVM_BUILD_DIR=/Users/melikanorouzbeygi/Workspace/Huawei/vpto-dev-llvm-build-noassert-rerun


cmake -G Ninja -S . -B build \
  -DLLVM_DIR="$LLVM_BUILD_DIR/lib/cmake/llvm" \
  -DMLIR_DIR="$LLVM_BUILD_DIR/lib/cmake/mlir" \
  -DPython3_EXECUTABLE="$PYTHON" \
  -DPython3_FIND_STRATEGY=LOCATION \
  -Dpybind11_DIR="$($PYTHON -m pybind11 --cmakedir)" \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DMLIR_PYTHON_PACKAGE_DIR="$LLVM_BUILD_DIR/tools/mlir/python_packages/mlir_core" \
  -DCMAKE_INSTALL_PREFIX="$PWD/install"
