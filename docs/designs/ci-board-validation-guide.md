# PTOAS CI and Board Validation Guide

## 1. Document Purpose

This document describes the three PTOAS validation paths that are currently most relevant to developers:

1. Local minimal reproduction: `build -> runop -> generate pto/cpp`
2. GitHub Actions: `Build Wheel` and `CI`
3. A3/A5 manual board validation triggered from PR comments

This document only covers flows that already exist in the current repository and are used directly in daily development. It does not expand on the internal implementation of the board-validation bot.

## 2. Current Flow Overview

### 2.1 `Build Wheel`

Corresponding workflow: `.github/workflows/build_wheel.yml`

Notes:

- The macOS wheel uses a separate workflow: `.github/workflows/build_wheel_mac.yml`
- The comment-triggered board-validation monitor currently depends on the Linux `Build Wheel` artifacts

Purpose:

- Build the Linux wheel
- Build the `ptoas` binary distribution package
- Produce artifacts downloaded by the comment-triggered board-validation monitor

Key artifacts:

- `ptoas-wheel-py<version>-x86_64`
- `ptoas-bin-x86_64`

Conclusions:

- If the PR head SHA does not have a successful `Build Wheel`, comment-triggered board validation usually cannot prepare the toolchain.
- When the board-validation bot reports `no successful workflow run named 'Build Wheel' found`, rerun this workflow first.

### 2.2 `CI`

Corresponding workflow: `.github/workflows/ci.yml`

Purpose:

- Build LLVM/MLIR and PTOAS on the GitHub runner
- Run `test/samples/runop.sh --enablebc all`
- For `workflow_dispatch` / `schedule`, package the payload and send the samples and scripts to the remote board machine to run `run_remote_npu_validation.sh`

Trigger differences:

- `push` / `pull_request`: only run the build and sample generation on the GitHub runner
- `workflow_dispatch` / `schedule`: also run the remote board-validation job `remote-npu-validation`

### 2.3 Comment-Triggered Board Validation

This part is not implemented in this repository, but the current development flow depends on it.

Purpose:

- Manually trigger A3 or A5 board validation from the PR comments
- Return the result to the GitHub comments and send a synchronized Feishu notification

Common commands:

- `/run a3`
- `/run all`
- `/run a5 <case>`
- `/run a5 case1,case2 --pto-level=level3`

Constraints:

- A5 manual board validation should currently provide an explicit case list. Running plain `/run a5` is not recommended.
- `/run all` is currently mainly used for the full A3 manual board-validation suite.
- If the PR conflicts with `origin/main`, the monitor should report the conflict and skip directly instead of continuing.

## 3. Local Minimal Reproduction

The commands below are aligned with the `CI` workflow as closely as possible. They are suitable for first checking locally during development that `py -> pto -> cpp` works correctly.

### 3.1 Build LLVM/MLIR

```bash
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
git checkout llvmorg-19.1.7

cmake -G Ninja -S llvm -B llvm/build-shared \
  -DLLVM_ENABLE_PROJECTS="mlir;clang" \
  -DBUILD_SHARED_LIBS=ON \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DPython3_EXECUTABLE=python3 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="host"

ninja -C llvm/build-shared
```

### 3.2 Build PTOAS

Run from the PTOAS repository root:

```bash
export LLVM_DIR=$PWD/llvm-project/llvm/build-shared
export PTO_INSTALL_DIR=$PWD/install
export PYBIND11_CMAKE_DIR="$(python3 -m pybind11 --cmakedir)"

cmake -G Ninja -S . -B build \
  -DLLVM_DIR="$LLVM_DIR/lib/cmake/llvm" \
  -DMLIR_DIR="$LLVM_DIR/lib/cmake/mlir" \
  -DPython3_EXECUTABLE=python3 \
  -DPython3_FIND_STRATEGY=LOCATION \
  -Dpybind11_DIR="$PYBIND11_CMAKE_DIR" \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DMLIR_PYTHON_PACKAGE_DIR="$LLVM_DIR/tools/mlir/python_packages/mlir_core" \
  -DCMAKE_INSTALL_PREFIX="$PTO_INSTALL_DIR" \
  -DCMAKE_BUILD_TYPE=Release

ninja -C build ptoas
ninja -C build ptobc
ninja -C build install
```

### 3.3 Run the Sample Generation Flow

