# Generalized Lowering Rules Design for the `mad` Family

## Problem

The `mad` family has already been split into semantic ops and raw ops, but lowering is still not generalized enough:

- Callee selection for ordinary MAD and MX MAD depends on local if / fallback logic, which easily crosses wires in FP8 scenarios.
- `X_t`, `CTRL`, bias packing, and callee dispatch are spread across multiple helpers, making it unclear which layer to modify when adding a type or mode.
- Some type recognition depends on string matching and is scattered through emitter logic.

The problem to solve is not to add another "larger descriptor", but to define a set of generalized lowering rules:

- Do not copy operands.
- Do not enumerate and store information that can be inferred from types.
- Do not let raw-to-LLVM reinterpret semantic clauses.
- Do not allow fallback between the ordinary and MX families.

## Core Principles

### 1. The IR Itself Is the Source of Truth, and the Op Interface Is the Access Point

Lowering does not introduce a descriptor that carries operands. Operands, types, and attributes still only exist on the original op. However, lowering also should not write class checks such as `isa<pto::MadOp>` everywhere.

Define one op interface each for semantic MAD and raw MAD, so different op classes expose the same set of accessors and derived semantics:

```c++
enum class MadFamily { Ordinary, Mx };
enum class MadAccumulation { ZeroInit, Accumulate, BiasInit };
enum class MadRawKind { Ordinary, OrdinaryBias, Mx, MxBias };

class MadSemanticOpInterface {
  Value getLhs();
  Value getRhs();
  Value getDst();
  Value getM();
  Value getN();
  Value getK();

  bool hasBiasOperand();
  Value getBiasOrNull();
  bool supportsTf32Mode();
  bool readsAccumulator();
  bool initializesAccumulatorWithZero();
  bool initializesAccumulatorWithBias();

  std::optional<pto::MadUnitFlagMode> getUnitFlagMode();
  bool getDisableGemv();
  std::optional<pto::MadSatMode> getSatMode();
  std::optional<pto::Tf32Mode> getTf32Mode();
  bool getNDir();

  MadFamily getMadFamily();
  MadAccumulation getMadAccumulation();
};

class MadRawOpInterface {
  Value getLhs();
  Value getRhs();
  Value getDst();
  Value getXt();

  bool hasBiasOperand();
  Value getBiasOrNull();

  MadRawKind getMadRawKind();
  MadFamily getMadFamily();
  bool readsAccumulator();
  bool initializesAccumulatorWithZero();
  bool initializesAccumulatorWithBias();
};
```

Interface methods can be implemented through ODS extra class declarations or C++ methods. The key point is that lowering patterns only match the interface and do not write separate logic for six semantic op classes and four raw op classes.

One class dispatch inside the implementation of an interface method is allowed, because that is a local fact at the op-definition layer. Class dispatch must not be scattered through the main lowering flow.

MLIR does not automatically consider an op to implement an interface just because the original op already has a getter with the same name. The interface must be explicitly added to the op traits in ODS. Interface methods can be implemented in two ways:

```tablegen
def MadSemanticOpInterface : OpInterface<"MadSemanticOpInterface"> {
  let cppNamespace = "::mlir::pto";
  let methods = [
    InterfaceMethod<"lhs", "::mlir::Value", "getLhs">,
    ...
  ];
}

def PTO_MadOp : PTO_Op<"mad", [
  MadSemanticOpInterface,
  DeclareOpInterfaceMethods<MemoryEffectsOpInterface>
]> { ... }
```

If an interface method has no default implementation, ODS only generates declarations for ops that implement the interface; the concrete definitions must be filled in C++. If all implementing ops have generated accessors with the same name and semantics, the interface method can provide a default implementation:

```tablegen
InterfaceMethod<
  "lhs",
  "::mlir::Value",
  "getMadLhs",
  (ins),
  [{}],
  [{ return $_op.getLhs(); }]
>
```

For fields such as `lhs/rhs/dst/m/n/k` that have the same name across all semantic MAD ops, the default implementation can directly forward to the existing accessor. For fields such as `bias` and `tf32_mode` that do not exist on every op, the interface must provide capability methods:

