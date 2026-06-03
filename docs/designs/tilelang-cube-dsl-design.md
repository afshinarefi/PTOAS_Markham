# TileLang Cube DSL Design

> **Status:** Requirements alignment is complete; not yet implemented
> **Scope:** Python frontend syntax design; backend lowering implementation details are out of scope

---

## 1. Background and Motivation

### 1.1 Hardware Background

PTOAS target hardware contains two independent compute units:

| Unit | Hardware Core | IR kernel_kind | Compile Macro | Typical Operations |
|------|---------|----------------|--------|---------|
| **Vector** | AIV | `#pto.kernel_kind<vector>` | `__DAV_VEC__` | vector load/store/ALU/predicate |
| **Cube** | AIC | `#pto.kernel_kind<cube>` | `__DAV_CUBE__` | matrix multiplication (MAD), fractal data movement |

**Key constraint: the two instruction kinds cannot appear in the same function.** This is a hardware limitation. The compiler verifier already enforces it at the IR layer through the `verifyFrontendKernelKind` check, and the DSL design must reflect this separation at the Python syntax layer.

### 1.2 Current Status

- **Vector DSL**: A complete `@vkernel` decorator plus `pto.vecscope` / `pto.strict_vecscope` scope mechanism already exists, with both basic and advanced API surfaces.
- **Cube IR**: VPTO bridge-layer instructions (`pto.mte_gm_l1`, `pto.mad`, `pto.mte_l0c_l1`, and others) are fully defined at the IR layer and have lowering and LLVM emission support.
- **Missing link**: There is no corresponding Python DSL frontend, so programmers cannot write Cube instructions in Python.

### 1.3 Design Goals

1. Provide an `@ckernel` decorator alongside `@vkernel`, distinguishing the hardware unit at the entry layer.
2. Expose the full VPTO bridge-layer Cube operations, including data movement and matrix compute.
3. Support the template-slot `pto.tpl()` mechanism and reuse the Vector DSL design pattern.
4. Prevent Cube/Vector instruction mixing during DSL semantic analysis.

### 1.4 Design Principles

- **Represent GM data with TensorView / PartitionTensorView**: GM input data for Cube tileops is expressed through `TensorView` (logical tensor view) or `PartitionTensorView` (partitioned view), not through `Tile`.
- **Use Tile for buffers in specific address spaces**: The `Tile` type represents a tile buffer allocated in a specific hardware address space (LEFT/RIGHT/ACC/MAT/BIAS).
- **Use ptr at the VPTO bridge layer**: Cube bridge operands use raw `pto.ptr<T, addr_space>` pointers, obtained from Tile/TensorView via `.as_ptr()`.
- **Allocate tile buffers with address-space and layout configuration through the `pto.Tile` constructor**: Use the `pto.Tile` constructor to allocate tile buffers with address-space and layout configuration.
- **Synchronization is out of scope for this pass**: This design only focuses on exposing the Cube instructions themselves in the DSL; synchronization is inserted automatically by `--enable-insert-sync`.
- **Keep parameter order consistent with IR**: Avoid extra mental overhead.

---

## 2. `@ckernel` Decorator

### 2.1 Basic Syntax

```python
from tilelang_dsl import ckernel, Tile, MemorySpace, select_kernel

@ckernel(
    op="pto.mad",                              # single op name
    dtypes=[(pto.f16, pto.f16, pto.f32)],      # supported dtype combinations
    name="my_matmul",                          # template name
    # Optional parameters follow
    ops=["mad", "mad_acc", "mad_bias"],        # multi-op template slots
    templates={                                # slot -> concrete op mapping
        "compute": {
            "mad": "mad",
            "mad_acc": "mad_acc",
            "mad_bias": "mad_bias",
        }
    },
)
def kernel(
    a_tv: PartitionTensorView,  # GM input, expressed through PartitionTensorView
    b_tv: PartitionTensorView,
    c_tv: PartitionTensorView,  # GM output
    M: int, K: int, N: int,
):
    ...
```

### 2.2 Parameter Description

