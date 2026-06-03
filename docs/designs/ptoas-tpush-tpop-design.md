# TALLOC/TPUSH/TPOP Frontend Interface and PTOAS Implementation Design

## 1. Document Scope

This document defines the frontend pipe-allocation and tile-transfer interfaces used by PTOAS and describes how they lower into internal PTOAS IR. It covers:

- frontend initialization ops for AIC and AIV pipe resources
- frontend data-transfer ops for allocating, pushing, popping, and freeing pipe entries
- address hinting through `reserve_buffer` and `import_reserved_buffer`
- internal IR interfaces such as `!pto.pipe`, `pto.talloc`, `pto.tpush`, `pto.tpop`, and `pto.tfree`
- lowering, verifier, flag allocation, EmitC, and `pto-isa` mapping rules

The goal is to make the frontend surface stable while keeping target-specific details inside lowering and internal IR.

## 2. Design Goals

1. Provide a clear frontend interface for moving data between Cube and Vector sides through logical pipes.
2. Support both one-way and two-way transfer patterns.
3. Keep pipe initialization explicit and verifiable.
4. Allow address planning to be automatic by default, while still supporting manual address import when needed.
5. Keep frontend ops independent from low-level event IDs and implementation details.
6. Preserve enough metadata for InsertSync and EmitC to generate correct set/wait and runtime calls.

## 3. Frontend IR Interface Definition

### 3.1 `pto.aic_initialize_pipe`

#### Semantics

Initializes pipe resources visible from the AIC/Cube side. The op declares how many logical entries are available and how they are organized for Cube-side producers or consumers.

#### Syntax

```mlir
pto.aic_initialize_pipe @pipe_name {
  slot_size = ...,
  slot_num = ...,
  dir_mask = ...,
  split = ...
}
```

#### Parameters

| Parameter | Meaning |
|---|---|
| `slot_size` | Size of each pipe slot in bytes |
| `slot_num` | Number of slots in the logical pipe |
| `dir_mask` | Direction mask: C2V, V2C, or bidirectional |
| `split` | Logical split mode used to map frontend entries to internal pipes |

### 3.2 `pto.aiv_initialize_pipe`

#### Semantics

Initializes pipe resources visible from the AIV/Vector side. It mirrors the AIC initialization contract and must agree with the same logical pipe definition.

#### Syntax

```mlir
pto.aiv_initialize_pipe @pipe_name {
  slot_size = ...,
  slot_num = ...,
  dir_mask = ...,
  split = ...
}
```

### 3.3 Frontend Data-Transfer Interfaces

The frontend exposes direction-specific ops. These ops operate on logical pipe entries and hide the internal pipe object.

#### `pto.talloc_to_aiv`

Allocates a pipe entry that will be consumed by AIV.

#### `pto.talloc_to_aic`

Allocates a pipe entry that will be consumed by AIC.

#### `pto.tpush_to_aiv`

Pushes a produced entry toward AIV.

#### `pto.tpush_to_aic`

Pushes a produced entry toward AIC.

#### `pto.tpop_from_aic`

Pops an entry produced by AIC.

#### `pto.tpop_from_aiv`

Pops an entry produced by AIV.

#### `pto.tfree_from_aic`

Frees an entry after AIC-side consumption.

#### `pto.tfree_from_aiv`

Frees an entry after AIV-side consumption.

#### GlobalTensor Pipe Entry Usage Example

```mlir
%entry = pto.talloc_to_aiv @pipe_name : !pto.pipe_entry
pto.tpush_to_aiv @pipe_name, %entry
%recv = pto.tpop_from_aic @pipe_name : !pto.pipe_entry
pto.tfree_from_aic @pipe_name, %recv
```

The exact frontend syntax may vary with ODS assembly forms, but the semantic contract is that allocation, push, pop, and free operate on the same logical entry lifecycle.

### 3.4 Address Hint Interfaces

#### `pto.reserve_buffer`

`pto.reserve_buffer` asks the compiler to reserve a local buffer region for a frontend pipe entry. It is an address-planning hint, not a data movement operation.

```mlir
%buf = pto.reserve_buffer {
  slot_size = ...,
  slot_num = ...,
  address_space = ...
} : !pto.reserved_buffer
```

#### Parameters

| Parameter | Meaning |
|---|---|
| `slot_size` | Required slot size in bytes |
| `slot_num` | Number of slots |
| `address_space` | Target local address space |
| `local_slot_num` | Optional frontend request for local slots when supported |

#### Results

The op returns an abstract reserved-buffer handle that can later be imported by transfer ops or lowered into concrete local addresses.

#### `pto.import_reserved_buffer`

Imports a previously reserved buffer into the pipe-transfer path.

```mlir
%entry = pto.import_reserved_buffer %buf : !pto.reserved_buffer -> !pto.pipe_entry
```

#### Parameters

| Parameter | Meaning |
|---|---|
| input buffer | The reserved-buffer handle |

#### Results

Returns a pipe entry associated with the reserved local address.

### 3.5 Frontend-Layer Constraints