- `getMadFamily()`: ordinary or MX; determines the raw family and callee lookup family.
- `getMadAccumulation()`: `ZeroInit / Accumulate / BiasInit`; determines accumulator initial-value semantics.
- `readsAccumulator()`: returns true only in acc mode; it means the C initial value comes from the existing `%dst`.
- `initializesAccumulatorWithZero()`: returns true in zero-init mode; it determines `X_t.c_init = 1`.
- `initializesAccumulatorWithBias()`: returns true in bias-init mode; it determines `X_t.c_src = 1`.
- `hasBiasOperand()`: returns true only for bias-init ops.
- `getBiasOrNull()`: returns null when `hasBiasOperand() == false`.
- `supportsTf32Mode()`: returns true for ordinary MAD ops and false for MX MAD ops.
- `getTf32Mode()`: must return `std::nullopt` when `supportsTf32Mode() == false`.

Lowering must check capabilities first, then use optional accessors. It must not directly assume that every implementing op has `getBias()` or `getTf32ModeAttr()`.

These two capabilities are orthogonal and cannot be handled together through one op-class branch:

| op | family | accumulation | reads acc | zero init | bias init | bias operand | TF32 |
|---|---|---|---:|---:|---:|---:|---:|
| `pto.mad` | Ordinary | ZeroInit | false | true | false | false | true |
| `pto.mad_acc` | Ordinary | Accumulate | true | false | false | false | true |
| `pto.mad_bias` | Ordinary | BiasInit | false | false | true | true | true |
| `pto.mad_mx` | MX | ZeroInit | false | true | false | false | false |
| `pto.mad_mx_acc` | MX | Accumulate | true | false | false | false | false |
| `pto.mad_mx_bias` | MX | BiasInit | false | false | true | true | false |

Therefore, `mad_bias` is both a bias op and a TF32-capable op; `mad_mx_bias` is a bias op but not TF32-capable. `mad_acc` has no extra operand, but it is the only mode that reads the existing accumulator as the C initial value. Lowering must not directly equate "no bias operand" with "zero-init", nor bind "bias op" to "does not support TF32".

In implementation, the interface default implementation also should not call a generated getter that does not exist on every op. Recommended approach:

- `getLhs/getRhs/getDst` can use fixed operand indexes `0/1/2`.
- `getBiasOrNull` returns operand `3` depending on `hasBiasOperand()`.
- `getM/getN/getK` reads from operands `3/4/5` or `4/5/6` depending on `hasBiasOperand()`.
- `readsAccumulator/initializesAccumulatorWithZero/initializesAccumulatorWithBias` are derived from `getMadAccumulation()`; the three must be mutually exclusive and exactly one must be true.
- `getTf32Mode` reads `"tf32_mode"` through generic attribute lookup instead of calling generated `getTf32Mode()`; when MX ops have no such attr, it naturally returns empty.
- The verifier guarantees that ops with `supportsTf32Mode() == false` cannot carry `"tf32_mode"`.

In other words, interface uniformity comes from "fixed operand organization + capabilities", not from assuming that every op has exactly the same generated C++ getters.

Therefore, this is not "write your own C++ inheritance class". The correct approach is:

1. Define the op interface in `PTOInterfaces.td`.
2. Declare implementation of the interface in the traits of every MAD ODS op.
3. Use interface default implementations for getters that can be forwarded uniformly.
4. Explicitly provide small implementations per op for shape-dependent fields such as family / accumulation / bias/tf32 capability.

### 2. Family Is Determined by Op Kind, Not Guessed from Type

ordinary / MX is op semantics, not type semantics:

- `pto.mad*` semantic ops can only lower to the ordinary raw family.
- `pto.mad_mx*` semantic ops can only lower to the MX raw family.
- `pto.mad_raw` / `pto.mad_bias_raw` can only emit ordinary MAD.
- `pto.mad_mx_raw` / `pto.mad_mx_bias_raw` can only emit MX MAD.

Types are only used to select a concrete typed intrinsic within the same family. Types cannot change the family.

