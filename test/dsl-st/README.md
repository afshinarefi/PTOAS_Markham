# PTODSL ST Guide

`test/dsl-st/` contains simulator/ST cases based on PTODSL.

These tests are suitable for validating:

- Whether the PTODSL surface can correctly generate the target IR.
- Whether the `ptoas --pto-backend=vpto` backend can reliably accept these new forms.
- The actual kernel execution result on the simulator/runtime path.

If you need to validate behavior that only inspects compilation output, such as parser, verifier, pass dump, or IR rewrite behavior, prefer `test/lit` instead of this directory.

## Recommended Pattern

In this directory, prefer the two helpers from [common.py](/home/zhangzhendong/ptoas-workspace/PTOAS/test/dsl-st/common.py):

- `golden_output_case(...)`
- `auto_main(globals())`

目录级运行时，还可以直接使用：

- `python3 test/dsl-st`
- `scripts/sim_dsl.sh test/dsl-st`

对大多数单输出测试，开发者只需要写：
For most single-output tests, developers only need to write:

1. kernel
2. input construction
3. golden computation
4. `CASES = [...]`
5. one `auto_main(globals())` line at the end of the file

## Minimal Template

```python
#!/usr/bin/env python3

import numpy as np

from common import auto_main, golden_output_case
from ptodsl import pto


@pto.jit(name="my_kernel", kernel_kind="vector", target="a5", mode="explicit")
def my_kernel(
    inp_ptr: pto.ptr(pto.f32, "gm"),
    out_ptr: pto.ptr(pto.f32, "gm"),
    rows: pto.i32,
    cols: pto.i32,
):
    # write kernel here
    ...


def make_inputs():
    return [np.ones((4, 64), dtype=np.float32)]


def make_expected(inp):
    # compute golden from host inputs
    return inp + 1.0


CASES = [
    golden_output_case(
        "my_kernel_basic",
        my_kernel,
        inputs=make_inputs,
        expected=make_expected,
        rtol=0.0,
        atol=0.0,
    ),
]


auto_main(globals())
```

## `golden_output_case(...)` Contract

`golden_output_case(...)` is intended by default for tests with "several inputs + one output."

It automatically does the following:

- Converts `inputs` to host NumPy arrays.
- Allocates a zero-filled output from the shape/dtype of `expected`.
- Passes this output to the kernel as the last argument.
- By default, takes the last device tensor and compares it with the golden result.

Common parameters:

- `inputs`
  - Can be a function that returns `list[np.ndarray]`.
  - Can also be a direct `list[np.ndarray]`.
- `expected`
  - Can be a function with signature `expected(*host_inputs)`.
  - Can also be a direct NumPy array.
- `output_shape`
  - Specify explicitly if the output shape cannot be inferred directly from the golden result.
- `output_dtype`
  - Specify explicitly if the output dtype must be controlled separately from the golden result.
- `output_index`
  - Compares the last tensor by default; change this if the output is not the last tensor.
- `rtol` / `atol`
  - Set these explicitly for floating-point results; bit-level results usually use `0.0`.

## When To Use A Custom Case

If the test is not on the "single output compared with golden" path, do not force it into `golden_output_case(...)`.

Common examples:

- Multiple outputs need to be compared.
- Intermediate buffers need to be read.
- Custom assertion messages are needed.
- Structured checks based on runtime results are needed instead of `allclose`.

In these cases, use the lower-level `run_cases(...)` interface directly and customize:

- `make_case()`
- `check(device_inputs, expected)`

## Current Reference Cases

Refer directly to:

- [predicate_pack.py](/home/zhangzhendong/ptoas-workspace/PTOAS/test/dsl-st/predicate_pack.py)
- [cube_matrix_pipeline.py](/home/zhangzhendong/ptoas-workspace/PTOAS/test/dsl-st/cube_matrix_pipeline.py)

They demonstrate:

- PTODSL kernel authoring
- How to write a host golden for a raw predicate image.
- The standard integration pattern for `golden_output_case(...)`.
- End-to-end simulator/ST authoring for a cube matrix pipeline.

## How To Run

单文件打印生成的 MLIR：
Print generated MLIR:

```bash
python3 test/dsl-st/predicate_pack.py --emit-mlir
```

单文件走 simulator ST：
Run simulator ST:

```bash
scripts/sim_dsl.sh test/dsl-st/predicate_pack.py
```

自动发现整个目录下的测例并列出 case name：

```bash
python3 test/dsl-st --list
```

自动发现整个目录下的测例并打印合并 MLIR：

```bash
python3 test/dsl-st --emit-mlir
```

自动发现整个目录下的测例并走 simulator ST：

```bash
scripts/sim_dsl.sh test/dsl-st
```

If you only want to check the compilation chain first, you can also run:

```bash
python3 ptodsl/tests/test_jit_compile.py
```

## Authoring Tips

- 优先让 golden 直接表达语义，不要把 expected 写成难懂的魔数堆。
- 尽量让一个测试只保护一个回归点；如果要覆盖一组紧密相关的形态，可以像 `predicate_pack.py` 一样在同一个 kernel 里并排 materialize。
- 对 predicate / bit-level 结果，优先用 `psts` 这类“直接 materialize raw state”的方式观测，不要绕远路通过别的算子副作用来猜结果。
- 能用 Python 原生字面量的地方就直接用，减少不必要的 `pto.const(...)` 噪音。
- 如果某个写法依赖当前 backend / raw image 约定，最好在 golden 附近留一小段注释，解释为什么 expected 长这样。

## 自动发现约定

`test/dsl-st/` 目录级 runner 会自动加载当前目录下所有顶层 `.py` 用例文件，但会跳过：

- `common.py`
- `__main__.py`
- 以下划线开头的辅助模块

每个被发现的模块都需要定义非空 `CASES` 列表，且所有 case name 在目录内必须唯一。
- Prefer making the golden result express the semantics directly; avoid writing `expected` as a hard-to-read pile of magic numbers.
- Try to make each test protect only one regression point. If you need to cover a tightly related set of forms, materialize them side by side in one kernel as `predicate_pack_launch.py` does.
- For predicate / bit-level results, prefer observing them with direct raw-state materialization such as `psts`; do not infer the result indirectly through side effects from other ops.
- Use native Python literals wherever possible to reduce unnecessary `pto.const(...)` noise.
- If a pattern depends on the current backend / raw image convention, leave a short comment near the golden result explaining why `expected` has that shape.
