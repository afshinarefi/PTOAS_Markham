# Semantic Op Design for the `mad` Family

## Goals

Converge `pto.mad*` / `pto.mad_mx*` from "assembled by ISA bit fields" into "semantically self-describing" ops.

Design principles:

- Ops directly express computation semantics
- Factors that affect results must be visible
- Values that can be inferred from types are no longer exposed separately
- Values that cannot be inferred from types must be explicit clauses
- Close over the target profile first, without mixing in profile1 / reserved fields

This discusses the target-profile semantics corresponding to `disa-cube.json`.

## 1. Semantic Sources

### 1.1 Inferred from Pointer Types

The matrix type of `mad` / `mad_mx` should be inferred from pointer element types, instead of carrying a separate `type` parameter.

### 1.2 Must Be Expressed Explicitly

- `unit_flag`
- `disable_gemv`
- `sat` / `nosat`
- `tf32_mode`
- `n_dir`
- `bias`

The initial-value semantics of `C` are not modeled as a separate clause, but are distinguished by the op itself:

- `pto.mad`: zero-init
- `pto.mad_acc`: accumulate-init
- `pto.mad_bias`: bias-init

### 1.3 Constrained by Rules, Not as Independent Operands

- Scale addresses for `mad_mx`
- Alignment / fractal / layout constraints
- GEMV conditions

## 2. Complete Op Set for the `mad` Family

### 2.1 `pto.mad`

```mlir
pto.mad %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  tf32_mode(round_even | round_away)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64
```

Semantics:

```text
dst = lhs * rhs
```

### 2.2 `pto.mad_acc`

```mlir
pto.mad_acc %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  tf32_mode(round_even | round_away)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64
```

Semantics:

```text
dst = dst + lhs * rhs
```

### 2.3 `pto.mad_bias`

```mlir
pto.mad_bias %lhs, %rhs, %dst, %bias, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  tf32_mode(round_even | round_away)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>,
    !pto.ptr<..., bt>, i64, i64, i64
```

Semantics:

```text
dst = bias + lhs * rhs
```

### 2.4 `pto.mad_mx`

```mlir
pto.mad_mx %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64
```

Semantics:

```text
dst = (ScaleA * lhs) * (ScaleB * rhs)
```

Notes:

- `ScaleA` / `ScaleB` are not explicit operands
- They are derived through the `lhs` / `rhs` addresses to `L0A_MX / L0B_MX`
- MX scale storage for `lhs` and `rhs` must already have been loaded externally and aligned with the data tile

### 2.5 `pto.mad_mx_acc`

```mlir
pto.mad_mx_acc %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64
```

Semantics:

```text
dst = dst + (ScaleA * lhs) * (ScaleB * rhs)
```

### 2.6 `pto.mad_mx_bias`

```mlir
pto.mad_mx_bias %lhs, %rhs, %dst, %bias, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>,
    !pto.ptr<..., bt>, i64, i64, i64
```

Semantics:

```text
dst = bias + (ScaleA * lhs) * (ScaleB * rhs)
```

## 3. Raw Op Interface

The semantic `mad` family expands to:

```text
CTRL update + raw MAD/MMAD op
```

Raw ops only carry the underlying MAD/MMAD instruction itself, not `CTRL` semantics.

### 3.1 Raw Op Set

To preserve typed pointer and memory effect information, the raw layer is not directly represented as an all-register `i64, i64, i64, i64` form. Instead, it uses typed pointers plus packed `X_t`:

```mlir
pto.mad_raw %lhs, %rhs, %dst, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64

pto.mad_bias_raw %lhs, %rhs, %dst, %bias, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>,
    !pto.ptr<..., bt>, i64

pto.mad_mx_raw %lhs, %rhs, %dst, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64

pto.mad_mx_bias_raw %lhs, %rhs, %dst, %bias, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>,
    !pto.ptr<..., bt>, i64
```

`mad_acc` and `mad_mx_acc` do not need separate raw ops. They use `pto.mad_raw` / `pto.mad_mx_raw`; the only difference is the `c_init` bit in `%xt`.

### 3.2 Raw Operand Semantics

- `%lhs`: underlying `[X_n]`, Matrix A, must be `left`
- `%rhs`: underlying `[X_m]`, Matrix B, must be `right`
- `%dst`: underlying `[X_d[31:0]]`, Matrix C in L0C, must be `acc`
- `%bias`: underlying `[X_d[63:32]]`, bias table buffer, must be `bias`
- `%xt`: packed `X_t`, type must be `i64`

