# `pto.tcvt` TileLib Template Library Design and Work Items

## 1. Goal

Use the existing `TCVT_IMPL` implementation in `pto-isa` on A5 as the reference, and complete the `pto.tcvt` template library in TileLib with the TileLang DSL.

The current PTOAS `pto.tcvt` explicitly carries only `rmode`; it does not expose a separate `sat_mode`. Therefore, the template library cannot simply forward one layer of parameters. Instead, it must reproduce A5's default `sat_mode` selection internally based on `(src_dtype, dst_dtype)`, then route each type pair to the correct VPTO path.


## 2. Current Semantics

### 2.1 PTOAS Side

The current PTOAS `pto.tcvt` has only the `rmode` attribute and no `sat_mode` attribute.

This means the only static information passed from PTOAS to TileLib is the round mode. The template library must fill in the default saturation policy itself.

### 2.2 A5 `pto-isa` Side

The A5 side already has several `TCVT_IMPL` overloads, including:

- `TCVT_IMPL(dst, src, mode)`
- `TCVT_IMPL(dst, src, mode, satMode)`
- `TCVT_IMPL(dst, src, tmp, mode)`
- `TCVT_IMPL(dst, src, tmp, mode, satMode)`

On A5, `TCVT_IMPL(dst, src, tmp, mode)` only redirects to the version without `tmp`; `tmp` itself does not participate in the implementation. `tmp` is kept here mainly to remain compatible with the A2/A3 interface shape.

If we focus only on the entry that the current `pto.tcvt` really needs to align with:

```cpp
TCVT_IMPL(dst, src, mode)
```

then the main flow inside A5 `pto-isa` can be summarized as this chain:

1. First select the default `satMode` by `(src_dtype, dst_dtype)`.
   In other words, this entry itself first performs type dispatch and maps the current type pair to the default
   `satMode=ON` or `OFF`.

2. Then redirect to the main implementation entry with explicit `satMode`.

```cpp
TCVT_IMPL(dst, src, mode, satMode)
```

3. In the explicit `satMode` entry, first compute which CTRL bits need to be set for `(src_dtype, dst_dtype, satMode)`.
   This calls `determineSaturationCtrlBits(...)`, then calls
   `applySaturationCtrlBits(...)` to write those CTRL bits.

4. After the CTRL bits are set, perform another switch dispatch on `round_mode`.
   For example, dispatch to `RoundRType` / `RoundAType` / `RoundFType` / `RoundCType` /
   `RoundZType` / `RoundOType`, and finally call:

```cpp
implTCVT<TileDataD, TileDataS, RoundXType>(...)
```

5. Inside `implTCVT(...)`, dispatch by type pair again to the concrete helper.
   For example:
   - `cast32to32`
   - `cast32to16`
   - `cast16to32`
   - `cast16to16`
   - `cast16to8`
   - and the dedicated `NonSatTorch` helpers

6. Finally restore the CTRL bits that were modified earlier.
   That is, call `restoreSaturationCtrlBits(...)` at the end of the main implementation entry.

Compressed into one line of implementation flow, this is:

```text
TCVT_IMPL(dst, src, mode)
  -> select the default satMode by type pair
  -> TCVT_IMPL(dst, src, mode, satMode)
       -> determineSaturationCtrlBits(...)
       -> applySaturationCtrlBits(...)
       -> switch(round_mode)
            -> implTCVT<RoundXType>(...)
                 -> cast helper / NonSatTorch helper
       -> restoreSaturationCtrlBits(...)
```

For TileLib, this framework is what really needs to be reproduced. The implementation should not stop at directly forwarding `rmode` to some
`vcvt`.

Therefore, for current A5, the true semantics that `pto.tcvt` needs to align with are:

1. The external interface explicitly provides only `rmode`.
2. The library internally selects the default `sat_mode` by type pair.
3. It then enters the concrete implementation path based on the type pair and `sat_mode`.

## 3. A5 Implementation Points

### 3.1 Default `sat_mode`

A5's round-only `TCVT_IMPL(dst, src, mode)` uses `sat_mode=OFF` by default for the following type pairs:

| Source Type | Destination Type | Default `sat_mode` | Description |
|---|---|---|---|
| `f16` | `u8` | `OFF` | Existing A5 default behavior |
| `f16` | `i8` | `OFF` | Existing A5 default behavior |
| `f32` | `i16` | `OFF` | Existing A5 default behavior |
| `f16` | `i16` | `OFF` | Existing A5 default behavior |
| `i64` | `i32` | `OFF` | Existing A5 default behavior |
| `i32` | `i16` | `OFF` | Existing A5 default behavior |

All type pairs outside the table above use `sat_mode=ON` by default.

This part of the rule should be reproduced directly inside the TileLib template and should not depend on PTOAS passing an extra parameter.

### 3.2 Overall A5 `TCVT` Support Table

Classify by three implementation dimensions:

- Whether it is affected by `round_mode`
- Whether it is affected by `sat_mode`
- Whether `NonSatTorch` alignment is needed

This table is organized from `pto-isa/include/pto/npu/a5/TCvt.hpp`; it does not mean that the current
PTOAS + TileLib path has already enabled everything.

The last column, `TileLib Support`, in each table below follows the actual implementation in
`PTOAS/lib/TileOps/tcvt_template.py`. Currently enabled paths are marked `Supported`;
the rest are temporarily left blank.

#### 3.2.1 Not affected by `round_mode` or `sat_mode`, and does not require `NonSatTorch`

This group is the best fit for priority implementation. Most paths are expand / unpack paths.

| Source Type | Destination Type | A5 Helper Coverage | Notes | TileLib Support |
|---|---|---|---|---|
| `f16` | `f32` | 1D+2D, `vcvt + part` | type expand | `Supported` |
| `bf16` | `f32` | 1D+2D, `vcvt + part` | type expand | `Supported` |
| `i16` | `f32` / `i32` / `u32` | 1D+2D, expand helper | widening path | `Supported` |
| `i32` | `i64` | 1D+2D, expand helper | | `Supported` |
| `u8` | `f16` / `u16` | 1D only, expand helper | Currently only a 1D helper has been found | `Supported` |
| `i8` | `f16` / `i16` / `i32` | 1D only, expand helper | Currently only a 1D helper has been found | `Supported` |
| `fp8_e4m3` / `fp8_e5m2` / `h8` | `f32` | 1D+2D, expand helper | source 8-bit float | |
| `fp4_e1m2x2` / `fp4_e2m1x2` | `bf16` | 1D+2D, dedicated unpack helper | 4-bit packed source | |

#### 3.2.2 Affected by `round_mode`, not affected by `sat_mode`, and does not require `NonSatTorch`

This group belongs to the round-only path.

| Source Type | Destination Type | A5 Helper Coverage | Notes | TileLib Support |
|---|---|---|---|---|
| `f32` | `f32` | 1D+2D, `vtrc` | Keep `f32` and perform integer-valued float rounding | `Supported` |
| `f16` | `i32` | 1D+2D, `vcvt + part` | | `Supported` |
| `i16` | `f16` | 1D+2D, `vcvt` | | `Supported` |
| `i32` | `f32` | 1D+2D, `vcvt` | | `Supported` |
| `i64` | `f32` | 1D+2D, `vcvt + part` | | `Supported` |
| `bf16` | `fp4_e1m2x2` / `fp4_e2m1x2` | 1D+2D, dedicated packed helper | Not an ordinary `vcvt` package, but does not consume `sat_mode` | |

#### 3.2.3 Not affected by `round_mode`, affected by `sat_mode`, and does not require `NonSatTorch`

This group is mainly integer narrowing.

| Source Type | Destination Type | A5 Helper Coverage | Default `effective_sat_mode` | Notes | TileLib Support |
|---|---|---|---|---|---|
| `i16` | `u8` | 1D+2D, `vcvt + part` | `ON` | | `Supported` |
| `i32` | `i16` | 1D+2D, `vcvt + part` | `OFF` | | `Supported` |
| `i32` | `u16` / `u8` | 1D+2D, `vcvt + part` | `ON` | | `Supported` |
| `u32` | `i16` / `u16` / `u8` | 1D+2D, `vcvt + part` | `ON` | | `Supported` |
| `i64` | `i32` | 1D+2D, `vcvt + part` | `OFF` | | `Supported` |

