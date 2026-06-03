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

- [predicate_pack_launch.py](/home/zhangzhendong/ptoas-workspace/PTOAS/test/dsl-st/predicate_pack_launch.py)
- [cube_matrix_pipeline.py](/home/zhangzhendong/ptoas-workspace/PTOAS/test/dsl-st/cube_matrix_pipeline.py)

They demonstrate:

- PTODSL kernel authoring
- How to write a host golden for a raw predicate image.
- The standard integration pattern for `golden_output_case(...)`.
- End-to-end simulator/ST authoring for a cube matrix pipeline.

## How To Run

Print generated MLIR:

```bash
python3 test/dsl-st/predicate_pack_launch.py --emit-mlir
```

Run simulator ST:

```bash
scripts/sim_dsl.sh test/dsl-st/predicate_pack_launch.py
```

If you only want to check the compilation chain first, you can also run:

```bash
python3 ptodsl/tests/test_jit_compile.py
```

## Authoring Tips

- Prefer making the golden result express the semantics directly; avoid writing `expected` as a hard-to-read pile of magic numbers.
- Try to make each test protect only one regression point. If you need to cover a tightly related set of forms, materialize them side by side in one kernel as `predicate_pack_launch.py` does.
- For predicate / bit-level results, prefer observing them with direct raw-state materialization such as `psts`; do not infer the result indirectly through side effects from other ops.
- Use native Python literals wherever possible to reduce unnecessary `pto.const(...)` noise.
- If a pattern depends on the current backend / raw image convention, leave a short comment near the golden result explaining why `expected` has that shape.