| Parameter | Type | Required | Description |
|------|------|------|------|
| `op` | str | one of `op` or `ops` | Single op name, such as `"pto.mad"` |
| `ops` | list[str] | one of `op` or `ops` | Multi-op name list, enabling the template-slot mechanism |
| `dtypes` | list[tuple] | yes | Supported dtype combinations, such as `[(f16, f16, f32)]` |
| `name` | str | yes | Template name, used for registration and selection |
| `templates` | dict | no | Template-slot mapping, mapping `pto.tpl("slot", ...)` to a concrete op |
| `target` | str | no | Target architecture, default `"a5"` |

### 2.3 Function Parameter Type Conventions

The parameter types of a Cube kernel reflect their roles in the dataflow:

| Parameter Type | Purpose | Description |
|----------|------|------|
| `PartitionTensorView` | partitioned input/output on GM | Passed by the caller after slicing a sub-block from the full `TensorView` through `PartitionViewOp` |
| `TensorView` | full logical tensor on GM | Used for scenarios that do not require partitioning |
| `Tile` (specific addr space) | allocated hardware tile buffer | Passed when the caller has already allocated a LEFT/RIGHT/ACC tile, etc. |
| `int` | dimension parameter | Matrix dimensions such as M, K, and N |
| `pto.f16` / `pto.f32`, etc. | scalar parameter | Values such as threshold and alpha |
| `pto.ptr<T, addr>` | raw pointer | Used when direct pointer manipulation is needed, such as a GM pointer |

### 2.4 Key Differences from `@vkernel`

| Feature | @vkernel | @ckernel |
|------|----------|----------|
| Hardware unit | Vector (AIV) | Cube (AIC) |
| Execution scope | `pto.vecscope` / `pto.strict_vecscope` | **No scope required**; the function body is directly linear Cube code |
| GM data representation | `TensorView` / `Tile` | `TensorView` / `PartitionTensorView` |
| Buffers | Tile (UB/VEC) | Tile (MAT/LEFT/RIGHT/ACC/BIAS) |
| Operand abstraction | Tile plus vector registers and masks inside VecScope | Raw `pto.ptr<T, addr_space>` pointers |
| Core operations | vector ALU, load/store | data movement plus matrix multiplication (mad) |
| Generated IR attribute | `#pto.kernel_kind<vector>` | `#pto.kernel_kind<cube>` |

---

## 3. Cube Programming Model

### 3.1 Dataflow

```text
PartitionTensorView (GM)
       |
       +--(cube_load)--> L1/cbuf (MAT) --(left_load)--> L0A (LEFT)
       |                                                   |
       +--(cube_load)--> L1/cbuf (MAT) --(right_load)--> L0B (RIGHT)
       |                                                   |
       |                                              +----+
       |                                              v
       |                                         +----------+
       |                                         | pto.mad  |
       |                                         +----------+
       |                                              |
       |                                              v
       |    L1/cbuf (MAT) <--(acc_store)-- L0C (ACC)
       |         |                                    |
       |         +--(cube_store)--> UB (VEC)          |
       |         +--(acc_store_gm)--> GM  <-----------+
       |         +--(acc_store_ub)--> UB
       |
       v
PartitionTensorView (GM, writeback)
```

### 3.2 Address Spaces

| Address Space | Enum Value | Description | Corresponding IR Type |
|----------|--------|------|-------------|
| `GM` | `MemorySpace.GM` | global memory | `!pto.ptr<T, gm>` |
| `MAT` | `MemorySpace.MAT` | L1 buffer (cbuf) | `!pto.ptr<T, l1>` |
| `LEFT` | `MemorySpace.LEFT` | L0A matrix left-operand buffer | `!pto.ptr<T, l0a>` |
| `RIGHT` | `MemorySpace.RIGHT` | L0B matrix right-operand buffer | `!pto.ptr<T, l0b>` |
| `ACC` | `MemorySpace.ACC` | L0C accumulator buffer | `!pto.ptr<T, l0c>` |
| `BIAS` | `MemorySpace.BIAS` | Bias table | `!pto.ptr<T, bt>` |
| `UB` | `MemorySpace.UB` | unified buffer (Vector side) | `!pto.ptr<T, ub>` |

### 3.3 Buffer Allocation Interface

#### `pto.Tile` Constructor