- A logical pipe must be initialized before use.
- A frontend data-transfer op must reference an initialized pipe.
- Direction-specific ops must match `dir_mask`.
- `slot_size` and `slot_num` must be consistent between AIC and AIV initialization for the same logical pipe.
- A pipe entry must follow the lifecycle `talloc -> tpush -> tpop -> tfree`.
- Manual address import must not conflict with automatic local address planning.
- Frontend ops must not expose backend event IDs.

## 4. Core Conventions

### 4.1 Logical Pipe

A logical pipe is the frontend concept shared by AIC and AIV. It represents a queue-like transfer resource with slots. Lowering may split it into one or more internal pipes depending on direction and target.

### 4.2 Role of `split`

`split` controls how the frontend logical pipe maps to internal pipe resources. For one-way traffic, a single internal direction may be enough. For bidirectional traffic, `split` keeps the two directions independent so allocation, flag assignment, and address propagation remain clear.

### 4.3 Definition of `SLOT_SIZE`

`SLOT_SIZE` is the byte size of one pipe slot. It must be large enough for the tile or tensor fragment transferred through the pipe and must satisfy target alignment constraints.

### 4.4 `SLOT_NUM` Rules

`SLOT_NUM` is the number of slots. It determines queue depth, local-buffer reservation size, and possible multi-buffer behavior. Target profiles may impose minimum, maximum, or power-of-two constraints.

## 5. PTOAS Internal IR Interface Definition

### 5.1 `!pto.pipe`

`!pto.pipe` represents the internal pipe object produced by lowering from frontend initialization ops. It carries direction, slot size, slot count, and target-specific metadata.

### 5.2 `pto.initialize_l2g2l_pipe`

Initializes an internal pipe that connects local-to-global-to-local style movement or the corresponding target-specific route.

#### Required Attributes

| Attribute | Meaning |
|---|---|
| `slot_size` | Slot size in bytes |
| `slot_num` | Number of slots |
| `direction` | Pipe direction |

#### Optional Attributes

| Attribute | Meaning |
|---|---|
| `split` | Split mode inherited from frontend |
| `local_slot_num` | Local slot override when supported |
| `reserved_addr` | Planned local address if available |

#### Operands

Operands may include reserved-buffer handles, explicit address operands, or target-specific pipe configuration values.

### 5.3 `pto.initialize_l2l_pipe`

Initializes an internal local-to-local pipe used for direct local-side exchange.

#### Required Attributes

The required attributes mirror `pto.initialize_l2g2l_pipe`: `slot_size`, `slot_num`, and `direction`.

#### Optional Attributes

Optional attributes include `split`, local-slot configuration, and address-planning metadata.

#### Operands

Operands carry runtime or planned address handles when required.

### 5.4 pipe entry type

A pipe entry type represents a single allocated slot in an internal pipe. It is the value threaded through `talloc`, `tpush`, `tpop`, and `tfree`.

### 5.5 `pto.talloc`

Allocates an entry from an internal pipe.

### 5.6 `pto.tpush`

Pushes an allocated entry to the opposite side.

### 5.7 `pto.declare_tile`

Declares the tile object or tile view associated with a pipe entry.

### 5.8 `pto.declare_global`

Declares a global tensor or global pointer associated with the transfer.

### 5.9 `pto.tpop`

Pops an entry produced by the other side.

### 5.10 `pto.tfree`

Frees a consumed entry so the slot can be reused.

## 6. Frontend-to-Internal IR Lowering Rules

### 6.1 Initialization Interface Lowering

#### A2/A3

For A2/A3, lowering follows the legacy pipe model. Frontend initialization is translated into internal initialization ops compatible with the existing runtime and `pto-isa` implementation.

#### A5

For A5, lowering selects the A5 internal pipe form and preserves metadata needed for local address planning, event allocation, and EmitC mapping.

### 6.2 `DIR_MASK=1/2`

One-way direction masks lower to a single internal pipe in the corresponding direction. Only the matching frontend transfer ops are legal.

### 6.3 `DIR_MASK=3`

Bidirectional direction masks lower to two direction-specific internal pipes or one split internal representation, depending on target support. Allocation and flag IDs must remain independent per direction.

### 6.4 Binding Frontend Data-Transfer Ops to Internal Pipes

Each frontend op is bound to the internal pipe selected by its logical pipe name and direction. The binding must be deterministic and must reject ambiguous mappings.

### 6.5 Data-Transfer Op Lowering

#### `talloc_to_aiv` / `talloc_to_aic`

Lower to `pto.talloc` on the internal pipe selected by the destination side.

#### `tpush_to_aiv` / `tpush_to_aic`

Lower to `pto.tpush` on the same internal pipe used for allocation.

#### `tpop_from_aic` / `tpop_from_aiv`

Lower to `pto.tpop` from the producer side's corresponding internal pipe.

#### `tfree_from_aic` / `tfree_from_aiv`

Lower to `pto.tfree` after the consumer side is done with the entry.

## 7. `reserve_buffer` and Address Propagation