Raw ops no longer receive:

- `unit_flag(...)`
- `disable_gemv`
- `sat`
- `tf32_mode(...)`
- `n_dir`
- `m / n / k`

All of these must be encoded before semantic-to-raw expansion.

### 3.3 `%xt` Packed Bit Convention

`%xt` is the underlying `X_t`:

- `[11:0]`: M
- `[23:12]`: K
- `[35:24]`: N
- `[56:55]`: unit-flag control bits, legal values `0 / 2 / 3`
- `[61]`: GEMV disable
- `[62]`: C source, `0` means L0C, `1` means bias table
- `[63]`: C init, `1` means the C initial value is 0, `0` means read C

Rules for generating `%xt` from semantic op to raw op:

| semantic op | raw op | `X_t[62] / c_src` | `X_t[63] / c_init` |
|---|---|---:|---:|
| `pto.mad` | `pto.mad_raw` | `0` | `1` |
| `pto.mad_acc` | `pto.mad_raw` | `0` | `0` |
| `pto.mad_bias` | `pto.mad_bias_raw` | `1` | `0` |
| `pto.mad_mx` | `pto.mad_mx_raw` | `0` | `1` |
| `pto.mad_mx_acc` | `pto.mad_mx_raw` | `0` | `0` |
| `pto.mad_mx_bias` | `pto.mad_mx_bias_raw` | `1` | `0` |

### 3.4 What Raw Ops Are Not Responsible For

Raw ops do not configure `SPR.CTRL`. The following semantics must be explicitly inserted by semantic-to-raw expansion through `get_ctrl / sbitset0 / sbitset1 / set_ctrl`:

- `hif8` ptr element type -> `CTRL[45]`
- `tf32_mode(...)` -> `CTRL[46] / CTRL[47]`
- `sat` / `nosat` -> `CTRL[48]`
- `n_dir` -> `CTRL[51]`

Because `hif8 / tf32_mode / n_dir` have explicit off/on semantics, semantic-to-raw must not only set 1 when enabled, but also set 0 when disabled:

- ordinary `fp8_e4m3` -> `CTRL[45] = 0`
- `hif8` -> `CTRL[45] = 1`
- ordinary `f322f32` -> `CTRL[46] = 0`
- `tf32_mode(round_even)` -> `CTRL[46] = 1, CTRL[47] = 0`
- `tf32_mode(round_away)` -> `CTRL[46] = 1, CTRL[47] = 1`
- omitted `n_dir` -> `CTRL[51] = 0`
- written `n_dir` -> `CTRL[51] = 1`

`sat` / `nosat` are still explicit flags: writing `sat` generates saturated-semantics configuration, writing `nosat` generates non-saturated-semantics configuration, and omitting both does not overwrite `CTRL[48]`.

Raw ops are also not responsible for MX scale address organization. `mad_mx_raw` still derives `L0A_MX / L0B_MX` from `lhs / rhs` addresses, and the verifier constrains the scale layout.

### 3.5 Raw Verifier Rules

- Raw ops may not contain any semantic clauses
- `%lhs / %rhs / %dst` must be typed `!pto.ptr`
- The `%lhs` address space must be `left`
- The `%rhs` address space must be `right`
- The `%dst` address space must be `acc`
- For bias raw ops, the `%bias` address space must be `bias`
- For bias raw ops, the `%bias` element type must match the `%dst` element type
- `%xt` must be `i64`
- If `%xt` is a constant:
  - raw non-bias ops require `X_t[62] = 0`
  - raw bias ops require `X_t[62] = 1`
  - `X_t[56:55]` can only be `0 / 2 / 3`

## 4. Type Semantics

### 4.1 Target-Profile Available Types for the `mad` Family

| Family | lhs/rhs | dst | Notes |
|---|---|---|---|
| `s8` | `s8` | `s32` | Inferred from ptr element types |
| `f162f32` | `f16` | `f32` | Inferred from ptr element types |
| `bf162f32` | `bf16` | `f32` | Inferred from ptr element types |
| `f322f32` | `f32` | `f32` | ordinary FP32 can be inferred from ptr element types; TF32 requires explicit `tf32_mode(...)` |
| `e4m3e4m3` | `fp8_e4m3` / `hif8` | `f32` | ordinary FP8 and HiF8 are distinguished by ptr element types |
| `e4m3e5m2` | `fp8_e4m3` / `fp8_e5m2` | `f32` | Inferred from ptr element types |
| `e5m2e4m3` | `fp8_e5m2` / `fp8_e4m3` | `f32` | Inferred from ptr element types |
| `e5m2e5m2` | `fp8_e5m2` | `f32` | Inferred from ptr element types |