```python
pto.Tile(
    shape: tuple[int, ...],           # buffer shape (required)
    dtype: pto dtype,                 # element type (required)
    memory_space: MemorySpace,        # address space (required)
    valid_shape: tuple[int, ...] | None = None,    # valid region; defaults to shape
    blayout: BLayout | None = None,               # B layout; defaults by address space
    slayout: SLayout | None = None,               # S layout; defaults by address space
    fractal_size: int | None = None,              # fractal size; defaults by address space
    pad_value: PadValue = PadValue.Null,          # padding policy
    compact_mode: CompactMode = CompactMode.Null, # compact mode
    addr: int | None = None,                      # preallocated address (used by level3)
) -> Tile
```

**Layout Configuration Defaults by Address Space:**

| Address Space | blayout | slayout | fractal_size |
|----------|---------|---------|-------------|
| `MAT` | `ColMajor` | `RowMajor` | `TileConfig.fractalABSize` (512) |
| `LEFT` | `ColMajor` | `RowMajor` | `TileConfig.fractalABSize` (512) |
| `RIGHT` | `RowMajor` | `ColMajor` | `TileConfig.fractalABSize` (512) |
| `ACC` | `ColMajor` | `RowMajor` | `TileConfig.fractalCSize` (1024) |
| `BIAS` | `RowMajor` | `NoneBox` | `TileConfig.fractalABSize` (512) |

**Enum Value Definitions:**

| Enum Type | Allowed Values |
|----------|--------|
| `BLayout` | `ColMajor` (0), `RowMajor` (1) |
| `SLayout` | `NoneBox` (0), `RowMajor` (1), `ColMajor` (2) |
| `PadValue` | `Null` (0), `Zero` (1), `Max` (2), `Min` (3) |
| `CompactMode` | `Null` (0), `Normal` (1), `RowPlusOne` (2) |

#### `.as_ptr()`

Obtain a raw pointer from a Tile or TensorView/PartitionTensorView through a method call:

```python
# Get a pointer from Tile; the address space is determined by the Tile type
l0a_ptr = l0a_tile.as_ptr()  # Tile[LEFT] -> pto.ptr<f16, left>

# Get GM pointers from TensorView / PartitionTensorView
gm_ptr = tensor_view.as_ptr()  # TensorView -> pto.ptr<f16, gm>
a_ptr = a_tv.as_ptr()          # PartitionTensorView -> pto.ptr<f16, gm>
```

### 3.4 Pointer Offset

Submatrix addressing is implemented with `pto.addptr`, and the offset is measured in elements:

```python
a_k = pto.addptr(a_ptr, k_off)  # offset by k_off elements
```

No tile-slice syntax sugar is introduced; this keeps the abstraction consistent with the VPTO-layer ptr model.

### 3.5 Typical Programming Pattern

```python
@ckernel(op="pto.mad", dtypes=[(pto.f16, pto.f16, pto.f32)], name="gemm")
def gemm(a_tv: PartitionTensorView,  # GM input A [M, K]
         b_tv: PartitionTensorView,  # GM input B [K, N]
         c_tv: PartitionTensorView,  # GM output C [M, N]
         M: int, K: int, N: int):
    # 1. Get GM pointers from PartitionTensorView
    a_ptr = a_tv.as_ptr()  # -> pto.ptr<f16, gm>
    b_ptr = b_tv.as_ptr()  # -> pto.ptr<f16, gm>
    c_ptr = c_tv.as_ptr()  # -> pto.ptr<f32, gm>

    # 2. Allocate L1 (MAT) tile buffers and get pointers
    l1_a = pto.Tile([M, K], pto.f16, MemorySpace.MAT)
    l1_b = pto.Tile([K, N], pto.f16, MemorySpace.MAT)

    # 3. Allocate L0 tile buffers and get pointers
    l0a = pto.Tile([M, K], pto.f16, MemorySpace.LEFT)
    l0b = pto.Tile([K, N], pto.f16, MemorySpace.RIGHT)
    l0c = pto.Tile([M, N], pto.f32, MemorySpace.ACC)

    # 4. GM -> L1 data movement
    pto.mte_gm_l1(a_ptr, l1_a.as_ptr(), K, nburst=(1, 0, 0))
    pto.mte_gm_l1(b_ptr, l1_b.as_ptr(), N, nburst=(1, 0, 0))

    # 5. L1 -> L0 data movement
    pto.mte_l1_l0a(l1_a.as_ptr(), l0a.as_ptr(), M, K)
    pto.mte_l1_l0b(l1_b.as_ptr(), l0b.as_ptr(), K, N)

    # 6. Matrix multiplication
    pto.mad(l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), M, N, K)

    # 7. L0C -> GM result writeback
    pto.mte_l0c_gm(l0c.as_ptr(), c_ptr, M, N,
                     src_stride=N, dst_stride=N,
                     mode="nz2nd")
```

