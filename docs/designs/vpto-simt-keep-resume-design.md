# VPTO SIMT `pto.keep` / `pto.resume` Design

## 1. Background

VPTO currently supports expressing a SIMT VF call through `pto.store_vfsimt_info` + `func.call @simt_func(...)` + `pto.get_tid_x/y/z`.

The hardware also has an additional semantic property: between two consecutive SIMT VF calls, the SIMT register state is not automatically cleared. Some logical values written by the previous SIMT VF can be read reliably by the following SIMT VF.

If this semantic property is not modeled explicitly, later passes may treat the calls as ordinary independent calls and reorder, duplicate, or delete them.

Therefore, a new pair of VPTO ops is needed:

- `pto.keep`
- `pto.resume`

They explicitly express this implicit logical data flow across SIMT VF calls.

---

## 2. Design Goals

- Explicitly express which SSA values are kept and which SSA values are resumed.
- Do not model this semantic property as ordinary long-lived SSA `return` values, avoiding a misleading contract.
- Do not allow `!pto.vreg` / `!pto.mask` to enter this mechanism.
- Allow the verifier to enforce strict constraints by slot and payload.
- Allow lowering to consume the semantics first, then decide whether to erase them or map them to intrinsics.

Non-goals:

- No long-distance propagation over arbitrary CFGs.
- No support for one slot with multiple consumers.
- No propagation across host / kernel boundaries.

---

## 3. Core Semantics

`pto.keep` and `pto.resume` are paired by a compile-time constant `slot`.

- `pto.keep`
  - Binds the SSA values explicitly listed in the current `simtvf`
  - Records this value group into the specified `slot`

- `pto.resume`
  - Restores the value group previously saved by `pto.keep` from the specified `slot`
  - Rematerializes them as new SSA values for later use

This is a **logical data flow**, not ordinary `return` value semantics.

---

## 4. IR Interface

### 4.1 `pto.keep`

Syntax:

```mlir
pto.keep %a {slot = 0} : i32
```

Semantics:

- Explicitly saves one SSA value into `slot`
- Supports integer scalars up to 64 bits, as well as `f16` / `bf16` / `f32`
- A 64-bit integer value occupies `slot` and `slot + 1`, so `slot` must be even

### 4.2 `pto.resume`

Syntax:

```mlir
%x = pto.resume {slot = 0} : i32
```

Semantics:

- Restores the previously saved value from `slot`
- The restored result type must exactly match the `keep` payload type
- Supports integer scalars up to 64 bits, as well as `f16` / `bf16` / `f32`
- A 64-bit integer value occupies `slot` and `slot + 1`, so `slot` must be even

### 4.3 Example

```mlir
module attributes {pto.target_arch = "a5"} {
  func.func @kernel(%dst: !pto.ptr<i32, gm>) {
    %c0_i64 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %c128_i64 = arith.constant 128 : i64
    %dim_z = arith.constant 1 : i32
    %dim_y = arith.constant 32 : i32
    %dim_x = arith.constant 32 : i32
    %ub_out = pto.castptr %c0_i64 : i64 -> !pto.ptr<i32, ub>

    pto.store_vfsimt_info %dim_z, %dim_y, %dim_x : i32, i32, i32
    func.call @simt_stage0(%ub_out) : (!pto.ptr<i32, ub>) -> ()
    func.call @simt_stage1(%ub_out) : (!pto.ptr<i32, ub>) -> ()

    pto.set_flag["PIPE_V", "PIPE_MTE3", "EVENT_ID0"]
    pto.wait_flag["PIPE_V", "PIPE_MTE3", "EVENT_ID0"]
    pto.dma_store %ub_out, %dst, %c128_i64
      nburst(%c32_i64, %c128_i64, %c128_i64)
      : !pto.ptr<i32, ub>, !pto.ptr<i32, gm>, i64, i64, i64, i64
    return
  }

  func.func @simt_stage0(%dst: !pto.ptr<i32, ub>) attributes {pto.simt_entry} {
    %tid = pto.get_tid_x : i32
    pto.keep %tid {slot = 0 : i64} : i32
    return
  }

  func.func @simt_stage1(%dst: !pto.ptr<i32, ub>) attributes {pto.simt_entry} {
    %tid2 = pto.resume {slot = 0 : i64} : i32
    %tid = pto.get_tid_x : i32
    %idx = arith.index_castui %tid : i32 to index
    pto.store %tid2, %dst[%idx] : !pto.ptr<i32, ub>, i32
    return
  }
}
```

