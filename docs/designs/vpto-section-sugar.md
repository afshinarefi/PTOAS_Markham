# VPTO section sugar

## Background

The VPTO fatobj workflow currently uses an explicit two-module programming model:

```mlir
module attributes {pto.target_arch = "a5"} {
  module attributes {pto.kernel_kind = #pto.kernel_kind<vector>} {
    func.func @kernel(...) attributes {pto.kernel} {
      ...
    }
  }

  module attributes {pto.kernel_kind = #pto.kernel_kind<cube>} {
    func.func @kernel(...) attributes {pto.kernel} {
      ...
    }
  }
}
```

This model is suitable as the canonical backend input, but it is not compact enough for handwritten mixed kernels. We want to add syntax sugar that lets users write vector and cube code inside one `pto.kernel` function using `pto.section.vector` and `pto.section.cube`; the VPTO path entry then immediately unpacks it into the existing two-module form.

## Research Findings

1. `pto.section.cube` / `pto.section.vector` already exist in the PTO dialect.

2. These two ops are currently defined in `include/PTO/IR/PTOOps.td` as `SingleBlock, NoTerminator` region containers.

3. `PTOWrapFunctionsInSectionsPass` can already wrap the body of a frontend function with `pto.kernel_kind` into the corresponding section, but it serves the old frontend section/EmitC model, not VPTO mixed-module unpacking.

4. Multiple verifiers already understand section context. For example, `tpush`/`tpop`/`tfree` are allowed inside `pto.section.cube/vector`.

5. The VPTO fatobj backend currently only accepts the canonical two-module form:
   - `vpto-normalize-container` wraps a single module with `pto.kernel_kind` into an outer container and requires the outer module to contain only child modules with `pto.kernel_kind`.
   - `VPTOLLVMEmitter` selects the cube/vector LLVM target based on each child module's `pto.kernel_kind`, and appends the `_mix_aic` / `_mix_aiv` suffix to `pto.kernel` functions.
   - `VPTOHostStubEmission` generates one host stub from same-named `pto.kernel` functions and verifies that mixed variants have matching signatures.

Conclusion: the new syntax sugar should reuse the existing `pto.section.cube/vector` ops and only add an unpacking pass at the VPTO entry. It should not change the core model of LLVM emitter, host stub emission, or fatobj emission.

## Input Form

The syntax-sugar input is a normal kernel module; the module does not need `pto.kernel_kind`. One `pto.kernel` function can contain one vector section, one cube section, or only one of them. The old attribute name `pto.aicore` is still recognized for compatibility, but new input should use `pto.kernel`.

```mlir
module attributes {pto.target_arch = "a5"} {
  func.func @kernel(%src: !pto.ptr<i16, gm>, %dst: !pto.ptr<i16, gm>)
      attributes {pto.kernel} {
    %c0 = arith.constant 0 : i64

    pto.section.vector {
      // vector code
    }

    pto.section.cube {
      // cube code
    }

    return
  }
}
```

Code inside a section may use function arguments, SSA values defined outside the section within the function, and values defined inside the same section. The unpacking pass does not analyze these dependencies separately. Instead, it clones the original function as a whole and deletes the other section kind according to the target core.

## Output Form

The unpacked IR must be the existing canonical VPTO fatobj input:

```mlir
module attributes {pto.target_arch = "a5"} {
  module attributes {pto.kernel_kind = #pto.kernel_kind<vector>} {
    func.func @kernel(%src: !pto.ptr<i16, gm>, %dst: !pto.ptr<i16, gm>)
        attributes {pto.kernel} {
      // original function body with cube sections removed
      return
    }
  }

  module attributes {pto.kernel_kind = #pto.kernel_kind<cube>} {
    func.func @kernel(%src: !pto.ptr<i16, gm>, %dst: !pto.ptr<i16, gm>)
        attributes {pto.kernel} {
      // original function body with vector sections removed
      return
    }
  }
}
```

The later VPTO pipeline no longer sees `pto.section.cube/vector`; it only processes child modules with `pto.kernel_kind`.

## Unpacking Steps