---

## 4. Cube Operation API Surface

The following are the supported `pto.*` calls inside an `@ckernel` function body. All operands use the `pto.ptr<T, addr_space>` pointer type.

### 4.1 Matrix Compute Operations

#### `pto.mad` - Zero-Initialized Matrix Multiplication

```python
pto.mad(lhs: pto.ptr<T, left>, rhs: pto.ptr<T, right>, dst: pto.ptr<U, acc>,
        m: int, n: int, k: int,
        unit_flag_ctrl: int = 0, disable_gemv: bool = False)
```

Semantics: `dst = lhs * rhs` after zero-initializing the accumulator.

#### `pto.mad_acc` - Accumulating Matrix Multiplication

```python
pto.mad_acc(lhs: pto.ptr<T, left>, rhs: pto.ptr<T, right>, dst: pto.ptr<U, acc>,
            m: int, n: int, k: int,
            unit_flag_ctrl: int = 0, disable_gemv: bool = False)
```

Semantics: `dst += lhs * rhs`.

#### `pto.mad_bias` - Matrix Multiplication with Bias

```python
pto.mad_bias(lhs: pto.ptr<T, left>, rhs: pto.ptr<T, right>, dst: pto.ptr<U, acc>,
             bias: pto.ptr<U, bias>,
             m: int, n: int, k: int,
             unit_flag_ctrl: int = 0, disable_gemv: bool = False)
```

Semantics: `dst = lhs * rhs + bias`.

#### `pto.mad_mx` / `pto.mad_mx_acc` / `pto.mad_mx_bias`

MX micro-scaling variants. Their parameters are the same as the corresponding non-MX versions, and they are used for MX data types such as `f8`.

### 4.2 Data Movement Operations

#### `pto.mte_gm_l1` - GM -> L1 (cbuf)

```python
pto.mte_gm_l1(src: pto.ptr<T, gm>, dst: pto.ptr<T, mat>,
              len_burst: int,
              nburst: tuple[int, int, int] = (1, 0, 0),
              loops: list[tuple[int, int, int]] | None = None)
```

#### `pto.mte_l1_ub` - L1 (cbuf) -> UB

```python
pto.mte_l1_ub(src: pto.ptr<T, mat>, dst: pto.ptr<T, ub>,
               len_burst: int,
               nburst: tuple[int, int, int] = (1, 0, 0),
               loops: list[tuple[int, int, int]] | None = None)
```

#### `pto.mte_gm_l1_frac` - Fractal Load (nd2nz / dn2nz)

```python
pto.mte_gm_l1_frac(src: pto.ptr<T, gm>, dst: pto.ptr<T, mat>,
                   mode: str,  # "nd2nz" | "dn2nz"
                   shape: tuple[int, int],          # (n_value, d_value)
                   src_layout: tuple[int, int],     # (inner_stride, outer_stride)
                   dst_group: tuple[int, int, int, int],  # (count, l2s, l3s, l4s)
                   ctrl: tuple[int, bool])          # (l2_cache_ctrl, smallc0_en)
```

#### `pto.mte_l1_bt` - L1 (cbuf) -> Bias Table

```python
pto.mte_l1_bt(src: pto.ptr<T, mat>, dst: pto.ptr<U, bias>,
              len_burst: int,
              nburst: tuple[int, int, int] = (1, 0, 0))
```

#### `pto.mte_l1_l0a` - L1 (cbuf) -> L0A

```python
pto.mte_l1_l0a(src: pto.ptr<T, mat>, dst: pto.ptr<T, left>,
              m: int, k: int,
              start_row: int, start_col: int)
```

#### `pto.mte_l1_l0b` - L1 (cbuf) -> L0B

