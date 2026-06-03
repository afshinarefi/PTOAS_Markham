# TileLang DSL Documentation

The TileLang Python DSL provides a high-level Pythonic interface for vector computation and matrix multiplication (Cube) kernels targeting Ascend NPU hardware. This guide is intended for library developers and performance engineers who need to write efficient, hardware-aware kernels.

## Documentation Structure

### Getting Started
- [Introduction](user_guide/01-introduction.md) - Language overview, layers, and basic versus advanced modes
- [Quick Start](user_guide/02-quick-start.md) - Quick-start examples

### Core Concepts
- [Kernel Declaration](user_guide/03-kernel-declaration.md) - Kernel declarations, decorator parameters, and the constraint system
- [Template Kernels](user_guide/04-template-kernels.md) - Template kernels, multi-operation kernels, and compile-time substitution

### Type System
- [Type System](user_guide/05-type-system.md) - Scalar, vector, pointer, TensorView, and Tile types

### Control Flow
- [Control Flow](user_guide/06-control-flow.md) - Vector scopes, loops, and conditionals

### Operation Reference
- [Frontend Operations](user_guide/07-frontend-operations.md) - Frontend operations, type queries, and pointer construction
- [Synchronization and DMA Operations](user_guide/08-sync-dma-operations.md) - Synchronization and DMA operations
- [Vector Memory Operations](user_guide/09-vector-memory-operations.md) - Vector load and store operations
- [Predicate Operations](user_guide/10-predicate-operations.md) - Predicate operations
- [Vector Arithmetic Operations](user_guide/11-vector-arithmetic-operations.md) - Vector arithmetic operations
- [Cube Matrix Multiplication Operations](user_guide/12-cube-operations.md) - Cube data movement and matrix multiplication operations

### Examples and Error Handling
- [Examples](user_guide/13-examples.md) - Examples of Vector and Cube kernels
- [Common Errors](user_guide/14-common-errors.md) - Common errors and solutions

### Appendix
- [Compatibility Notes](user_guide/15-compatibility-notes.md) - Differences from the experimental implementation
- [Next Steps](user_guide/16-next-steps.md) - Related resource links

## Related Documents
- [v1-surface.md](v1-surface.md) - TileLang DSL v1 contract
- [v1-lowering.md](v1-lowering.md) - TileLang DSL v1 lowering contract
- [matcher-and-advanced-surface-migration.md](matcher-and-advanced-surface-migration.md) - Migration notes
- [unsupported-features.md](unsupported-features.md) - Unsupported features

---

**Source documentation boundary**:
- `tilelang-dsl/docs/` is the source of truth for the new `tilelang_dsl` frontend's local documentation.
- Repository-level documentation may link here, but it should not redefine the v1 boundary implemented by this package.
- `python/pto/dialects/pto.py` is not the source of truth for TileLang DSL v1.