This is the key rule that prevents ordinary FP8 and MX FP8 from crossing wires.

### 3. Lowering Uses Rule Functions, Not a Large Descriptor

semantic-to-raw must have one unified entry. This entry is responsible for generating the two runtime values needed by the raw op from the semantic op:

- `xt`: the packed shape/config operand of raw MAD, generated from the semantic op's `m/n/k` and clauses.
- `ctrl_for_mad`: the temporary control state used by this MAD, generated from the semantic op's numeric/layout clauses and pointer types.

Rule helpers only serve this unified entry and receive interfaces instead of bare `Operation *`:

```c++
MadRawKind deriveRawKind(MadSemanticOpInterface op);
Value buildMadXtFromSemanticOp(MadSemanticOpInterface op,
                               PatternRewriter &rewriter);
Value emitCtrlForMad(MadSemanticOpInterface op, Value ctrlSaved,
                     PatternRewriter &rewriter);
StringRef lookupMadIntrinsic(MadRawOpInterface op);
```

These functions do not return a "repacked op". They only return the products actually needed by the current stage.

## semantic-to-raw Rules

The unified entry for semantic-to-raw is:

```c++
LogicalResult lowerMadSemanticOp(MadSemanticOpInterface op,
                                 PatternRewriter &rewriter);
```

This function is the only place that creates `xt`. `xt` is not passed in from outside and is not regenerated by raw-to-LLVM; it is constructed during semantic-to-raw from the operands/attributes of the original semantic op, then passed as an operand to the raw op.

The input is a semantic op, and the output is:

```text
get_ctrl
set_ctrl(ctrl_for_this_mad)
raw op(..., xt)
set_ctrl(ctrl_saved)
```

### Raw Op Selection

The raw op is determined only by the semantic op name:

| semantic op | raw op |
|---|---|
| `pto.mad` | `pto.mad_raw` |
| `pto.mad_acc` | `pto.mad_raw` |
| `pto.mad_bias` | `pto.mad_bias_raw` |
| `pto.mad_mx` | `pto.mad_mx_raw` |
| `pto.mad_mx_acc` | `pto.mad_mx_raw` |
| `pto.mad_mx_bias` | `pto.mad_mx_bias_raw` |

No descriptor is needed here. The pattern uses a generic `lowerMadSemanticOp(MadSemanticOpInterface op)` and selects the raw op through the interface's `getMadFamily()` and `getMadAccumulation()`.

### `X_t` Generation

`X_t` is the packed `xt` operand of the raw op. It is generated only in `buildMadXtFromSemanticOp(op)`, and its source is the semantic op itself:

```text
X_t.M = op.m
X_t.K = op.k
X_t.N = op.n
X_t.unit_flag = op.unit_flag or 0
X_t.disable_gemv = op.has(disable_gemv)
X_t.c_src = op.initializesAccumulatorWithBias()
X_t.c_init = op.initializesAccumulatorWithZero()
```

The accumulation is exposed by the semantic op itself through the interface:

```text
mad / mad_mx -> ZeroInit
mad_acc / mad_mx_acc -> Accumulate
mad_bias / mad_mx_bias -> BiasInit
```

This rule avoids storing `c_src/c_init` in another structure. They are derived semantics of the op kind.

### `CTRL` Generation

`CTRL` is generated only from semantic clauses and pointer types:

```text
CTRL[HiF8] = isHiF8(lhs.type, rhs.type)
CTRL[TF32 enable/round] = op.supportsTf32Mode ? op.tf32_mode/default : disabled
CTRL[sat] = op.sat_mode only if explicitly present
CTRL[n_dir] = op.has(n_dir)
```

Rules:

- HiF8 must be inferred from lhs/rhs pointer element types and cannot be stored as an independent operand or enum.
- TF32 is only allowed on ordinary `f32 x f32 -> f32` semantic ops with `supportsTf32Mode() == true`; MX ops must have `supportsTf32Mode() == false`, and `getTf32Mode()` must return empty.
- If `sat|nosat` is not written, the corresponding state is not overwritten; it is only overwritten when spelled.
- When `n_dir` is not written, explicitly set the default direction to avoid contaminating later MAD ops.
- semantic-to-raw must save and restore the `CTRL` value present before entering the op.

