# `ptoas emit fatobj`

## Input/Output Form

### Input

```mlir
module attributes {pto.kernel_kind = #pto.kernel_kind<vector>} {
  func.func @helper(...) {
  }
  func.func @foo(...) attributes {pto.kernel} {
    ...
  }
}

module attributes {pto.kernel_kind = #pto.kernel_kind<cube>} {
  func.func @helper(...) {}
  func.func @foo(...) attributes {pto.kernel} {
    ...
  }
}
```

One module is allowed, but there can be at most one module for each `kernel_kind`, and only vector/cube module kinds are allowed.

Functions with `pto.kernel` keep their logical function names in the input. The input side does not need to manually append the `_mix_aic` / `_mix_aiv` suffix. The old attribute name `pto.aicore` is still recognized for compatibility, but new input should use `pto.kernel`.

### Output

fatobj object file

## Work For Each Module

### `ptoas`

`--pto-backend=vpto` directly outputs a fatobj. The external LLVM IR/BC output mode is removed here. All changes happen inside the VPTO path. Do not touch the EmitC path; it is not in scope.

0. For two sibling modules, the MLIR parser automatically creates nesting. To keep the pass pipeline from diverging, the single-module case should also be actively wrapped into the same nested structure.

1. There are currently two places in `ptoas.cpp` that enter the VPTO path. Both entry points need to be changed and support fatobj output. The emphasis here is that "both places must be changed," not that they should be forcibly merged into one control-flow entry:

- The first is the direct VPTO branch for `effectiveBackend == PTOBackend::VPTO && inputIsVPTOIR && !hasTileOpsToExpand`. This path is around [`tools/ptoas/ptoas.cpp:1605`](/home/mouliangyu/projects/github.com/mouliangyu/PTOAS-3/tools/ptoas/ptoas.cpp#L1605). It currently runs `inlineTilelangHelpersOnVPTOInput` first when needed, then directly returns `emitVPTOBackendResult(...)`.
- The second is the `effectiveBackend == PTOBackend::VPTO` branch after the generic PTO frontend pipeline runs. This path is around [`tools/ptoas/ptoas.cpp:1670`](/home/mouliangyu/projects/github.com/mouliangyu/PTOAS-3/tools/ptoas/ptoas.cpp#L1670). It currently prints seam IR first, then runs `lowerPTOToVPTOBackend`, and finally returns `emitVPTOBackendResult(...)`.

2. After entering the VPTO path, first ensure the module is automatically nested in the following form. If there is only one module, manually add one outer layer.

```mlir
module {
    module {
    }
    module { ; this second child module is absent if there is only one module
    }
}
```

3. `pto.kernel_kind` must be on the innermost module.

4. All passes are driven through a nested pass manager. Do not manually split modules and run the pass pipeline separately. This is the unified driver model for nested modules.

5. `ptoas` is responsible for unified scheduling, but not for concrete linking details. It is responsible for:

- Calling `VPTOHostStubEmission` to generate the stub source string.
- Calling `VPTOLLVMEmitter` to generate the two cube|vector LLVM module structures.
- Feeding the stub, cube, and vector components into the fatobj emission component and directly writing the final result to `outputFile`.

6. Do not modify code on the EmitC path.

### `VPTOHostStubEmission`

1. Responsible for generating the stub source string. It generates the corresponding stub according to the signatures and symbol conventions of `pto.kernel` functions in the input.

2. Same-named `pto.kernel` functions in the cube and vector modules share one stub function.

### `VPTOLLVMEmitter`

1. Responsible for LLVM module generation. Prepare and translate are combined and driven through the same nested pass manager. Do not manually split modules and run the pass pipeline separately.

2. Its external responsibility is to receive nested module input and output vector / cube LLVM modules split by `kernel_kind`.

3. For functions with `pto.kernel`, automatically append the real device symbol suffix according to the owning `kernel_kind`:

- vector appends `_mix_aiv`
- cube appends `_mix_aic`

The input side only keeps the logical function name and does not manually encode this suffix in the input IR.

4. Many functions in the current file are not module passes themselves and cannot be registered directly into the nested pass manager. They need to be wrapped as passes before entering the unified pipeline.

5. `runPipeline` is the unified internal driver entry for this module, and pass registration is centralized there.

### `VPTOFatobjEmission`

1. Responsible for interacting with the toolchain, temporary files, and final fatobj output. It organizes the vector, cube, and stub components and produces the fatobj.

2. Responsible for temporary-file management. Do not use a "temporary directory ownership + recursive directory deletion" model here; manage only individual temporary files. The reason is not an implementation bug, but that the directory model itself has higher deletion risk: once path judgment is wrong, directory deletion naturally carries batch-deletion and implicit path-interpretation risk. File-level cleanup does not have that broad damage surface.

3. Write vector/cube LLVM modules and the stub string to temporary files as required by the toolchain. Materializing files on disk is the unified primary model.

4. Build the compile flow by referring to scripts under `test/vpto`, and implement the local wrapper using the toolchain invocation model from the LLVM/Clang driver. A unified set of interfaces is needed for:

- Creating and registering temporary files for unified cleanup.
- Calling `llvm::sys::ExecuteAndWait(...)` to execute external tools.
- Redirecting the contents of already-materialized temporary files to child processes through standard input when the underlying tool supports it.
- Falling back to explicit temporary-file input when the underlying tool does not support standard-input redirection.

5. The goal of the wrapper above is not to eliminate temporary files, but to manage "temporary-file creation / registration / redirection / cleanup" uniformly, so toolchain interaction converges on a stable pattern.

6. The linking process generally follows the scripts under `test/vpto`, and the final output is the argument passed to `-o`.


## Test Constraints

### `test/vpto` Scripts

1. Test scripts under `test/vpto` should uniformly use the fatobj emitted directly by `ptoas`.

2. Scripts should no longer compile device LLVM, device object, and host stub separately and then manually package them. Instead, they should directly consume the fatobj output from `ptoas`.

3. Special-case paths in scripts for mixed / non-mixed, cube / vector, standalone `cube.pto`, and similar forms should be removed. Everything should use the same compile and link model.

### `test/vpto` Case Organization

1. Keep only one `kernel.pto` for each case.

2. Move code that was previously in `cube.pto` into the cube module in `kernel.pto`.

3. `kernel.pto` may contain both a vector module and a cube module, distinguished by `pto.kernel_kind`.

4. Supporting files for test-data generation, host stub, launch, compare, and similar tasks should continue to be kept under the existing case directory organization. Their responsibilities are not changed in this refactor.