```python
pto.mte_l1_l0b(src: pto.ptr<T, mat>, dst: pto.ptr<T, right>,
               k: int, n: int,
               start_row: int, start_col: int)
```

DSL frontends may let users omit `start_row` and `start_col`; omitted start
positions are materialized as `0` before emitting PTO IR.

#### `pto.mte_l1_l0a_mx` / `pto.mte_l1_l0b_mx`

MX-mode L1->L0A/L0B movement. Parameters are the same as the non-MX versions.

### 4.3 Result Writeback Operations

#### `pto.mte_l0c_l1` - L0C (acc) -> L1 (cbuf)

```python
pto.mte_l0c_l1(src: pto.ptr<T, acc>, dst: pto.ptr<T, mat>,
              m: int, n: int,
              src_stride: int, dst_stride: int,
              mode: str = "nz2nd",  # "nz2nd" | "nz2dn" | "nz2nz"
              loop0_src_stride: int | None = None,   # required when mode="nz2dn"
              split: int | None = None,              # required when mode="nz2nz"
              loop3: tuple[int, int, int] | None = None)
```

#### `pto.mte_l0c_gm` - L0C (acc) -> GM

```python
pto.mte_l0c_gm(src: pto.ptr<T, acc>, dst: pto.ptr<T, gm>,
                 m: int, n: int,
                 src_stride: int, dst_stride: int,
                 sid: int = 0, l2_cache_ctrl: int = 0,
                 mode: str = "nz2nd",
                 loop0_src_stride: int | None = None,
                 split: int | None = None,
                 loop3: tuple[int, int, int] | None = None)
```

#### `pto.mte_l0c_ub` - L0C (acc) -> UB

```python
pto.mte_l0c_ub(src: pto.ptr<T, acc>, dst: pto.ptr<T, ub>,
                 m: int, n: int,
                 src_stride: int, dst_stride: int,
                 dual_dst_mode: int = 0, sub_blockid: int = 0,
                 mode: str = "nz2nd",
                 loop0_src_stride: int | None = None,
                 channel_split_en: int | None = None,  # required when mode="nz2nz"
                 loop3: tuple[int, int, int] | None = None)
```

---

## 5. Template Slot Mechanism

### 5.1 Design

Reuse the Vector DSL `pto.tpl()` mechanism, allowing one Cube kernel template to adapt to multiple mad operation variants.

### 5.2 Syntax

```python
@ckernel(
    ops=["mad", "mad_acc"],
    dtypes=[(pto.f16, pto.f16, pto.f32)],
    name="gemm_template",
    templates={
        "compute": {"mad": "mad", "mad_acc": "mad_acc"},
    },
)
def gemm_template(a_tv: PartitionTensorView, b_tv: PartitionTensorView,
                  c_tv: PartitionTensorView, M: int, K: int, N: int):
    a_ptr = a_tv.as_ptr()
    b_ptr = b_tv.as_ptr()
    c_ptr = c_tv.as_ptr()

    l1_a = pto.Tile([M, K], pto.f16, MemorySpace.MAT)
    l1_b = pto.Tile([K, N], pto.f16, MemorySpace.MAT)
    l0a = pto.Tile([M, K], pto.f16, MemorySpace.LEFT)
    l0b = pto.Tile([K, N], pto.f16, MemorySpace.RIGHT)
    l0c = pto.Tile([M, N], pto.f32, MemorySpace.ACC)

    pto.mte_gm_l1(a_ptr, l1_a.as_ptr(), K, nburst=(1, 0, 0))
    pto.mte_gm_l1(b_ptr, l1_b.as_ptr(), N, nburst=(1, 0, 0))
    pto.mte_l1_l0a(l1_a.as_ptr(), l0a.as_ptr(), M, K)
    pto.mte_l1_l0b(l1_b.as_ptr(), l0b.as_ptr(), K, N)

    # Template slot: automatically replaced with mad or mad_acc according to selected_op
    pto.tpl("compute", l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), M, N, K)

    pto.mte_l0c_gm(l0c.as_ptr(), c_ptr, M, N,
                     src_stride=N, dst_stride=N, mode="nz2nd")
```

Usage:

```python
k_mad = select_kernel("a5", "gemm_template", selected_op="mad")
k_acc = select_kernel("a5", "gemm_template", selected_op="mad_acc")
```

### 5.3 Constraints

Variants in the same template slot must have identical parameter signatures:

| Slot Group | Members | Parameters |
|--------|------|------|
| `compute` | `mad`, `mad_acc` | `(lhs, rhs, dst, m, n, k)` |
| `compute_bias` | `mad_bias` | `(lhs, rhs, dst, bias, m, n, k)` |
| `compute_mx` | `mad_mx`, `mad_mx_acc` | `(lhs, rhs, dst, m, n, k)` |

Variants with different parameters, such as mad vs. mad_bias, cannot be placed in the same slot.

---

## 6. Hardware Separation Rules

### 6.1 Function-Level Isolation

- Functions generated by `@ckernel` carry the `#pto.kernel_kind<cube>` attribute.
- Functions generated by `@vkernel` carry the `#pto.kernel_kind<vector>` attribute.
- The verifier prevents the two instruction kinds from appearing in the same function at the IR layer.

### 6.2 DSL-Level Enforcement

During semantic analysis:

1. Vector-only operations such as `vlds` and `vadd` are not allowed inside an `@ckernel` function body.
2. `pto.vecscope` / `pto.strict_vecscope` are not allowed inside an `@ckernel` function body.
3. CKernel cannot call a VKernel `inline_proc`, and vice versa.

### 6.3 Module Level

- The same `.py` file may define both `@ckernel` and `@vkernel`.
- Each function is compiled independently, and the EmitC backend uses the `__DAV_CUBE__` / `__DAV_VEC__` macro guards for conditional compilation.

---

## 7. Shared Infrastructure with the Vector DSL

| Facility | Description |
|------|------|
| `TensorView` / `PartitionTensorView` | High-level views of GM data; both are shared |
| `Tile` type | Buffer type annotation, using `MemorySpace` to distinguish address spaces |
| `select_kernel()` / `KernelRegistry` | Kernel registration and selection |
| `MaterializedMLIRModule` | Materialized MLIR module |
| `pto.ptr` / `pto.castptr` / `pto.addptr` | Pointer operations |
| `MemorySpace` | Address-space enum, already including MAT/LEFT/RIGHT/ACC/BIAS |
| `Tile` constructor | Buffer allocation, constructed through `pto.Tile()` |
| `TileConfig` | Constants such as fractal sizes |

---

## 8. Complete Examples

### 8.1 Basic GEMM

```python
from tilelang_dsl import ckernel, Tile, MemorySpace

@ckernel(
    op="pto.mad",
    dtypes=[(pto.f16, pto.f16, pto.f32)],
    name="gemm",
)
def gemm(a_tv: PartitionTensorView,   # [M, K] in GM
         b_tv: PartitionTensorView,   # [K, N] in GM
         c_tv: PartitionTensorView,   # [M, N] in GM, output
         M: int, K: int, N: int):
    # Get GM pointers from PartitionTensorViews
    a_ptr = a_tv.as_ptr()
    b_ptr = b_tv.as_ptr()
    c_ptr = c_tv.as_ptr()

    # Allocate tiles in respective address spaces
    l1_a = pto.Tile([M, K], pto.f16, MemorySpace.MAT)
    l1_b = pto.Tile([K, N], pto.f16, MemorySpace.MAT)
    l0a = pto.Tile([M, K], pto.f16, MemorySpace.LEFT)
    l0b = pto.Tile([K, N], pto.f16, MemorySpace.RIGHT)
    l0c = pto.Tile([M, N], pto.f32, MemorySpace.ACC)

    # Data movement
    pto.mte_gm_l1(a_ptr, l1_a.as_ptr(), K, nburst=(1, 0, 0))
    pto.mte_gm_l1(b_ptr, l1_b.as_ptr(), N, nburst=(1, 0, 0))
    pto.mte_l1_l0a(l1_a.as_ptr(), l0a.as_ptr(), M, K)
    pto.mte_l1_l0b(l1_b.as_ptr(), l0b.as_ptr(), K, N)

    # Compute
    pto.mad(l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), M, N, K)

    # Writeback
    pto.mte_l0c_gm(l0c.as_ptr(), c_ptr, M, N,
                     src_stride=N, dst_stride=N, mode="nz2nd")
```