1. Identify the sugar module.

   If the top-level module is already a container and its child modules have `pto.kernel_kind`, treat the input as the canonical two-module form and do not unpack sections.

   If the top-level module itself has `pto.kernel_kind`, let `vpto-normalize-container` wrap it in an outer container.

   If the top-level module does not have `pto.kernel_kind` and contains `pto.section.cube/vector` inside a `pto.kernel` function, enter section-sugar unpacking.

2. Create a child module for each kernel kind that actually appears.

   A vector section generates `module attributes {pto.kernel_kind = #pto.kernel_kind<vector>}`.

   A cube section generates `module attributes {pto.kernel_kind = #pto.kernel_kind<cube>}`.

   The outer module preserves shared module-level attributes such as `pto.target_arch`.

3. Generate same-named function variants for each function with `pto.kernel`.

   The output function preserves the original function name, argument list, result types, and `pto.kernel` attribute. `VPTOLLVMEmitter` remains responsible for appending the `_mix_aiv` / `_mix_aic` suffix later.

   Put one clone of the original function in the vector module, then delete all `pto.section.cube` instances from it.

   Put one clone of the original function in the cube module, then delete all `pto.section.vector` instances from it.

4. Inline the target section.

   In the vector module, replace `pto.section.vector` with the operations in its body.

   In the cube module, replace `pto.section.cube` with the operations in its body.

   Because each target function is cloned from the original function as a whole, shared setup code outside sections is naturally preserved. There is no need to separately analyze and clone section dependencies.

5. Dependency validation.

   The unpacking pass does not perform complex cross-section dependency analysis. After non-target sections are deleted, if the target code still references SSA values produced by a deleted section, the later MLIR verifier should report the error directly.

   This is the expected behavior: cube/vector sections cannot pass data directly through ordinary SSA values. Cross-core communication must be expressed with explicit synchronization and transfer ops.

## Constraints

1. Each section kind may appear at most once in one `pto.kernel` function.

2. `pto.section.cube` and `pto.section.vector` cannot be nested.

3. In section-sugar input, the top level of a `pto.kernel` function body may contain shared setup definitions, section ops, ordinary operations such as synchronization/transfer ops, and `return`. These operations outside sections are fully preserved in each target function.

4. If one input module contains multiple `pto.kernel` functions, each function only enters the child module corresponding to the section kinds it actually contains. The later host stub stage continues to require same-named mixed variants to have matching signatures.

5. Helper functions are copied together with the target module. Unused helpers can be left for later DCE or kept in place; they are not a semantic issue for section sugar.

6. Section ops are not preserved after unpacking. Section ops are only source-level sugar and do not enter VPTO LLVM emission.

## Placement

Name the new pass `vpto-split-cv-module`.

It should run at the very beginning of the VPTO path, before:

1. `vpto-normalize-container`

2. `prepareVPTOForEmission`

Recommended entry responsibilities:

```text
VPTO input
  -> expand section sugar to kernel_kind modules
  -> normalize single kernel_kind module to outer container
  -> verify normalized container
  -> existing nested VPTO pipeline
  -> LLVM modules
  -> fatobj
```

This keeps a single canonical IR form for the later fatobj workflow, so sections do not need to be handled during emitter or stub generation.

## Relationship With Existing Passes

`PTOWrapFunctionsInSectionsPass` goes in the opposite direction from this design:

```text
kernel_kind function -> section.cube/vector
```

The new pass goes in this direction:

```text
section.cube/vector -> kernel_kind module
```

Therefore, do not reuse `PTOWrapFunctionsInSectionsPass`, but its traversal logic for section ops and verifier constraints can inform the new implementation.

## Test Plan

1. Add a lit test with a single-module input plus `pto.section.vector` / `pto.section.cube`, and check that two `pto.kernel_kind` child modules appear after unpacking.

2. Add a test containing only a vector section, and check that it is equivalent to single-vector-module input.

3. Add error tests:
   - Duplicate vector sections in the same function.
   - Nested sections.
   - A section captures an external SSA value that cannot be cloned.
   - A `pto.kernel` function has a return value.

4. Rewrite one existing mixed VPTO host validation case as section-sugar input, and confirm that `ptoas --pto-backend=vpto` can still directly generate a fatobj and pass SIM.