### semantic-to-raw Pseudocode

```c++
LogicalResult lowerMadSemanticOp(MadSemanticOpInterface op,
                                 PatternRewriter &rewriter) {
  // One entry for the entire semantic-to-raw conversion.
  // Every value consumed by the raw op is produced here.
  MadRawKind rawKind = deriveRawKind(op);          // only from interface family/accumulation
  Value xt = buildMadXtFromSemanticOp(op, rewriter); // op.m/n/k + clauses

  Value ctrlSaved = emitGetCtrl();
  Value ctrlForOp = emitCtrlForMad(op, ctrlSaved, rewriter);
  emitSetCtrl(ctrlForOp);

  emitRawOp(rawKind, op, xt, rewriter);       // forwards existing operands

  emitSetCtrl(ctrlSaved);
  erase op;
}
```

Note that `emitRawOp(rawKind, op, xt, rewriter)` only forwards the original op's existing data operands plus the newly generated `xt` to the raw op. It does not create a new operand model.

More concretely, several rule functions should look like this:

```c++
MadRawKind deriveRawKind(MadSemanticOpInterface op) {
  switch (op.getMadFamily()) {
  case MadFamily::Ordinary:
    return op.getMadAccumulation() == MadAccumulation::BiasInit
               ? MadRawKind::OrdinaryBias
               : MadRawKind::Ordinary;
  case MadFamily::Mx:
    return op.getMadAccumulation() == MadAccumulation::BiasInit
               ? MadRawKind::MxBias
               : MadRawKind::Mx;
  }
}

Value buildMadXtFromSemanticOp(MadSemanticOpInterface op,
                               PatternRewriter &rewriter) {
  Value m = op.getM();
  Value n = op.getN();
  Value k = op.getK();

  Value xt = zextOrCastI64(m);
  xt = bitOr(xt, shl(zextOrCastI64(k), 12));
  xt = bitOr(xt, shl(zextOrCastI64(n), 24));

  if (auto mode = op.getUnitFlagMode()) {
    uint64_t bits = *mode == pto::MadUnitFlagMode::CheckOnly ? 2 : 3;
    xt = bitOr(xt, shl(i64(bits), 55));
  }

  if (op.getDisableGemv())
    xt = bitOr(xt, shl(i64(1), 61));

  if (op.initializesAccumulatorWithBias())
    xt = bitOr(xt, shl(i64(1), 62));

  if (op.initializesAccumulatorWithZero())
    xt = bitOr(xt, shl(i64(1), 63));

  return xt;
}

Value emitCtrlForMad(MadSemanticOpInterface op, Value ctrlSaved,
                     PatternRewriter &rewriter) {
  Value ctrl = ctrlSaved;

  // HiF8 is inferred from the existing pointer element types.
  bool hif8 = isHiF8Type(getPtrElementType(op.getLhs()));
  ctrl = setCtrlBit(ctrl, kCtrlHiF8, hif8);

  if (op.supportsTf32Mode()) {
    auto tf32 = op.getTf32Mode();
    ctrl = setCtrlBit(ctrl, kCtrlTf32Enable, true);
    ctrl = setCtrlBit(ctrl, kCtrlTf32RoundAway,
                      tf32 && *tf32 == pto::Tf32Mode::RoundAway);
  } else {
    ctrl = setCtrlBit(ctrl, kCtrlTf32Enable, false);
    ctrl = setCtrlBit(ctrl, kCtrlTf32RoundAway, false);
  }

  // sat/nosat is only an override when the semantic op spells it explicitly.
  if (auto sat = op.getSatMode())
    ctrl = setCtrlBit(ctrl, kCtrlNoSat,
                      *sat == pto::MadSatMode::NoSat);

  ctrl = setCtrlBit(ctrl, kCtrlNDir, op.getNDir());
  return ctrl;
}

void emitRawOp(MadRawKind rawKind, MadSemanticOpInterface op, Value xt,
               PatternRewriter &rewriter) {
  Value lhs = op.getLhs();
  Value rhs = op.getRhs();
  Value dst = op.getDst();

  switch (rawKind) {
  case MadRawKind::Ordinary:
    rewriter.create<pto::MadRawOp>(op.getLoc(), lhs, rhs, dst, xt);
    return;
  case MadRawKind::OrdinaryBias:
    assert(op.hasBiasOperand());
    rewriter.create<pto::MadBiasRawOp>(op.getLoc(), lhs, rhs, dst,
                                       op.getBiasOrNull(), xt);
    return;
  case MadRawKind::Mx:
    rewriter.create<pto::MadMxRawOp>(op.getLoc(), lhs, rhs, dst, xt);
    return;
  case MadRawKind::MxBias:
    assert(op.hasBiasOperand());
    rewriter.create<pto::MadMxBiasRawOp>(op.getLoc(), lhs, rhs, dst,
                                         op.getBiasOrNull(), xt);
    return;
  }
}
```