`u8`, `s4`, `s16s8`, `f162f16`, `f16u2`, `u8s8`, `b8u2`, and `MMAD_SP` are not included in the target-profile design.

### 4.2 Target-Profile Available Types for the `mad_mx` Family

| Family | lhs/rhs | dst | Notes |
|---|---|---|---|
| `e1m2e1m2` | `fp4_e1m2` | `f32` | Inferred from ptr element types |
| `e1m2e2m1` | `fp4_e1m2` / `fp4_e2m1` | `f32` | Inferred from ptr element types |
| `e2m1e1m2` | `fp4_e2m1` / `fp4_e1m2` | `f32` | Inferred from ptr element types |
| `e2m1e2m1` | `fp4_e2m1` | `f32` | Inferred from ptr element types |
| `e4m3e4m3` | `fp8_e4m3` | `f32` | Inferred from ptr element types |
| `e4m3e5m2` | `fp8_e4m3` / `fp8_e5m2` | `f32` | Inferred from ptr element types |
| `e5m2e4m3` | `fp8_e5m2` / `fp8_e4m3` | `f32` | Inferred from ptr element types |
| `e5m2e5m2` | `fp8_e5m2` | `f32` | Inferred from ptr element types |

## 5. Clause Semantics

### 5.1 `unit_flag(...)`

This is the producer-side L0C block semantics.

- Omitted `unit_flag(...)`: disabled
- `unit_flag(check_only)`: check, do not set
- `unit_flag(check_and_set)`: check and set

`check_and_set` is the corresponding semantic on the `mad` side; the consumer-side `acc_store` uses `check_and_clear`.

### 5.2 `disable_gemv?`

- Omitted: allow GEMV
- Written: disable GEMV

### 5.3 `sat?` / `nosat?`

Represents CUBE saturation/propagation semantics.

- Omitted: preserve the default numeric policy under the target profile
- Written: explicitly request saturate semantics
- Written `nosat`: explicitly request non-saturate semantics

### 5.4 `tf32_mode(...)`

Only appears for execution modes that cannot be inferred from pointer element types:

- `tf32_mode(round_even | round_away)`: only meaningful for `f322f32`

`hif8` is not placed in `tf32_mode(...)`. After an independent HiF8 element type is introduced, `hif8` semantics are inferred from the ptr element types of `lhs / rhs`; ordinary `fp8_e4m3` still means ordinary E4M3 interpretation.

Other families should not carry `tf32_mode(...)`.

### 5.5 `n_dir?`

This is the semantic expression of `CTRL[51]`, used to constrain the direction order of CUBE output to L0C.

- Omitted: `CTRL[51] = 1'b0`, M first then N
- Written `n_dir`: `CTRL[51] = 1'b1`, N first then M

This clause mainly works with later `acc_store*` layout transform / unit-flag semantics and does not change the mathematical result.

## 6. Scale Rules for `mad_mx`

`mad_mx` does not provide scale pointer operands.

Scale is derived from input addresses:

- `lhs` corresponds to `L0A_MX`
- `rhs` corresponds to `L0B_MX`
- The scale base address is derived from the data tile address, in the form `addr / 16`

In other words, `mad_mx` only declares "I want MX semantics" and is not responsible for passing scale addresses as independent data flows.

### 6.1 Constraints

- The scale dtype is fixed to `e8m0`
- For the MX-fp4 family, the data tile is `K0 = 64`, corresponding to a scale tile of `16 x 2`
- For the MX-fp8 family, the data tile is `K0 = 32`, corresponding to a scale tile of `16 x 2`
- Every 32 K elements share one scale
- `L0A_MX / L0B_MX` must be address-aligned with `L0A / L0B`
- The K0 and fractal layout of MX-fp4 / MX-fp8 must satisfy target-profile constraints

## 7. Design Constraints

### 7.1 `mad_bias`

- `bias` must be in the `BIAS` address space
- The `bias` element type must match `dst`

### 7.2 `mad_mx`

- Scale must not be modeled as an independent operand
- Scale must be expressed through derivation rules and verifier constraints

### 7.3 `tf32_mode`

- `f322f32` cannot be expressed by ptr type alone
- It must explicitly carry `tf32_mode(...)`

### 7.4 `hif8`