### 8.2 Split-K GEMM

```python
@ckernel(
    op="pto.mad",
    dtypes=[(pto.f16, pto.f16, pto.f32)],
    name="gemm_splitk",
)
def gemm_splitk(a_tv: PartitionTensorView,   # [M, K]
                b_tv: PartitionTensorView,   # [K, N]
                c_tv: PartitionTensorView,   # [M, N]
                M: int, K: int, N: int, BASEK: int):
    iters = K // BASEK

    a_ptr = a_tv.as_ptr()
    b_ptr = b_tv.as_ptr()
    c_ptr = c_tv.as_ptr()

    l1_a = pto.Tile([M, BASEK], pto.f16, MemorySpace.MAT)
    l1_b = pto.Tile([BASEK, N], pto.f16, MemorySpace.MAT)
    l0a = pto.Tile([M, BASEK], pto.f16, MemorySpace.LEFT)
    l0b = pto.Tile([BASEK, N], pto.f16, MemorySpace.RIGHT)
    l0c = pto.Tile([M, N], pto.f32, MemorySpace.ACC)

    for k_step in range(iters):
        k_off = k_step * BASEK
        a_k = pto.addptr(a_ptr, k_off)
        b_k = pto.addptr(b_ptr, k_off)

        pto.mte_gm_l1(a_k, l1_a.as_ptr(), BASEK, nburst=(1, 0, 0))
        pto.mte_gm_l1(b_k, l1_b.as_ptr(), N, nburst=(1, 0, 0))
        pto.mte_l1_l0a(l1_a.as_ptr(), l0a.as_ptr(), M, BASEK)
        pto.mte_l1_l0b(l1_b.as_ptr(), l0b.as_ptr(), BASEK, N)

        if k_step == 0:
            pto.mad(l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), M, N, BASEK)
        else:
            pto.mad_acc(l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), M, N, BASEK)

    pto.mte_l0c_gm(l0c.as_ptr(), c_ptr, M, N,
                     src_stride=N, dst_stride=N, mode="nz2nd")
```

### 8.3 Matrix Multiplication with Bias

```python
@ckernel(
    op="pto.mad_bias",
    dtypes=[(pto.f16, pto.f16, pto.f32)],
    name="gemm_bias",
)
def gemm_bias(a_tv: PartitionTensorView, b_tv: PartitionTensorView,
              c_tv: PartitionTensorView, bias_tv: PartitionTensorView,
              M: int, K: int, N: int):
    a_ptr = a_tv.as_ptr()
    b_ptr = b_tv.as_ptr()
    c_ptr = c_tv.as_ptr()
    bias_ptr = bias_tv.as_ptr()

    l1_a = pto.Tile([M, K], pto.f16, MemorySpace.MAT)
    l1_b = pto.Tile([K, N], pto.f16, MemorySpace.MAT)
    l1_bias = pto.Tile([1, N], pto.f32, MemorySpace.MAT)
    l0a = pto.Tile([M, K], pto.f16, MemorySpace.LEFT)
    l0b = pto.Tile([K, N], pto.f16, MemorySpace.RIGHT)
    l0c = pto.Tile([M, N], pto.f32, MemorySpace.ACC)
    bt = pto.Tile([1, N], pto.f32, MemorySpace.BIAS)

    pto.mte_gm_l1(a_ptr, l1_a.as_ptr(), K, nburst=(1, 0, 0))
    pto.mte_gm_l1(b_ptr, l1_b.as_ptr(), N, nburst=(1, 0, 0))
    pto.mte_gm_l1(bias_ptr, l1_bias.as_ptr(), N, nburst=(1, 0, 0))
    pto.mte_l1_bt(l1_bias.as_ptr(), bt.as_ptr(), N, nburst=(1, 0, 0))

    pto.mte_l1_l0a(l1_a.as_ptr(), l0a.as_ptr(), M, K)
    pto.mte_l1_l0b(l1_b.as_ptr(), l0b.as_ptr(), K, N)
    pto.mad_bias(l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), bt.as_ptr(), M, N, K)

    pto.mte_l0c_gm(l0c.as_ptr(), c_ptr, M, N,
                     src_stride=N, dst_stride=N, mode="nz2nd")
```

