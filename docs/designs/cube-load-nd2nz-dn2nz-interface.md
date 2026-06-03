# `cube_load_nd2nz` / `cube_load_dn2nz` Interface Unification Notes

## 1. Goal

This document does one thing: based on the real A5 usage in `pto-isa`, it organizes the parameter semantics and typical usage scenarios of the lower-level interfaces corresponding to `cube_load_nd2nz` and `cube_load_dn2nz`, and evaluates whether the two can converge to the same upper-level interface model.

This document does not discuss release-document wording or LLVM emitter details. It focuses only on:

- how the lower-level intrinsics are called in `pto-isa`
- what each parameter actually represents in each scenario
- which parameters are naturally common
- which differences need to be preserved as mode distinctions

## 2. Shape of the Lower-Level Interface

In A5 `pto-isa`, both paths eventually go through `TLoadCubeInstr`, then dispatch to lower-level intrinsics:

- `ND` path: `copy_gm_to_cbuf_multi_nd2nz`
- `DN` path: `copy_gm_to_cbuf_multi_dn2nz`

Reference:

- [`include/pto/npu/a5/TLoad.hpp:235`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L235)

The call forms on A5 are basically identical:

```cpp
copy_gm_to_cbuf_multi_*d2nz(dst, src,
    0 /*sid*/,
    loop1SrcStride,
    0 /*l2_cache_ctrl*/,
    nValue,
    dValue,
    loop4SrcStride,
    false /*smallc0_en*/);
```

There are two important facts here:

1. `sid` is fixed to `0` in these `pto-isa` scenarios.
2. The NZ landing structure on the destination side is not fully expressed directly through intrinsic parameters; it is programmed ahead of time through `set_mte2_nz_para(...)`.

In other words, the real semantics come from two parts:

- intrinsic arguments: source-side traversal plus part of the movement shape
- `MTE2_NZ_PARA`: destination-side NZ storage structure

## 3. Unified Parameter View

Although the lower-level names are split into `nd2nz` and `dn2nz`, their real usage in `pto-isa` can first be abstracted into one set of semantic parameters and converged into a unified upper-level interface, `cube_load_frac`.

### 3.1 Intrinsic-Side Parameters

| Unified Name | A5 Lower-Level Field | Semantics |
|---|---|---|
| `src` | `src` | GM source pointer |
| `dst` | `dst` | CBUF/L1 destination pointer |
| `l2_cache_ctrl` | `l2_cache_ctrl` | L2 cache-control configuration bits |
| `src_inner_stride` | `loop1SrcStride` | Stride between innermost repeated units on the source side, in bytes |
| `n_value` | `nValue` | Inner length moved contiguously at a time |
| `d_value` | `dValue` | Size of the dimension packed into the NZ/C0 structure; commonly one of `C`, `K`, or one dimension of `validRow/validCol` |
| `src_outer_stride` | `loop4SrcStride` | Stride between one more outer repeated unit on the source side, in bytes; usually `0` when there is no outer layer |
| `smallc0_en` | `smallc0_mode` | small C0 mode switch; can be enabled only when `D <= 4` |

### 3.2 `MTE2_NZ_PARA`-Side Parameters

In `pto-isa`, the destination-side structure is passed through `set_mte2_nz_para(...)`:

```text
MTE2_NZ_PARA[63:48] = loop4DstStride
MTE2_NZ_PARA[47:32] = loop3DstStride
MTE2_NZ_PARA[31:16] = loop2DstStride
MTE2_NZ_PARA[15:0]  = groupCount
```

The destination `loop2/3/4` stride units are not bytes; they are `C0_size`.

On A5, `C0_size` is a hardware-fixed 32B address unit.
Therefore:

- `dst_loop*_stride = 1` means the destination address advances by `32B`.
- `dst_loop*_stride = 4` means the destination address advances by `128B`.

Note that `C0_size` is fixed at 32B, but the number of elements contained in one `C0` depends on element type size:

| Element Type | Elements per `C0` |
|---|---|
| `i8` / `u8` | `32` |
| `f16` / `i16` | `16` |
| `f32` / `i32` | `8` |

The last 16 bits have different names in different modes:

- In `nd2nz` scenarios they are usually called `ndNum`.
- In `dn2nz` scenarios they are usually called `dnNum`.

From the unified modeling perspective, however, both can essentially be treated as:

- `group_count`: the number of outer groups in the destination-side NZ layout that are processed by hardware at once

Therefore, the destination side can be abstracted uniformly as:

| Unified Name | A5 Lower-Level Field | Semantics |
|---|---|---|
| `group_count` | `MTE2_NZ_PARA[15:0]` | Number of destination groups above the innermost layer; mapped to `ndNum` or `dnNum` in different scenarios |
| `dst_loop2_stride` | `MTE2_NZ_PARA[31:16]` | loop2 stride of the destination NZ structure |
| `dst_loop3_stride` | `MTE2_NZ_PARA[47:32]` | loop3 stride of the destination NZ structure |
| `dst_loop4_stride` | `MTE2_NZ_PARA[63:48]` | loop4 stride of the destination NZ structure |

## 4. Real `nd2nz` Usage Scenarios

### 4.1 Scenario A: `MX_A_ND -> ZZ`

Corresponding `pto-isa`:

- `TLoadMxCubeADN2ZZ`
- [`include/pto/npu/a5/TLoad.hpp:723`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L723)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `n_value` | `validCol >> 1` | Column-direction length moved each time |
| `d_value` | `validRow` | Row-direction length moved each time |
| `src_inner_stride` | `GetByteSize(dtype, gStride4) * sizeof(uint16_t)` | Stride between adjacent inner source fragments |
| `src_outer_stride` | `0` | No further outer source repetition in this scenario |
| `group_count` | `1` | Single group |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `TileData::Cols >> 1` | NZ-layout stride in the destination column direction |
| `dst_loop4_stride` | `0` | No further outer destination repetition |

This scenario essentially means:

- The source is traversed in ND style.
- The destination writes into the ZZ-style NZ layout used by the left matrix.

### 4.2 Scenario B: `MX_B_ND -> NN`

Corresponding `pto-isa`:

- `TLoadMxCubeBND2NN`
- [`include/pto/npu/a5/TLoad.hpp:744`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L744)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `n_value` | `validRow >> 1` | Row-direction length moved each time |
| `d_value` | `validCol` | Column-direction length moved each time |
| `src_inner_stride` | `GetByteSize(dtype, gStride3) * sizeof(uint16_t)` | Stride between adjacent inner source fragments |
| `src_outer_stride` | `0` | No further outer source repetition |
| `group_count` | `1` | Single group |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `TileData::Rows >> 1` | NZ-layout stride in the destination row direction |
| `dst_loop4_stride` | `0` | No further outer destination repetition |

This scenario is mostly isomorphic to the previous one; only the `A/B` left/right matrix semantics differ, which changes the mapping of `n_value` / `d_value` and destination stride.

### 4.3 Scenario C: Generic `ND -> [N,C1,H,W,C0]`

Corresponding `pto-isa`:

- Generic path from ND to convolution tile
- [`include/pto/npu/a5/TLoad.hpp:1000`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L1000)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `group_count` | `srcShape2` | This is `ndNum = H` |
| `n_value` | `srcShape3` | This is `W` |
| `d_value` | `srcShape4` | This is `C` |
| `src_inner_stride` | `bytes(gStride3)` | Stride between adjacent row groups along W |
| `src_outer_stride` | `bytes(gStride2)` | Stride between adjacent groups along H |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `dstShape2 * dstShape3` | Destination `H*W` group stride |
| `dst_loop4_stride` | `dstShape3` | Destination W stride |

This scenario best shows the commonality of `nd2nz`:

- `group_count` really represents an outer ND group count.
- `src_outer_stride` is truly meaningful here and cannot be omitted in every scenario.

## 5. Real `dn2nz` Usage Scenarios

### 5.1 Scenario A: `MX_A_DN -> ZZ`

Corresponding `pto-isa`:

- `TLoadMxCubeAND2ZZ`
- [`include/pto/npu/a5/TLoad.hpp:664`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L664)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `n_value` | `validCol >> 1` | Column-direction length moved each time |
| `d_value` | `validRow` | Row-direction length moved each time |
| `src_inner_stride` | `bytes(gStride3)` | Stride between adjacent inner source fragments |
| `src_outer_stride` | `0` | No further outer source repetition |
| `group_count` | `1` | This is `dnNum = 1` |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `TileData::Cols >> 1` | NZ-layout stride in the destination column direction |
| `dst_loop4_stride` | `0` | No further outer destination repetition |

### 5.2 Scenario B: `MX_B_DN -> NN`

Corresponding `pto-isa`:

- `TLoadMxCubeBDN2NN`
- [`include/pto/npu/a5/TLoad.hpp:765`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L765)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `n_value` | `validRow >> 1` | Row-direction length moved each time |
| `d_value` | `validCol` | Column-direction length moved each time |
| `src_inner_stride` | `bytes(gStride4)` | Stride between adjacent inner source fragments |
| `src_outer_stride` | `0` | No further outer source repetition |
| `group_count` | `1` | Single group |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `TileData::Rows >> 1` | NZ-layout stride in the destination row direction |
| `dst_loop4_stride` | `0` | No further outer destination repetition |

### 5.3 Scenario C: `NCHW -> [N,C1,H,W,C0]`

Corresponding `pto-isa`:

- `TLoadNCHW`
- [`include/pto/npu/a5/TLoad.hpp:1027`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L1027)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `group_count` | `1` | Here `dnNum = 1` is fixed |
| `n_value` | `srcW` or `srcH * srcW` | Inner movement unit; if W is contiguous, this can be combined into `H*W` |
| `d_value` | `srcC` | Number of channels packed into `C0` |
| `src_inner_stride` | `bytes(gStride2)` | Source stride corresponding to adjacent `C` fragments |
| `src_outer_stride` | `0` | The outer loop for this path is usually expanded in software outside the intrinsic |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `dstH * dstW` | Destination HW group stride |
| `dst_loop4_stride` | `dstW` | Destination W stride |

Characteristics of `dn2nz` here:

- `group_count` is often not a large dimension such as `H` / `D`.
- Outer repetitions over `H` or `N` are often wrapped by an outer `for` loop rather than put into the intrinsic.

### 5.4 Scenario D: `NCDHW -> [N,D,C1,H,W,C0]`

Corresponding `pto-isa`:

- `TLoadNCDHW2NDC1HWC0`
- [`include/pto/npu/a5/TLoad.hpp:1128`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L1128)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `group_count` | `1` | Here `dnNum = 1` is fixed |
| `n_value` | `srcH * srcW` or degraded to `srcW` | Whether H/W are contiguous determines the inner movement length |
| `d_value` | `srcC` | Number of channels packed into `C0` |
| `src_inner_stride` | `bytes(gStride1)` | Source stride for adjacent `C` fragments |
| `src_outer_stride` | `0` | Outer repetitions over `D` / `H` are usually handled by external loops |
| `dst_loop2_stride` | `1` | Fixed |
| `dst_loop3_stride` | `dstH * dstW` | Destination HW group stride |
| `dst_loop4_stride` | `dstW` | Destination W stride |

### 5.5 Scenario E: `NCHW -> FractalZ`

Corresponding `pto-isa`:

- `TLoadNCHW2FractalZ`
- [`include/pto/npu/a5/TLoad.hpp:1085`](../../../../gitlab.com/cann/pto-isa/include/pto/npu/a5/TLoad.hpp#L1085)

Parameter mapping:

| Parameter | Value | Meaning |
|---|---|---|
| `group_count` | `srcShape1` | Here `dnNum = N` |
| `n_value` | `gStride2` | Move the whole `H*W` at once |
| `d_value` | `srcShape2` | This is `C` |
| `src_inner_stride` | `bytes(gStride2)` | Source stride for one `N` group |
| `src_outer_stride` | `bytes(gStride1)` | Stride between adjacent outer groups |
| `dst_loop2_stride` | `dstShape1 * dstShape2` | Destination loop2 stride |
| `dst_loop3_stride` | `loop2DstStride * dstHW` | Destination loop3 stride |
| `dst_loop4_stride` | `1` | Contiguous storage |

This scenario shows:

- `dn2nz` is not limited to `group_count = 1`.
- `src_outer_stride` is also not an invalid parameter exclusive to `dn2nz`.

## 6. Comparison Conclusion

From real `pto-isa` usage, the difference between `nd2nz` and `dn2nz` is not "different parameter kinds"; it is "different source-layout traversal semantics for the same set of parameters".

Common points:

- Both need `src_inner_stride`.
- Both need `n_value`.
- Both need `d_value`.
- Both may need `src_outer_stride`.
- Both need destination-side `group_count / dst_loop2_stride / dst_loop3_stride / dst_loop4_stride`.
- Both are often used with outer software loops.

Core differences:

- In `nd2nz`, `group_count` is more like an ND group count; in `dn2nz`, it is more like a DN group count.
- Which source-tensor dimension maps to `n_value` / `d_value` / `src_inner_stride` depends on the source layout mode.
- Some `dn2nz` scenarios split outer dimensions such as `H` / `D` into software loops instead of putting them into `group_count`.

Therefore, if we look only at the parameter list, the two interfaces can be unified. The differences that truly need to be preserved are:

- an explicit `nd2nz | dn2nz` mode keyword
- each mode's own shape-to-parameter mapping rules

## 7. Minimal Movement Example

This section uses a minimal example to show how these parameters drive the movement process from "multiple groups of 2D matrices" to "multiple groups of NZ fractals".

Assume:

- `group_count = 2`
- `n_value = 3`
- `d_value = 5`
- `src_inner_stride = 32B`
- `src_outer_stride = 256B`
- `dst_loop2_stride = 1`
- `dst_loop3_stride = 4`
- `dst_loop4_stride = 20`

The source can be understood as two logical 2D matrix groups, each with `N x D = 3 x 5`.

### 7.1 Source-Side View

First ignore the address-interpretation difference between `nd2nz` and `dn2nz`; only look at the unified abstraction of "groups plus inner stride":

```text
group 0 base = src + 0 * src_outer_stride
group 1 base = src + 1 * src_outer_stride

group g contains 3 N units:

N0 base = group_base + 0 * src_inner_stride
N1 base = group_base + 1 * src_inner_stride
N2 base = group_base + 2 * src_inner_stride

Each N unit contains D=5 elements:

N0: [d0 d1 d2 d3 d4]
N1: [d0 d1 d2 d3 d4]
N2: [d0 d1 d2 d3 d4]
```

Drawn as two source matrix groups:

```text
group 0:
  N0 -> [00 01 02 03 04]
  N1 -> [10 11 12 13 14]
  N2 -> [20 21 22 23 24]

group 1:
  N0 -> [30 31 32 33 34]
  N1 -> [40 41 42 43 44]
  N2 -> [50 51 52 53 54]
```

Here:

- `src_inner_stride` decides how to step from `N0 -> N1 -> N2`.
- `src_outer_stride` decides how to step from `group 0 -> group 1`.
- `n_value = 3` decides that each group takes 3 N lines.
- `d_value = 5` decides that each N line takes 5 D elements.

### 7.2 Destination NZ View

The destination is not flattened into an ordinary 2D matrix; it is laid out into L1 as an NZ fractal.

It can first be abstracted as:

```text
destination base for group g = dst + g * dst_loop4_stride * C0_size

inside the group:
  destination base for D-block i = group_dst_base + i * dst_loop3_stride * C0_size
  destination base for N unit j = d_block_dst_base + j * dst_loop2_stride * C0_size
```

In this example:

- `dst_loop2_stride = 1` means adjacent N units are placed contiguously in the destination.
- `dst_loop3_stride = 4` means adjacent D-blocks are separated by 4 `C0_size` units.
- `dst_loop4_stride = 20` means adjacent groups' whole matrices are separated by 20 `C0_size` units in the destination.

If we draw only logical landing relationships without expanding the full `C0`, it looks like:

```text
group 0 NZ:
  D-block 0:
    N0 <- [00 01 02 03 ...]
    N1 <- [10 11 12 13 ...]
    N2 <- [20 21 22 23 ...]
  D-block 1:
    N0 <- [04 pad pad pad ...]
    N1 <- [14 pad pad pad ...]
    N2 <- [24 pad pad pad ...]

group 1 NZ:
  D-block 0:
    N0 <- [30 31 32 33 ...]
    N1 <- [40 41 42 43 ...]
    N2 <- [50 51 52 53 ...]
  D-block 1:
    N0 <- [34 pad pad pad ...]
    N1 <- [44 pad pad pad ...]
    N2 <- [54 pad pad pad ...]
```

`d_value = 5` is chosen deliberately to expose tail-block behavior:

- The first block holds the first 4 D elements.
- The second block has only the 5th element left.
- The tail is padded by hardware.

### 7.3 What Each Parameter Controls

Compressed into one sentence:

- `n_value` decides how many N lines each group moves.
- `d_value` decides how many D elements on each N line are packed into the fractal.
- `src_inner_stride` decides how adjacent N lines are stepped through on the source.
- `src_outer_stride` decides how adjacent matrix groups are stepped through on the source.
- `dst_loop2_stride` decides how adjacent N lines are placed on the destination.
- `dst_loop3_stride` decides how adjacent D-blocks are placed on the destination.
- `dst_loop4_stride` decides how adjacent groups are placed on the destination.

### 7.4 The Real Difference Between `nd2nz` and `dn2nz`

The diagram above intentionally shows only the unified abstraction, because the parameter framework itself is the same for both instructions.

The real difference is the source-side address interpretation order.

- `nd2nz`: more like treating the source as an ND matrix, then reading by `N x D` logic.
- `dn2nz`: more like treating the source as a DN matrix, then reading by another source-address recurrence order.

But in either case:

- `n_value` / `d_value` still define "how large this group movement is".
- `src_inner_stride` / `src_outer_stride` still define "how to walk the source".
- `dst_loop2/3/4_stride` still define "where the NZ fractal lands".

Therefore, from the upper-level interface perspective, they can fully share the same parameter model and differ only in `mode`, which selects the source-layout interpretation rule.

## 8. Recommended Unified Abstraction

If the upper layer wants a unified interface, first unify it at the "parameter semantic layer" rather than forcibly reusing existing lower-level names.

One possible unified abstraction is:

```text
cube_load_frac(
  src,
  dst,
  nd2nz | dn2nz,
  shape(n_value, d_value),
  src_layout(src_inner_stride, src_outer_stride?),
  dst_group(group_count, dst_loop2_stride, dst_loop3_stride, dst_loop4_stride),
  ctrl(l2_cache_ctrl, smallc0_en)
)
```

Where:

- `shape(...)` describes only the logical `N x D` size of one fractal movement.
- `src_layout(...)` describes only source-side address recurrence.
- `dst_group(...)` describes only destination NZ fractal layout.
- `ctrl(...)` describes only lower-level control bits.

If `src_outer_stride` is not provided, treat it as `0` by default.

Benefits of this abstraction:

- `nd2nz` / `dn2nz` share the same structured parameters.
- Whether the lower layer uses `copy_gm_to_cbuf_multi_nd2nz` or `copy_gm_to_cbuf_multi_dn2nz` is decided by `mode`.
- The four `MTE2_NZ_PARA` fields can be preserved as-is, with no need for implicit inference.

This kind of interface does not expose a separate `padding` parameter.

- When `d_value` cannot fully fill the destination fractal, tail padding is completed by hardware as zero padding.
- When `smallc0_en = true`, small C0 mode changes padding and alignment behavior, but it still is not a user-configurable pad value.

Therefore, the padding semantics here are built-in instruction behavior, not an explicit interface parameter like in `dma_load`.

If written directly as a VPTO-like syntax draft, it could be:

```text
pto.mte_gm_l1_frac %src, %dst,
    nd2nz | dn2nz,
    shape(%n_value, %d_value),
    src_layout(%src_inner_stride[, %src_outer_stride]),
    dst_group(%group_count, %dst_loop2_stride, %dst_loop3_stride, %dst_loop4_stride),
    ctrl(%l2_cache_ctrl, %smallc0_en)
  : !pto.ptr<..., gm>, !pto.ptr<..., l1>,
    nd2nz | dn2nz,
    shape i64, i64,
    src_layout(i64[, i64]),
    dst_group i64, i64, i64, i64,
    ctrl i64, i1
```

The recommended builder view should stay consistent with the syntax:

```text
cube_load_frac(
  src, dst,
  mode,
  shape(n_value, d_value),
  src_layout(src_inner_stride, src_outer_stride = 0),
  dst_group(group_count, dst_loop2_stride, dst_loop3_stride, dst_loop4_stride),
  ctrl(l2_cache_ctrl, smallc0_en)
)
```

## 9. Which Parameters Can Default and Which Should Be Explicit

Based on the current `pto-isa` status:

### 9.1 Can Default

- `sid = 0`

`sid` is fixed at every investigated A5 `pto-isa` usage point.

### 9.2 Recommended to Expose Explicitly

- `mode`
- `shape(n_value, d_value)`
- `src_layout(src_inner_stride, src_outer_stride?)`
- `dst_group(group_count, dst_loop2_stride, dst_loop3_stride, dst_loop4_stride)`
- `ctrl(l2_cache_ctrl, smallc0_en)`

These all truly exist in the lower-level interface and affect behavior or future extension space. In particular:

- `l2_cache_ctrl` is currently passed as `0` in A5 `pto-isa` usage.
- `smallc0_en` is currently passed as `false` in A5 `pto-isa` usage.
- But according to `disa-cube.json`, both fields are part of the original interface semantics and should not simply disappear from the unified interface.

### 9.3 Optional Exposure

- `src_outer_stride`

This parameter is not needed in every scenario, but once a generic interface is built, it is better to preserve it.
In the structured interface, `src_outer_stride` still belongs to `src_layout(...)`; it is only allowed to be omitted.

## 10. Preliminary Judgment

The conclusion is direct:

- `cube_load_nd2nz` and `cube_load_dn2nz` can be unified at the parameter semantic layer.
- The part that cannot be unified away is not the parameter list, but the interpretation of source-layout traversal rules by `mode`.
- If a new VPTO interface is added later, it should be abstracted as one unified `cube_load_frac` interface while preserving the two mode keywords `nd2nz | dn2nz`.
- This unified interface is better expressed with structured groups:
  - `shape(...)`
  - `src_layout(...)`
  - `dst_group(...)`
  - `ctrl(...)`
- In this unified interface, `l2_cache_ctrl` and `smallc0_en` should remain explicit parameters; only `sid` can continue to be fixed and hidden.

If a next step is needed, this design document can be advanced one level further into a VPTO-op-oriented syntax draft and verifier constraints.
