# Unified `acc_store` Interface Design

## 1. Target Design

The target `acc_store` interface keeps only the structured `L0C -> OUT` semantics available under `target_profile`:

```mlir
pto.mte_l0c_l1 %src, %dst, %m, %n, %src_stride, %dst_stride,
              unit_flag(check_only | check_and_clear)?,
              pre_quant(%scalar_or_fb_addr, mode = ...)?,
              pre_relu(%alpha_or_fb_addr, mode = ..., clip = %clip_value ?)?,
              nz2nd? | nz2dn(%loop0_src_stride)? | nz2nz(%split)?,
              loop3(%count, %src_stride, %dst_stride)?,
              (sat | nosat)?
```

Where:

- `%src` must be `!pto.ptr<..., l0c>`.
- `%dst` may be `!pto.ptr<..., gm>`, `!pto.ptr<..., vec>`, or `!pto.ptr<..., l1>`.
- All extension fields are optional; absence means the feature is disabled.
- `nz2nd / nz2dn / nz2nz` and `loop3` are peer layout-related parameters.

## 2. Field Forms

These are the optional/required relationships for each field in this structured interface version:

- `unit_flag(check_only | check_and_clear)?`
  - Omission means `off`.
  - `check_only` means check first without clearing.
  - `check_and_clear` means check first and then clear.
  - `2'b01` is ISA-reserved and is not exposed as a legal keyword.
- `pre_quant(..., mode = ...)`
  - `mode` is required.
  - Valid `mode` values: `no_convert`, `f32_f16`, `qf322hif8_pre_vec`, `qf322hif8_pre_scalar`, `qf322hif8_pre_hybrid_vec`, `qf322hif8_pre_hybrid_scalar`, `deqs32_int_vec`, `deqs32_int_scalar`, `req8_vec`, `req8_scalar`, `deqf16_vec`, `deqf16_scalar`, `qf322fp8_pre_vec`, `qf322fp8_pre_scalar`, `qf322f32_pre_vec`, `qf322f32_pre_scalar`, `f32_bf16`, `qf162b8_pre_vec`, `qf162b8_pre_scalar`, `qf162s4_pre_vec`, `qf162s4_pre_scalar`, `req4_vec`, `req4_scalar`, `qf322b8_pre_vec`, `qf322b8_pre_scalar`, `qf322s4_pre_vec`, `qf322s4_pre_scalar`, `deqs16_vec`, `deqs16_scalar`, `qf162s16_pre_vec`, `qf162s16_pre_scalar`, `qf322f16_pre_vec`, `qf322f16_pre_scalar`, `qf322bf16_pre_vec`, `qf322bf16_pre_scalar`, `qs322bf16_pre_vec`, `qs322bf16_pre_scalar`
  - `%scalar_or_fb_addr` is interpreted according to `mode`.
  - In scalar modes, `%scalar_or_fb_addr` is the quantization parameter value, and `f16`, `bf16`, and `f32` may be passed directly.
  - An `f16`/`bf16` scalar payload is first extended to `f32`, then encoded as the 32-bit floating-point bit pattern required by `SPR.QUANT_PRE`.
  - An `f32` scalar payload is directly encoded into `SPR.QUANT_PRE` as a 32-bit floating-point bit pattern.
  - In vector modes, `%scalar_or_fb_addr` is an FB1 address and maps to `SPR.FPC[15:8] / Quant_PRE_ADDR`.
  - `mode` must also match the source/destination element types of `acc_store*`. For example, `f32 -> f16` should use `qf322f16_pre_vec/scalar`, and `req8_vec/scalar` applies only to `i32 -> i8/u8`.
  - No additional optional subparameters.
- `pre_relu(%alpha_or_fb_addr, mode = ..., clip = %clip_value)?`
  - `mode` is required.
  - Valid `mode` values: `no_relu`, `normal_relu`, `scalar_relu`, `vector_relu`, `pwl`.
  - A payload is not required for every mode:
  - For `mode = no_relu` or `mode = normal_relu`, no payload is provided.
  - For `mode = scalar_relu`, `%alpha_or_fb_addr` is required, and `f16`, `bf16`, and `f32` may be passed directly.
  - An `f16`/`bf16` scalar alpha is first extended to `f32`, then encoded as the 32-bit floating-point bit pattern required by `SPR.RELU_ALPHA`.
  - An `f32` scalar alpha is directly encoded into `SPR.RELU_ALPHA` as a 32-bit floating-point bit pattern.
  - For `mode = vector_relu`, `%alpha_or_fb_addr` is required. Its value is used as an FB1 address and maps to `SPR.FPC[7:0] / RELU_PRE_ADDR`.
  - `clip = %clip_value` is an optional clause: it enables pre-stage clip and maps `%clip_value` to `SPR.FIX_CLIP_RELU`.
  - `clip` is allowed only for target types explicitly covered by the manual: `f16`, `ui8`, `s4/s8/s16`.