### 8.4 Fractal Load (nd2nz) Example

```python
@ckernel(
    op="pto.mad",
    dtypes=[(pto.f16, pto.f16, pto.f32)],
    name="gemm_frac",
)
def gemm_frac(a_tv: PartitionTensorView, b_tv: PartitionTensorView,
              c_tv: PartitionTensorView, M: int, K: int, N: int):
    a_ptr = a_tv.as_ptr()
    b_ptr = b_tv.as_ptr()
    c_ptr = c_tv.as_ptr()

    l1_a = pto.Tile([M, K], pto.f16, MemorySpace.MAT)
    l1_b = pto.Tile([K, N], pto.f16, MemorySpace.MAT)
    l0a = pto.Tile([M, K], pto.f16, MemorySpace.LEFT)
    l0b = pto.Tile([K, N], pto.f16, MemorySpace.RIGHT)
    l0c = pto.Tile([M, N], pto.f32, MemorySpace.ACC)

    pto.mte_gm_l1_frac(a_ptr, l1_a.as_ptr(), "nd2nz",
                       shape=(M, K),
                       src_layout=(K,),
                       dst_group=(1, 0, 0, 0),
                       ctrl=(0, False))
    pto.mte_gm_l1(b_ptr, l1_b.as_ptr(), N, nburst=(1, 0, 0))

    pto.mte_l1_l0a(l1_a.as_ptr(), l0a.as_ptr(), M, K)
    pto.mte_l1_l0b(l1_b.as_ptr(), l0b.as_ptr(), K, N)
    pto.mad(l0a.as_ptr(), l0b.as_ptr(), l0c.as_ptr(), M, N, K)

    pto.mte_l0c_gm(l0c.as_ptr(), c_ptr, M, N,
                     src_stride=N, dst_stride=N, mode="nz2nd")
```

---

## 9. Lowering Flow

### 9.1 Comparison with Vector DSL

| Stage | Vector DSL | Cube DSL |
|------|-----------|----------|
| AST parsing | `frontend_ast.py` -> `FrontendKernelNode` | Add `FrontendCKernelNode` |
| Semantic analysis | `semantic.py` -> `SemanticKernel` with vecscope analysis | Add Cube semantic analysis with no vecscope and linear IR |
| MLIR emission | `lowering.py` -> MLIR text with `vecscope` blocks | Add Cube lowering with direct linear VPTO IR emission |
| IR attribute | `#pto.kernel_kind<vector>` | `#pto.kernel_kind<cube>` |
| Target march | `dav-c310-vec` | `dav-c310-cube` |

### 9.2 Cube-Specific Issues

1. **No vecscope scope**: A Cube function body is directly a linear IR sequence.
2. **Address-space verification**: Each Cube op has strict address-space requirements on operands.
3. **ptr management**: `.as_ptr()` obtains addresses from Tile/TensorView, and `pto.addptr` pointer offsets must be handled correctly during semantic analysis.
4. **Tile constructor configuration**: `pto.Tile()` automatically infers layout defaults by address space.

---

## 10. Phased Implementation Recommendations

### Phase 1: Minimum Viable Surface (MVP)

- `@ckernel` decorator
- `pto.Tile` constructor plus `.as_ptr()` buffer allocation and pointer retrieval
- `pto.mad` / `pto.mad_acc` / `pto.mad_bias`
- `pto.mte_gm_l1` / `pto.mte_l1_ub`
- `pto.mte_l1_l0a` / `pto.mte_l1_l0b`
- `pto.mte_l0c_gm`
- Basic support for the `pto.tpl()` template slot

### Phase 2: Complete Bridge Surface

- `pto.mad_mx` / `pto.mad_mx_acc` / `pto.mad_mx_bias`
- `pto.mte_gm_l1_frac`
- `pto.mte_l1_bt`
- `pto.mte_l1_l0a_mx` / `pto.mte_l1_l0b_mx`
- `pto.mte_l0c_l1` / `pto.mte_l0c_ub`
- `pto.addptr` pointer offsets

### Phase 3: Advanced Features

- Split-K loop syntax sugar
- Automatic fractal-parameter inference
- Fully automatic layout inference for the Tile constructor