---

## 5. Placement Constraints

### 5.1 `pto.keep`

- May only appear inside a `pto.simt_entry` function.
- Must explicitly list the SSA values to save.
- `slot` must be a compile-time constant.
- The payload must not contain `!pto.vreg` / `!pto.mask`.
- In the current implementation, it must be immediately adjacent to `func.return`.

### 5.2 `pto.resume`

- May only appear inside a `pto.simt_entry` function.
- Must explicitly restore the payload.
- `slot` must match the corresponding `pto.keep`.
- The payload must not contain `!pto.vreg` / `!pto.mask`.
- In the current implementation, it must be the first operation in its block.

### 5.3 Pairing Constraints

These constraints describe the cross-SIMT-entry semantic relationships that users must preserve. The implementation does not need verifier checks for cross-entry relationships.

- A `slot` cannot be overwritten by another `keep` before it is consumed by `resume`.
- The payload types of `keep` and `resume` must match exactly.
- The first version only supports linear call chains, without crossing branches or loops.

### 5.4 Allowed Intermediate Ops

Between `keep` and its matching `resume`:

- Unrelated `pto.simt_entry` calls are forbidden
- New `pto.keep` / `pto.resume` ops are forbidden
- Ordinary scalar arithmetic, address calculations, constants, `arith.*`, and pure helper calls that are not `pto.simt_entry` are allowed

---

## 6. `store_vfsimt_info` Constraints

The launch dimensions of the two related `simtvf` calls must be identical:

- The `simtvf` containing `keep`
- The `simtvf` containing `resume`

---

## 7. Why Not Use `return` Semantics

If this state is modeled as an ordinary `return` value, it misleadingly implies that the value can be held for a long time and used later.

That does not match the timing-sensitive semantics here.

Therefore, this design chooses to:

- Use `slot` to express the logical connection across functions/calls
- Use an explicit payload to express which variables are saved
- Avoid modeling it as an ordinary long-lived return value

---

## 8. Side Effect Modeling

`pto.keep` / `pto.resume` cannot be `Pure` ops.

Model them as accesses to an abstract resource:

- `pto.keep`: `Write<SIMT_PAYLOAD_SLOT>`
- `pto.resume`: `Read<SIMT_PAYLOAD_SLOT>`

This avoids accidental damage from CSE / DCE / reordering.

---

## 9. Verifier Rules

Check at least:

1. `pto.keep` / `pto.resume` may only appear inside `pto.simt_entry`.
2. The `keep` / `resume` payload must not contain `!pto.vreg` / `!pto.mask`.
3. `slot` must be a compile-time constant.
4. `slot` is a slot explicitly allocated by the user; values of 32 bits or less occupy one slot, while 64-bit integers occupy two slots and the starting slot must be even.
5. Slot coverage ranges within the same keep/resume group must not overlap.
6. `resume` must be the first operation in its block, and `keep` must be immediately adjacent to `func.return`.

Slot pairing, payload type matching, overwrite relationships, and launch-dimension consistency across SIMT entries are semantic constraints that users must obey. They are not verifier cross-entry checks.

---

## 10. Lowering Plan

### 10.1 LLVM Carrier Form

The VPTO semantic layer keeps `pto.keep` / `pto.resume` unchanged. The LLVM layer does not introduce a long-lived `simt_state` value or add a new intrinsic; during lowering, `keep/resume` are only mapped to `llvm.inlineasm` sideeffect calls, and the backend recognizes their asm instructions.

The current implementation maps `slot` directly to fixed SIMT physical registers:

- `slot = 0` -> `R4`
- `slot = 1` -> `R5`
- ...
- `slot = 122` -> `R126`

64-bit integer values occupy a consecutive pair of slots, and the starting slot must be even. Slots are explicitly allocated by the user and are not repacked by occurrence order within a keep/resume group; therefore, when a consumer restores only part of the slots, the physical positions of the remaining slots stay stable.

Corresponding lowering:

- `pto.keep %x {slot = N} : i32`
  - `call void asm sideeffect "MOV R{4+N}, $0", "R"(i32 %x)`
- `%y = pto.resume {slot = N} : i32`
  - `%y = call i32 asm sideeffect "MOV $0, R{4+N}", "=R"()`