The `op.getLhs()/op.getM()/op.getUnitFlagMode()` calls here all come from the interface. They only read operands or attributes from the original op; they do not cache, reorganize, or create new semantic objects.

## raw-to-LLVM Rules

The input to raw-to-LLVM is a raw op. It only does four things:

1. Get the family from the raw op kind.
2. Generate the intrinsic type suffix from raw op operand types.
3. Look up the family-local intrinsic table.
4. Emit the call.

### family-local dispatch

Callee lookup must be split into two entries that do not fallback to each other:

```c++
FailureOr<StringRef> lookupOrdinaryMadIntrinsic(Type lhs, Type rhs, Type dst);
FailureOr<StringRef> lookupMxMadIntrinsic(Type lhs, Type rhs, Type dst);
```

Call rules:

```c++
if (op.getMadFamily() == MadFamily::Ordinary)
  callee = lookupOrdinaryMadIntrinsic(lhsElem, rhsElem, dstElem);
else if (op.getMadFamily() == MadFamily::Mx)
  callee = lookupMxMadIntrinsic(lhsElem, rhsElem, dstElem);
```

Forbidden:

```c++
ordinary lookup failed -> try MX lookup
MX lookup failed -> try ordinary lookup
```

This is more direct than `MadElementFamily`: the type suffix is inferred at the use site from operand types and does not need to be stored as an enum first.

### Typed Suffix Derivation

Suffix derivation only answers "what this type is called under the current family":

```c++
FailureOr<StringRef> getOrdinaryMadTypeSuffix(Type lhsElem, Type rhsElem,
                                               Type dstElem);

FailureOr<StringRef> getMxMadTypeSuffix(Type lhsElem, Type rhsElem,
                                         Type dstElem);
```

Examples:

```text
ordinary:
  f16, f16, f32 -> "f162f32.c310"
  bf16, bf16, f32 -> "bf162f32.c310"
  f32, f32, f32 -> "f322f32.c310"
  e4m3, e4m3, f32 -> "e4m3e4m3.c310"

MX:
  e4m3, e4m3, f32 -> "e4m3e4m3"
  e4m3, e5m2, f32 -> "e4m3e5m2"
```

The same FP8 type combination can map to different intrinsic stems under ordinary and MX. That difference is determined by family-local lookup, not by the type itself.

### HiF8 Handling

HiF8 does not participate in raw-to-LLVM callee distinction:

- HiF8 ordinary MAD uses the ordinary FP8 typed suffix.
- HiF8 execution interpretation is expressed by the semantic-to-raw `CTRL` modification.
- raw-to-LLVM does not read the HiF8 semantic mode and does not set `CTRL`.

This guarantees that HiF8 does not contaminate ordinary FP8 through callee-name selection.

### bias packing

bias packing is a mechanical rule of the raw kind:

```text
mad_raw / mad_mx_raw:
  call dst = dst

mad_bias_raw / mad_mx_bias_raw:
  call dst = pack(dst, bias)
```

It does not participate in callee selection and does not affect the ordinary/MX family.

### raw-to-LLVM Pseudocode