### 7.1 Design Principles

Address reservation is separated from data-transfer semantics. The reservation describes where a slot may live; the transfer ops describe when the slot is produced and consumed.

### 7.2 Usage Rules

#### C2V

For Cube-to-Vector traffic, the reserved local address must be valid for the producer and visible to the consumer path selected by lowering.

#### V2C

For Vector-to-Cube traffic, the reserved address must satisfy the Cube-side layout, size, and alignment requirements.

### 7.3 Compilation Path and Address Handling Path

The compile path is:

```text
frontend reserve/import
  -> internal pipe initialization
  -> local address planning or manual address import
  -> address propagation pass
  -> EmitC / pto-isa mapping
```

### 7.4 Auto Path with Local Address Planning Enabled

In the automatic path, the compiler owns address assignment. `reserve_buffer` contributes size and slot-count constraints, and the local address planner selects concrete addresses.

### 7.5 Manual Path that Skips Local Address Planning

In the manual path, addresses are imported explicitly. The compiler verifies consistency but does not reassign addresses.

### 7.6 `import_reserved_buffer` Rules

`import_reserved_buffer` must refer to a valid reservation, must be used with a compatible pipe direction, and must not be imported into multiple conflicting lifecycles.

### 7.7 Address Propagation Pass Rules

#### 7.7.1 Pass Placement

The pass should run after frontend-to-internal lowering and before EmitC generation.

#### 7.7.2 Input Assumptions

The pass assumes internal pipe initialization and pipe entry lifecycles are already well-formed.

#### 7.7.3 Implementation Flow

1. Collect reserved-buffer definitions.
2. Match imports to pipe entries.
3. Propagate concrete or planned addresses to internal pipe ops.
4. Verify size, slot count, and direction compatibility.
5. Report conflicts with actionable diagnostics.

#### 7.7.4 Result IR Form

The result IR should contain internal pipe ops with explicit address metadata or operands, ready for EmitC lowering.

#### 7.7.5 Failure Conditions

The pass fails if:

- a reservation is missing
- a reservation is used with an incompatible direction
- slot size or slot count conflicts
- manual addresses overlap illegally
- target alignment constraints are violated

## 8. Flag Allocation Rules

### 8.1 General Principles

Flags are allocated per pipe direction and per lifecycle. The frontend does not choose event IDs; allocation is handled by the backend synchronization and codegen stages.

### 8.2 One-Way Scenarios

A one-way pipe needs one producer-to-consumer flag flow. Allocation should avoid conflicts with other live pipe entries in the same direction.

### 8.3 Bidirectional Scenarios

Bidirectional pipes need independent flag resources per direction. C2V and V2C lifecycles must not share an event ID unless the backend proves that their lifetimes do not conflict and the target permits reuse.

### 8.4 Relationship with Address Propagation

Address propagation determines where data lives; flag allocation determines ordering. The two must agree on pipe direction and lifecycle, but neither should silently rewrite the other's metadata.

## 9. Verifier Rules

### 9.1 Frontend Verifier

The frontend verifier should check:

- pipe initialization exists before use
- AIC and AIV initialization agree for the same logical pipe
- direction-specific transfer ops match `dir_mask`
- `slot_size` and `slot_num` are legal
- `split` is legal for the selected direction and target
- `reserve_buffer` and `import_reserved_buffer` have compatible types
- lifecycle order is valid: allocate before push, pop before free

### 9.2 Internal IR Verifier

The internal verifier should check:

- internal pipe ops have valid attributes and operands
- pipe entries are used with the pipe that produced them
- address metadata is complete after propagation
- event-relevant direction metadata is present
- target-specific slot and alignment rules are satisfied

### 9.3 Verification Boundary for `split`

Frontend verification should ensure `split` is syntactically and semantically legal. Target-specific lowering decides how `split` maps to internal pipes and may reject combinations unsupported by the selected target.

## 10. EmitC and `pto-isa` Mapping

### 10.1 Initialization Ops

Internal initialization ops lower to the corresponding `pto-isa` pipe setup calls or EmitC helper calls. The mapping must preserve:

- slot size
- slot count
- direction
- split mode
- reserved or planned local addresses

### 10.2 Data-Transfer Ops

`pto.talloc`, `pto.tpush`, `pto.tpop`, and `pto.tfree` lower to target-specific runtime or `pto-isa` calls. The generated code must preserve the pipe entry lifecycle and use the event resources selected by allocation.

### 10.3 InsertSync

InsertSync is responsible for ordering around pipe operations. It should see internal pipe ops with enough direction and memory metadata to generate the required set/wait or barrier operations.

## 11. Compilation Flow Overview

```text
frontend pipe initialization and transfer ops
  -> frontend verifier
  -> frontend-to-internal pipe lowering
  -> address planning or reserved-buffer import
  -> address propagation
  -> internal verifier
  -> InsertSync and event allocation
  -> EmitC / pto-isa lowering
```

This keeps the user-facing interface stable while allowing PTOAS to choose target-specific internal pipe layouts, address paths, and synchronization resources.