```bash
export MLIR_PYTHON_ROOT=$PWD/llvm-project/llvm/build-shared/tools/mlir/python_packages/mlir_core
export PTO_PYTHON_ROOT=$PWD/install
export PYTHONPATH="$MLIR_PYTHON_ROOT:$PTO_PYTHON_ROOT:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="$LLVM_DIR/lib:$PTO_INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
export PTOAS_BIN=$PWD/build/tools/ptoas/ptoas

bash test/samples/runop.sh --enablebc all
```

To run a single directory:

```bash
bash test/samples/runop.sh --enablebc -t Sync
```

To run a single Python sample, you can also enter the corresponding directory and execute it directly, but you must ensure `PYTHONPATH` / `LD_LIBRARY_PATH` / `PTOAS_BIN` are aligned.

To locally reproduce A5 / Qwen-style cases, explicitly provide the `ptoas` arguments:

```bash
export PTOAS_FLAGS="--pto-arch=a5 --pto-level=level3"
bash test/samples/runop.sh --enablebc -t Qwen3Decode
```

Notes:

- `runop.sh` supports passing additional `ptoas` arguments through `PTOAS_FLAGS`
- `runop.sh` appends `--enable-insert-sync` by default
- When locally reproducing board-validation issues, prefer keeping `PTOAS_FLAGS` consistent with comment-triggered board validation

### 3.4 Run the Remote Board-Validation Script Directly

If you are already on the board machine, or the GitHub Actions payload is already prepared, you can run directly:

```bash
STAGE=run \
RUN_MODE=npu \
SOC_VERSION=Ascend910B1 \
DEVICE_ID=2 \
SKIP_CASES='mix_kernel,vadd_validshape,vadd_validshape_dynamic,print,storefp' \
bash test/npu_validation/scripts/run_remote_npu_validation.sh
```

A5 example:

```bash
STAGE=run \
RUN_MODE=npu \
SOC_VERSION=Ascend950 \
RUN_ONLY_CASES='qwen3_decode_layer_incore_0,qwen3_decode_layer_incore_1' \
DEVICE_ID=1 \
bash test/npu_validation/scripts/run_remote_npu_validation.sh
```

Notes:

- `RUN_ONLY_CASES` and `SKIP_CASES` both support comma or space separators.
- `run_remote_npu_validation.sh` automatically sources common Ascend environment scripts and tries to detect `ASCEND_HOME_PATH`.
- During full runs, `ci.yml` automatically excludes A3-only / A5-only cases based on `SOC_VERSION`; during manual runs, you must check whether the target architecture matches.

## 4. How to Run GitHub Actions

### 4.1 What Runs by Default for PRs

After a PR is created or pushed, at least two workflows are involved:

1. `Build Wheel`
2. `CI`

Recommended check order:

1. Whether `Build Wheel` succeeded
2. Whether the `CI` `build-and-test` job succeeded
3. If board validation is needed, decide whether to use `workflow_dispatch` or the comment-triggered monitor

### 4.2 Manually Trigger `Build Wheel`

When comment-triggered board validation is missing toolchain artifacts, manually rerun this first:

```bash
gh workflow run build_wheel.yml \
  --repo hw-native-sys/PTOAS \
  --ref <your-branch>
```

Check artifacts:

```bash
gh run list --repo hw-native-sys/PTOAS --workflow 'Build Wheel' --limit 5
```

### 4.3 Manually Trigger `CI` Remote Board Validation

The `CI` `remote-npu-validation` job only runs under `workflow_dispatch` or scheduled tasks.

Command-line example:

```bash
gh workflow run ci.yml \
  --repo hw-native-sys/PTOAS \
  --ref main \
  -f stage=run \
  -f run_mode=npu \
  -f soc_version=Ascend910B1 \
  -f device_id=2 \
  -f skip_cases='mix_kernel,vadd_validshape,vadd_validshape_dynamic,print,storefp' \
  -f run_only_cases=''
```

A5 example:

```bash
gh workflow run ci.yml \
  --repo hw-native-sys/PTOAS \
  --ref main \
  -f stage=run \
  -f run_mode=npu \
  -f soc_version=Ascend950 \
  -f device_id=1 \
  -f run_only_cases='qwen3_decode_layer_incore_0,qwen3_decode_layer_incore_1'
```

Key input descriptions:

- `stage`: `build` or `run`
- `run_mode`: `npu` or `sim`
- `soc_version`: for example `Ascend910B1`, `Ascend950`
- `device_id`: device id for remote `aclrtSetDevice`
- `skip_cases`: skip list
- `run_only_cases`: run-only list
- `pto_isa_repo` / `pto_isa_commit`: specify the `pto-isa` used for board validation
- `remote_host` / `remote_user` / `remote_port`: specify the remote board machine