- `hif8` is expressed by pointer element types, not as an independent clause
- `hif8` is only allowed for the `e4m3e4m3` family
- `lhs / rhs` must both be ordinary `fp8_e4m3` or both be `hif8`; ordinary E4M3 on one side and HiF8 on the other is not allowed

### 7.5 `CTRL` Derived Enums

These are the keywords that the verifier / lowering must fix, without directly exposing bit encodings:

- `unit_flag`
  - `check_only` -> `2'b10`
  - `check_and_set` -> `2'b11`
- `disable_gemv`
  - present -> `X_t[61] = 1'b1`
- `hif8` ptr element type
  - present on both `lhs / rhs` -> `CTRL[45] = 1'b1`
  - absent -> `CTRL[45] = 1'b0`
- `tf32_mode(round_even | round_away)`
  - `round_even` -> `CTRL[46]=1'b1, CTRL[47]=1'b0`
  - `round_away` -> `CTRL[46]=1'b1, CTRL[47]=1'b1`
- `sat` / `nosat`
  - `sat` -> `CTRL[48] = 1'b0`
  - `nosat` -> `CTRL[48] = 1'b1`
- `n_dir`
  - absent -> `CTRL[51] = 1'b0`
  - present -> `CTRL[51] = 1'b1`

### 7.6 `sat` / `nosat`

- `sat` and `nosat` are mutually exclusive explicit semantic switches
- When omitted, preserve the target-profile default behavior
- When written, they mean the user wants to explicitly control saturation semantics instead of relying on implicit conventions

### 7.7 `n_dir`

- `n_dir` only expresses output direction
- It does not change numeric meaning
- It needs to stay consistent with the layout design of `acc_store*`

## 8. Recommended Verifier Rules

### 8.1 General

- `lhs / rhs / dst` must be typed `!pto.ptr`
- `m / n / k` must be integer values convertible to i64
- `unit_flag(...)` can only be `check_only` or `check_and_set`
- `disable_gemv` can only appear as a flag
- `n_dir` can only appear as a flag

### 8.2 `mad_bias`

- `bias` must be in the `BIAS` address space
- The `bias` element type must match `dst`

### 8.3 `mad_mx`

- `lhs` / `rhs` must satisfy the MX family type table
- `dst` must be `f32`
- The derived scale address must match the data tile address
- The scale layout and K0 rules must satisfy MX family constraints

## 9. Target Profile Exclusions

The following are not included in this version of the design:

- `Feature Map Offset` / `fm_offset`
- `Weight Matrix Offset` / `wt_offset`
- `smask_addr`
- `sub_dtype`
- `right_shift_en`
- `MMAD_SP`
- Other reserved / profile1-only fields

## 10. Final Interface Shape

semantic op:

```mlir
pto.mad %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  tf32_mode(round_even | round_away)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64

pto.mad_acc %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  tf32_mode(round_even | round_away)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64

pto.mad_bias %lhs, %rhs, %dst, %bias, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  tf32_mode(round_even | round_away)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, !pto.ptr<..., bt>, i64, i64, i64

pto.mad_mx %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64

pto.mad_mx_acc %lhs, %rhs, %dst, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64, i64, i64

pto.mad_mx_bias %lhs, %rhs, %dst, %bias, %m, %n, %k
  unit_flag(check_only | check_and_set)?
  disable_gemv?
  (sat | nosat)?
  n_dir?
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, !pto.ptr<..., bt>, i64, i64, i64
```

raw op:

```mlir
pto.mad_raw %lhs, %rhs, %dst, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64

pto.mad_bias_raw %lhs, %rhs, %dst, %bias, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, !pto.ptr<..., bt>, i64

pto.mad_mx_raw %lhs, %rhs, %dst, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, i64

pto.mad_mx_bias_raw %lhs, %rhs, %dst, %bias, %xt
  : !pto.ptr<..., l0a>, !pto.ptr<..., l0b>, !pto.ptr<..., l0c>, !pto.ptr<..., bt>, i64
```

The core changes in this design are:

- type is inferred from pointers
- `unit_flag` becomes producer semantics `check_only` / `check_and_set`, without mixing in `check_and_clear`
- `disable_gemv` becomes a flag
- A raw op layer is added, so semantic ops are no longer lowered directly to HIVM intrinsics
- Raw ops only consume typed pointers and packed `%xt`
- `mad_mx` no longer models scale as an independent operand
- `sat`, `tf32_mode(...)`, and `n_dir` are explicit semantic clauses
- `hif8` is inferred from pointer element types, not modeled as an independent clause