- `pto.keep %x {slot = N} : i64`
  - `call void asm sideeffect "IMAD.WIDE.u32 R{4+N}, RZ, RZ, $0", "R"(i64 %x)`
- `%y = pto.resume {slot = N} : i64`
  - `%y = call i64 asm sideeffect "IMAD.WIDE.u32 $0, RZ, RZ, R{4+N}", "=R"()`

Constraints:

- `keep` must carry `sideeffect` and must not be deleted as a pure function.
- `resume` must produce a result type that exactly matches the `keep` payload.
- It must not be modeled as an ordinary return token or made to look like an indefinitely held state value.
- Asm instruction names should use backend-recognizable forms such as `MOV dst, src`, not arbitrarily concatenated business strings.
- `slot` must map to `R4~R126`; out-of-range values are rejected directly in the verifier. 64-bit integer values also require an even slot, and the second slot must not exceed the range.
- The asm string must be stable enough for the backend to unambiguously recognize fixed `R` register names and the `MOV` form.

### 10.2 Execution Order

1. Keep `keep/resume` in the authoring IR.
2. Tighten slot, payload, boundary, and insertion-point constraints in the VPTO verifier.
3. Lower to inline asm sideeffect calls in `VPTOLLVMEmitter`.
4. Let the lower-level backend recognize the asm marker and expand it to the actual hardware semantics.

### 10.3 A Concrete Case

Using "`simt_stage0` saves, `simt_stage1` restores" as an example, the target shape is:

```mlir
module attributes {pto.target_arch = "a5"} {
  func.func @kernel(%dst: !pto.ptr<i32, ub>, %src: !pto.ptr<i32, gm>) {
    %c0_i64 = arith.constant 0 : i64
    %c32_i64 = arith.constant 32 : i64
    %c128_i64 = arith.constant 128 : i64
    %dim_z = arith.constant 1 : i32
    %dim_y = arith.constant 32 : i32
    %dim_x = arith.constant 32 : i32
    %ub = pto.castptr %c0_i64 : i64 -> !pto.ptr<i32, ub>

    pto.store_vfsimt_info %dim_z, %dim_y, %dim_x : i32, i32, i32
    func.call @simt_stage0(%ub) : (!pto.ptr<i32, ub>) -> ()

    func.call @simt_stage1(%ub) : (!pto.ptr<i32, ub>) -> ()

    pto.dma_store %ub, %dst, %c128_i64
      nburst(%c32_i64, %c128_i64, %c128_i64)
      : !pto.ptr<i32, ub>, !pto.ptr<i32, gm>, i64, i64, i64, i64
    return
  }

  func.func @simt_stage0(%dst: !pto.ptr<i32, ub>) attributes {pto.simt_entry} {
    %tid = pto.get_tid_x : i32
    // This represents the state produced by stage0 being kept in slot 0.
    pto.keep %tid {slot = 0} : i32
    return
  }

  func.func @simt_stage1(%dst: !pto.ptr<i32, ub>) attributes {pto.simt_entry} {
    // This represents stage1 restoring the previous stage state from slot 0.
    %tid = pto.resume {slot = 0} : i32
    return
  }
}
```

After LLVM lowering, `keep/resume` still remain inside their respective functions; they are only transformed into sideeffect operations carried by inline assembly:

- `pto.keep %tid {slot = 0} : i32` inside `simt_stage0`
  - `call void asm sideeffect "MOV R4, $0", "R"(i32 %tid)`
- `pto.resume {slot = 0} : i32` inside `simt_stage1`
  - `%tid2 = call i32 asm sideeffect "MOV $0, R4", "=R"()`

What is fixed here is not only the data-flow relationship, but also the final asm shape:

- `keep/resume` must both remain inside the corresponding `simt_entry`.
- `slot = 0` only establishes an association between these two functions.
- During lowering, `slot` must map to `R4~R126`.

---

## 11. Impact on Existing Passes

- `PTOValidateVPTOIR` needs new keep/resume checks.
- canonicalize / CSE must preserve them because of side effects.
- `VPTOLLVMEmitter` needs to consume them before erasing them.

---

## 12. Conclusion

This version is more accurate than `return simt_state`:

- It does not mislead users into treating the state as a long-lived state value
- It still explicitly expresses which variables are saved
- It also establishes strict logical data flow through slots and the verifier