#### 3.2.4 Affected by both `round_mode` and `sat_mode`, but does not require `NonSatTorch`

This group is the regular `tcvt` main path. The currently enabled `f32 -> i32` path belongs to this category.

| Source Type | Destination Type | A5 Helper Coverage | Default `effective_sat_mode` | Notes | TileLib Support |
|---|---|---|---|---|---|
| `f32` | `f16` / `bf16` | 1D+2D, `vcvt + part` | `ON` | narrowing float | `Supported` |
| `f32` | `i32` | 1D+2D, `vcvt` | `ON` | This regular path has already been enabled first | `Supported` |
| `f32` | `i64` | 1D+2D, `vcvt + part` | `ON` | | `Supported` |
| `f32` | `fp8_e4m3` / `fp8_e5m2` | 1D+2D, `vcvt + part` | `ON` | | |
| `f16` | `u8` | 1D+2D, `vcvt + part` | `OFF` | | `Supported` |
| `bf16` | `i32` | 1D+2D, `vcvt + part` | `ON` | | `Supported` |
| `bf16` | `f16` | 1D+2D, `vcvt` | `ON` | The helper internally uses `SAT_ROUND` order | `Supported` |

#### 3.2.5 Affected by both `round_mode` and `sat_mode`, and requires `NonSatTorch`

This group needs to be closed separately later. These paths cannot be directly treated as ordinary `vcvt(..., sat=NOSAT)` equivalents.

| Source Type | Destination Type | A5 Helper Coverage | Default `effective_sat_mode` | `NonSatTorch` | Notes | TileLib Support |
|---|---|---|---|---|---|---|
| `f32` | `i16` | 1D+2D, `vcvt + part` | `OFF` | Yes | Uses `NonSatTorch` when `OFF` | `Supported` |
| `f16` | `i16` | 1D+2D, `vcvt` | `OFF` | Yes | | `Supported` |
| `f16` | `i8` | 1D+2D, `vcvt + part` | `OFF` | Yes | | `Supported` |

#### 3.2.6 Dedicated helpers with restricted `round_mode`

This group is not recommended for the first batch together with ordinary paths. Although the A5 helper formally carries template parameters, the current implementation is effectively fixed to a specific rounding behavior.

| Source Type | Destination Type | A5 Helper Coverage | Default `effective_sat_mode` | Notes | TileLib Support |
|---|---|---|---|---|---|
| `f32` | `h8` | 1D+2D, dedicated helper | `ON` | The helper is effectively fixed to `ROUND_A` | |
| `f16` | `h8` | 1D+2D, dedicated helper | `ON` | The helper is effectively fixed to `ROUND_A` | |

Record three more points here:

- `f16 -> fp8_e4m3/e5m2` is explicitly not implemented in current A5 `pto-isa`; the `f16` side only provides the dedicated `h8` helper.
- Paths such as `h8` and `fp4` are not ordinary `vcvt` packages. When implementing TileLib later, they are not recommended to be mixed into the first batch with the regular `f32/f16/bf16/int` main path.
- "Affected / not affected by `round_mode`" here means whether the A5 helper for that pair actually consumes rounding semantics, not whether the PTOAS layer can obtain `rmode`.

### 3.3 `round_mode` Mapping Table

In the current `pto.tcvt` chain, round mode passes through at least four layers of names:

1. PTOAS op attr: `#pto<round_mode ...>`
2. The context string passed from `ExpandTileOp` to TileLang: `round_mode`
3. TileLang DSL frontend: `pto.VcvtRoundMode.*`
4. VPTO / A5 lowering: tokens such as `rnd = "R"`, or `RoundMode::CAST_*`

The documentation and implementation should use the following table consistently and should not use different aliases in different layers.