```c++
LogicalResult emitMadRaw(MadRawOpInterface op,
                         ConversionPatternRewriter &rewriter) {
  Type lhsElem = getPtrElementType(op.getLhs());
  Type rhsElem = getPtrElementType(op.getRhs());
  Type dstElem = getPtrElementType(op.getDst());

  FailureOr<StringRef> callee =
      op.getMadFamily() == MadFamily::Mx
          ? lookupMxMadIntrinsic(lhsElem, rhsElem, dstElem)
          : lookupOrdinaryMadIntrinsic(lhsElem, rhsElem, dstElem);
  if (failed(callee))
    return failure();

  Value lhs = castToLeft(op.getLhs());
  Value rhs = castToRight(op.getRhs());
  Value dst = castToAcc(op.getDst());
  Value callDst = op.hasBiasOperand()
                      ? packDstAndBias(dst, castToBias(op.getBiasOrNull()))
                      : dst;

  emitCall(*callee, callDst, lhs, rhs, op.getXt());
}
```

## Type Recognition Rules

Type recognition should not use `contains("e4m3")` everywhere in the emitter. It needs to be consolidated into family-local type suffix helpers:

```c++
FailureOr<StringRef> getOrdinaryMadElemToken(Type elem);
FailureOr<StringRef> getMxMadElemToken(Type elem);
bool isHiF8Type(Type elem);
```

Constraints:

- Prefer the PTO type API.
- If some FP8/HiF8 types temporarily have no stable API, compatibility string matching is allowed inside this helper.
- String matching must not appear in callee lookup, pattern rewrite, or the main raw-lowering flow.
- Unsupported target-profile types fail in the helper and do not enter fallback.

Adding a new type then only changes the type token helper and the corresponding family-local suffix rules.

## Implementation Organization

Add lightweight helpers and op interfaces instead of a new large descriptor:

```text
include/PTO/IR/PTOInterfaces.td
include/PTO/Transforms/MadLoweringRules.h
lib/PTO/Transforms/MadLoweringRules.cpp
```

Include:

- `MadSemanticOpInterface` / `MadRawOpInterface`
- semantic-to-raw rules: `deriveRawKind`, `buildMadXtFromSemanticOp`, `emitCtrlForMad`
- raw-to-LLVM rules: `lookupOrdinaryMadIntrinsic`, `lookupMxMadIntrinsic`
- type token helpers: `getOrdinaryMadElemToken`, `getMxMadElemToken`, `isHiF8Type`

Do not include:

- operand copies
- type-family enum copies
- large state objects tightly bound to a specific rewriter
- repeated op-class checks in the main lowering flow

`VPTOExpandWrapperOps.cpp` keeps IR construction and pattern registration.
`VPTOLLVMEmitter.cpp` keeps LLVM address-space casts, bias packing, and call emission.

## Acceptance Criteria

Structural acceptance:

- ordinary raw lowering only calls `lookupOrdinaryMadIntrinsic`.
- MX raw lowering only calls `lookupMxMadIntrinsic`.
- There is no fallback between the two lookup functions.
- The main semantic-to-raw flow matches `MadSemanticOpInterface`, not per-op-class template instances.
- The main raw-to-LLVM flow matches `MadRawOpInterface`, not per-raw-op-class branches.
- semantic-to-raw does not construct a descriptor that stores operands.
- raw-to-LLVM does not read semantic clauses.
- If FP8/HiF8 string recognition exists, it only exists in the type token helper.

Behavioral acceptance:

- Full MAD SIM passes.
- ordinary FP8 `mad_raw` statically routes to ordinary `MAD.e4m3e4m3`.
- `mad_mx_raw` / `mad_mx_bias_raw` statically route to `MMAD.MX.*`.
- A same-kernel SIM with HiF8 followed by ordinary FP8 passes, proving that `CTRL` does not leak.
- Existing SIM coverage for `sat|nosat`, `tf32_mode`, and `n_dir` still passes.

## Non-goals

This design does not change user-visible MAD op syntax, does not add an MX scale operand, does not change the `acc_store` family interface, and does not redefine the numeric semantics of `sat|nosat`.