- `nz2nd?`
  - No additional parameters.
- `nz2dn(%loop0_src_stride)?`
  - `loop0_src_stride` is required.
- `nz2nz(%split)?`
  - `split` is optional.
  - Omitting `split` means no F32 channel split.
- `loop3(%count, %src_stride, %dst_stride)?`
  - All three parameters are required.
  - No additional optional subparameters.
- `(sat | nosat)?`
  - Optional flag.
  - Omission means saturation control is not explicitly configured, and the state before entering the op is inherited.
  - Writing `sat` selects saturating behavior inside this op.
  - Writing `nosat` selects non-saturating behavior inside this op.
  - `sat` and `nosat` are mutually exclusive.
- `atomic(type = ..., op = ...)?`
  - Supported only by `acc_store_gm`.
  - `type` is required. Valid values: `f32`, `f16`, `s16`, `s32`, `s8`, `bf16`.
  - `op` is required. Valid values: `add`, `max`, `min`.
  - Omitting `atomic(...)` means ordinary overwrite writeback, with OUT atomic read-modify-write disabled.

## 3. Constraints

Under `target_profile`, the valid items retained by this interface version are:

- `pre_quant(...)`
- `pre_relu(..., clip = %clip_value)?`
- `unit_flag(...)`
- `nz2nd`
- `nz2dn(%loop0_src_stride)`
- `nz2nz(%split)?`
- `loop3(...)`
- `sat` / `nosat`
- `atomic(...)` (only `acc_store_gm`)

Where:

- Scalar modes of `pre_quant` use `SPR.QUANT_PRE`.
- Vector modes of `pre_quant` use `SPR.FPC[15:8] / Quant_PRE_ADDR`, corresponding to FB1 mem_block0.
- `pre_relu(%alpha_or_fb_addr, mode = scalar_relu)` uses `SPR.RELU_ALPHA[31:13]` and does not use an FB1 address.
- `pre_relu(%alpha_or_fb_addr, mode = vector_relu)` uses FB1 mem_block1 and selects `RELU_PRE_ADDR` through `SPR.FPC[7:0]`.
- The `clip` clause in `pre_relu(..., clip = %clip_value)` uses `SPR.FIX_CLIP_RELU`.
- `unit_flag` does not use FB1.
- `split` does not use FB1.
- `sat` / `nosat` use `SPR.CTRL`.
- `atomic` uses `SPR.CTRL` only on `acc_store_gm`.
- Extensions related to `post-stage`, `element-wise`, and `LoopEnhance` are not included in this interface version.

Note: `NZ2DN` and `unit_flag` are not unconditionally compatible. When `loop0_src_stride != 1`, `unit_flag` must be disabled.

Parameters for `NZ2ND / NZ2DN` are not forbidden under `target_profile`. On the contrary, `FIX_L0C_TO_OUT.f32/s32` explicitly marks `NZ2ND Mode` and `NZ2DN Mode` as valid. For `nz2dn(%loop0_src_stride)`, `loop0_src_stride` still needs to be written to `CHANNEL_PARA[63:48]`, in units of `C0_SIZE`.

`nz2nz(%split)` is allowed only for `f32` output. `SPLIT_EN = 1` with a non-`f32` output type is an illegal configuration.

`loop3(...)` is not an alias for `nz2dn` or `nz2nd`; it is a separate parameter group used only in `nz2nd` or `nz2dn` scenarios.

## 4. Mapping

- `pre_quant(%scalar_or_fb_addr, mode = ...)` maps to `SPR.QUANT_PRE` or `SPR.FPC[15:8] / Quant_PRE_ADDR`.
- `pre_relu(%alpha_or_fb_addr, mode = ...)` maps to `X_t[41:39] / ReLU_PRE`, and further maps by mode to `SPR.RELU_ALPHA[31:13]` or `SPR.FPC[7:0] / RELU_PRE_ADDR`.
- `pre_relu(..., clip = %clip_value)?` maps to `X_t[31:30] / Clip_ReLU_PRE` (enable) and `SPR.FIX_CLIP_RELU[15:0]`.
- `unit_flag(check_only | check_and_clear)?` maps to `X_t[33:32] / unit_flag`.
- `nz2nz(%split)?` maps to `X_t[42] / SPLIT_EN`.
- `nz2dn(%loop0_src_stride)` maps to `CHANNEL_PARA[63:48]`.
- `loop3(...)` maps to `SPR.LOOP3_PARA`.
- `sat` / `nosat` maps to `SPR.CTRL[48] / ctrl_sat_ctrl`.
- `atomic(type = ..., op = ...)?` is valid only for `acc_store_gm`, and maps to `SPR.CTRL[8:6] / ctrl_atomic_en` and `SPR.CTRL[10:9] / ctrl_atomic_op`.