| PTOAS `rmode` | Value Passed by `ExpandTileOp` | DSL Frontend | VPTO Token | A5 / EmitC | Semantics |
|---|---|---|---|---|---|
| `NONE` | `RINT` | `pto.VcvtRoundMode.R` | `R` / `ROUND_R` | `RoundMode::CAST_RINT` | round to nearest, ties to even |
| `RINT` | `RINT` | `pto.VcvtRoundMode.R` | `R` / `ROUND_R` | `RoundMode::CAST_RINT` | round to nearest, ties to even |
| `CAST_RINT` | `RINT` | `pto.VcvtRoundMode.R` | `R` / `ROUND_R` | `RoundMode::CAST_RINT` | round to nearest, ties to even |
| `ROUND` | `ROUND` | `pto.VcvtRoundMode.A` | `A` / `ROUND_A` | `RoundMode::CAST_ROUND` | round away from zero |
| `FLOOR` | `FLOOR` | `pto.VcvtRoundMode.F` | `F` / `ROUND_F` | `RoundMode::CAST_FLOOR` | round toward negative infinity |
| `CEIL` | `CEIL` | `pto.VcvtRoundMode.C` | `C` / `ROUND_C` | `RoundMode::CAST_CEIL` | round toward positive infinity |
| `TRUNC` | `TRUNC` | `pto.VcvtRoundMode.Z` | `Z` / `ROUND_Z` | `RoundMode::CAST_TRUNC` | round toward zero |
| `ODD` | `ODD` | `pto.VcvtRoundMode.O` | `O` / `ROUND_O` | `RoundMode::CAST_ODD` | round to odd |

Add three implementation points to watch:

- `ExpandTileOp` should currently normalize `NONE` / `RINT` / `CAST_RINT` into `RINT`, so the template only needs to handle one default round-to-nearest semantic.
- The description of `ROUND` in `PTO_IR_manual` is somewhat stale. The current implementation and VPTO specification should interpret it as "away from zero".
- The `f32 -> f32` `vtrc` path cannot directly copy all tokens in the table above. The current VPTO `vtrc` specification explicitly lists only `R/A/F/C/Z`; `ODD` needs separate target-semantics review and should not be assumed to be fully equivalent to `vcvt`.

### 3.4 Handling Paths for Different Type Pairs

From the template implementation perspective, the more important question is not how A5 cuts CTRL bits internally, but which path each type pair should eventually take. TileLib logic should be organized according to the following table:

| Type Pair | Default Path | Notes |
|---|---|---|
| `f32 -> f32` | `vtrc` | This is round-to-int-valued-float and should not use `vcvt` |
| `f32 -> i16` with `sat_mode=OFF` | `NonSatTorch` helper | Must align with existing A5 boundary-value behavior |
| `f16 -> i16` with `sat_mode=OFF` | `NonSatTorch` helper | Must align with existing A5 boundary-value behavior |
| `f16 -> i8` with `sat_mode=OFF` | `NonSatTorch` helper | Must align with existing A5 boundary-value behavior |
| Other legal type pairs | `vcvt` | The exact attrs depend on the VPTO contract |

These three `NonSatTorch` paths cannot be simply treated as ordinary `vcvt(..., sat=NOSAT)` equivalents. A5 keeps dedicated implementations here to align the current behavior on boundary values such as `inf`, `nan`, and `overflow`.

### 3.5 `vcvt` Attr Constraints

Even after the TileLib side has inferred `sat_mode`, it still cannot unconditionally pass `rnd/sat/part` to `vcvt`. Whether these attrs should appear must still follow the VPTO `vcvt` verifier constraints.

Here are several typical paths that the template will definitely encounter:

| Type Pair | `rnd` | `sat` | `part` | Suggested Path |
|---|---|---|---|---|
| `f32 -> i32` | required | required | not required | `vcvt` |
| `i32 -> f32` | required | not required | not required | `vcvt` |
| `f32 -> f16/bf16` | required | required | required | `vcvt` |
| `f16/bf16 -> f32` | not required | not required | required | `vcvt` |
| `f32 -> f32` | not applicable | not applicable | not applicable | `vtrc` |

Therefore, the template should preferably split "default `sat_mode` inference" and "`vcvt` attr organization" into two layers instead of mixing them together.

## 4. TileLib Design Recommendations

### 4.1 Main Template Flow

The `pto.tcvt` template in TileLib should keep the following structure:

```python
@pto.vkernel(target="a5", op="pto.tcvt")
def template_tcvt(src: pto.Tile, dst: pto.Tile):
    src_dtype = src.element_type
    dst_dtype = dst.element_type

    round_mode = pto.get_op_attr("round_mode", "RINT")
    sat_mode = _a5_default_tcvt_sat_mode(src_dtype, dst_dtype)

    if _needs_nonsat_torch(src_dtype, dst_dtype, sat_mode):
        return _emit_nonsat_torch_tcvt(src, dst, round_mode)

    return _emit_regular_tcvt(src, dst, round_mode, sat_mode)
```

The logic should be split into three internal helpers:

- `_a5_default_tcvt_sat_mode(src_dtype, dst_dtype)`
- `_needs_nonsat_torch(src_dtype, dst_dtype, sat_mode)`
- `_emit_regular_tcvt(...)`

This makes it easier to align with the existing A5 `pto-isa` rules and also makes later unit testing easier.

### 4.2 Dispatch Principles for the Regular Path

`_emit_regular_tcvt(...)` should preferably do only two things:

1. Decide whether the current type pair should use `vtrc` or `vcvt`.
2. If it uses `vcvt`, decide whether to attach `rnd`, `sat`, and `part` according to the VPTO contract.

Do not dispatch TileLang DSL directly by A5 C++ helper names. TileLib needs to align with the final semantics, not clone each lower-level helper name one by one.

### 4.3 Role of `NonSatTorch`

`NonSatTorch` should be treated here as an internal template implementation detail, not a new external interface.

The regular path can be completed first, then `NonSatTorch` can be added. If the target is strict alignment with current A5 behavior, these three special paths need to be included in the first version.

## 5. Work Items

### 5.1 TileLib Template Library

A `pto.tcvt` TileLib template needs to be added with the following logic:

| Work Item | Description |
|---|---|
| Read `round_mode` | Obtain it with `pto.get_op_attr("round_mode", "RINT")` |
| Infer default `sat_mode` | Implement strictly according to the A5 type-pair rules |
| Support the `vtrc` path | Cover at least `f32 -> f32` |
| Support the regular `vcvt` path | Also satisfy the VPTO verifier requirements for attrs |
| Support the `NonSatTorch` path | Cover at least the default-`OFF` cases `f32 -> i16`, `f16 -> i16`, and `f16 -> i8` |

### 5.2 DSL / ExpandHelper / `ExpandTileOp`

In addition to the template itself, the following supporting capabilities need to be connected:

| Module | Work Item |
|---|---|
| TileLang DSL | Support `pto.get_op_attr("round_mode", ...)` |
| TileLang DSL | Add a round-mode surface for `pto.vtrc` to avoid blocking `f32 -> f32` |
| ExpandHelper | Pass `round_mode` into the template context |
| `ExpandTileOp` | Include `round_mode` in `SpecKey` to avoid incorrectly reusing instances across different `rmode` values |

There is currently no need to add `sat_mode` into `SpecKey`, because under the existing semantics it is fully determined by `(src_dtype, dst_dtype)`, and that part is already included in operand specialization.

### 5.3 Tests

Tests should be prepared in three categories:

| Test Type | Focus |
|---|---|
| Template selection and cache | The same type pair with different `rmode` values should not reuse the same instance |
| Template expansion | `round_mode` can correctly enter `vtrc` / `vcvt` |
| Numeric behavior | Default-`OFF` type pairs, special `NonSatTorch` paths, and the `f32 -> f32` path |

At minimum, cover these representative cases:

- `f32 -> f32`
- `f32 -> i16`
- `f16 -> i16`
- `f16 -> i8`
- `f32 -> i32`
- `f32 -> f16`
- `i32 -> f32`

## 6. Conclusion

The key to this work is not as simple as "pass `rmode` to one `vcvt`"; it is to carry the default `sat_mode` rules and type-dispatch rules that current A5 `pto-isa` implicitly applies in round-only `TCVT_IMPL` into TileLib as well.

For current PTOAS `pto.tcvt`, the template library should reproduce this main flow:

1. Read `round_mode` from PTOAS.
2. Infer the default `sat_mode` inside the template by `(src_dtype, dst_dtype)`.
3. Dispatch by type pair to `vtrc`, regular `vcvt`, or the `NonSatTorch` helper.

Only with this implementation can the TileLib template library stay consistent with existing A5 `pto-isa` behavior.