## 5. PR Comment-Triggered Board Validation

### 5.1 Checks Before Triggering

Check these first:

1. Whether the PR can merge cleanly into `origin/main`
2. Whether the corresponding head SHA or merge SHA has a successful `Build Wheel`
3. Whether the cases to run already have comparable golden / compare assets
4. Whether A3 / A5 cases need to be split by architecture

### 5.2 Common Commands

A3 full run:

```text
/run a3
```

A3 manual full-run entry point:

```text
/run all
```

A5 single case:

```text
/run a5 qwen3_decode_layer_incore_0 --pto-level=level3
```

A5 multiple cases:

```text
/run a5 qwen3_decode_layer_incore_0,qwen3_decode_layer_incore_1,qwen3_decode_layer_incore_2 --pto-level=level3
```

Notes:

- Case lists support comma separation; prefer commas to reduce parsing ambiguity.
- A5 currently recommends always specifying an explicit case list.
- Qwen-style A5 cases often also include `--pto-level=level3`.

### 5.3 How to Read Results

There are usually two result channels:

1. GitHub comment summary
2. Feishu bot message

Common statuses:

- `OK / FAIL / SKIP`
- `fetch-source`: failed to fetch source
- `prepare-toolchain`: failed to download or unpack the board-validation toolchain
- `sample-build-and-test`: failed during sample generation, compilation, or execution
- `internal`: monitor internal exception

## 6. Notes When Adding Cases

### 6.1 Which Files `runop.sh` Executes

`test/samples/runop.sh` iterates over `*.py` files under sample directories, but skips:

- `*_golden.py`
- `*_compare.py`

This means:

- Do not casually name pure helper scripts as ordinary `*.py` files
- If a helper is only reused by golden logic, prefer naming it `*_golden.py`, or place it under a path that `runop.sh` will not execute as an entry script

Otherwise, `runop.sh all` treats it as a sample-generation entry point, which can send empty IR or incorrect IR into `ptoas`.

### 6.2 Where to Place Golden / Compare Assets

The current sample flow automatically copies:

- `*_golden.py` under the sample directory
- `*_compare.py` under the sample directory
- `npu_validation/golden.py` under the sample directory
- `npu_validation/compare.py` under the sample directory

Recommendations:

- For case-specific golden logic, use `<case>_golden.py`
- For case-specific compare logic, use `<case>_compare.py`
- When multiple cases share logic, do not give common code an ordinary script name that will be matched as an entry point

### 6.3 A3 / A5 Routing

If a case only applies to one architecture, also update the routing lists in `.github/workflows/ci.yml`:

- `A3_ONLY_CASES`
- `A5_ONLY_CASES`

Otherwise:

- A3 may incorrectly run A5 cases
- A5 may incorrectly run A3 cases
- Full board validation may report false positives unrelated to the feature itself

## 7. FAQ

### 7.1 Why Is the PR `CI` Green, but Comment-Triggered Board Validation Still Cannot Start?

The most common cause is not the case itself, but unmet toolchain prerequisites:

- `Build Wheel` did not succeed
- The PR has no usable merge ref
- The board-validation monitor failed to fetch source or download artifacts

Check the failure stage reported by the bot first; do not immediately retry many times.

### 7.2 Why Is Plain `/run a5` Not Recommended for A5 Manual Board Validation?

The current A5 monitor is better suited to explicit case lists, especially for scenarios such as Qwen and Tilelet that only run partial regressions. A plain empty run makes the intended validation unclear and is more likely to be affected by unrelated cases.

### 7.3 Why Did `runop all` Fail After Adding a Helper Script?

Because `runop.sh` treats ordinary `*.py` files as sample entry points by default. If a helper does not follow the golden/compare naming pattern, it will be executed by mistake.

### 7.4 When Should I Use `workflow_dispatch`, and When Should I Use Comment-Triggered Board Validation?

Recommendations:

- Use `workflow_dispatch` when directly validating remote scripts, payloads, or `run_remote_npu_validation.sh`
- Use the comment-triggered monitor for routine PR board validation and Feishu/GitHub comment feedback

## 8. Reference Files

- `.github/workflows/build_wheel.yml`
- `.github/workflows/ci.yml`
- `test/samples/runop.sh`
- `test/npu_validation/scripts/run_remote_npu_validation.sh`
- `test/npu_validation/scripts/generate_testcase.py`