## 5. Keyword

The current structured interface uses semantic keywords and does not expose bit encodings directly:

- `pre_relu.mode`
  - `no_relu` -> `3'b000`
  - `normal_relu` -> `3'b001`
  - `scalar_relu` -> `3'b010`
  - `vector_relu` -> `3'b011`
  - `pwl` -> `3'b100`
- `pre_quant.mode`
  - `no_convert` -> `6'b000000`
  - `f32_f16` -> `6'b000001`
  - `qf322hif8_pre_vec` -> `6'b000010`
  - `qf322hif8_pre_scalar` -> `6'b000011`
  - `qf322hif8_pre_hybrid_vec` -> `6'b000100`
  - `qf322hif8_pre_hybrid_scalar` -> `6'b000101`
  - `deqs32_int_vec` -> `6'b000110`
  - `deqs32_int_scalar` -> `6'b000111`
  - `req8_vec` -> `6'b001000`
  - `req8_scalar` -> `6'b001001`
  - `deqf16_vec` -> `6'b001010`
  - `deqf16_scalar` -> `6'b001011`
  - `qf322fp8_pre_vec` -> `6'b001100`
  - `qf322fp8_pre_scalar` -> `6'b001101`
  - `qf322f32_pre_vec` -> `6'b001110`
  - `qf322f32_pre_scalar` -> `6'b001111`
  - `f32_bf16` -> `6'b010000`
  - `qf162b8_pre_vec` -> `6'b010001`
  - `qf162b8_pre_scalar` -> `6'b010010`
  - `qf162s4_pre_vec` -> `6'b010011`
  - `qf162s4_pre_scalar` -> `6'b010100`
  - `req4_vec` -> `6'b010101`
  - `req4_scalar` -> `6'b010110`
  - `qf322b8_pre_vec` -> `6'b010111`
  - `qf322b8_pre_scalar` -> `6'b011000`
  - `qf322s4_pre_vec` -> `6'b011001`
  - `qf322s4_pre_scalar` -> `6'b011010`
  - `deqs16_vec` -> `6'b011011`
  - `deqs16_scalar` -> `6'b011100`
  - `qf162s16_pre_vec` -> `6'b011101`
  - `qf162s16_pre_scalar` -> `6'b011110`
  - `qf322f16_pre_vec` -> `6'b011111`
  - `qf322f16_pre_scalar` -> `6'b100000`
  - `qf322bf16_pre_vec` -> `6'b100001`
  - `qf322bf16_pre_scalar` -> `6'b100010`
  - `qs322bf16_pre_vec` -> `6'b100011`
  - `qs322bf16_pre_scalar` -> `6'b100100`
- `pre_quant.scalar`
  - the specific scalar payload is mode-dependent and lives in `SPR.QUANT_PRE`
- `pre_quant.fb_addr`
  - the specific parameter array address is mode-dependent and lives in `SPR.FPC[15:8]`
- `pre_relu.clip` (whether the `clip = %clip_value` clause appears)
  - absent -> `2'b00`
  - present -> `2'b01`
- `unit_flag`
  - absent -> `2'b00`
  - `check_only` -> `2'b10`
  - `check_and_clear` -> `2'b11`
- `atomic.type`
  - `f32` -> `3'b001`
  - `f16` -> `3'b010`
  - `s16` -> `3'b011`
  - `s32` -> `3'b100`
  - `s8` -> `3'b101`
  - `bf16` -> `3'b110`
- `atomic.op`
  - `add` -> `2'b00`
  - `max` -> `2'b01`
  - `min` -> `2'b10`
- `sat` / `nosat`
  - absent -> no explicit `CTRL[48]` override
  - `sat` -> `CTRL[48] = 1'b0`
  - `nosat` -> `CTRL[48] = 1'b1`

## 6. Notes

This document only describes the target design. It does not keep transitional forms of the old flat interface, and it does not expand the field lists for `profile1` post-processing, element-wise, or LoopEnhance.

This no longer introduces a large `fixpipe(...)` wrapper. These items appear directly as structured semantic fields of `acc_store`, avoiding the misunderstanding that source access, layout transform, and writeback control all belong to one fixed pipeline stage.
