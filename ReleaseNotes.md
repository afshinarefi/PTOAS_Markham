# PTOAS (PTO Assembler & Optimizer)

## Version
- Version: v0.1.0
- Release date: 2026-02-14

## Change Summary
- Initial PTOAS release

## Overview
PTOAS (PTO Assembler & Optimizer) is a compiler toolchain for PTO Bytecode, built on LLVM/MLIR release/19.x. It provides PTO Dialect definition, parsing, verification, optimization, and code generation, and emits C++ code that can call `pto-isa`.

PTOAS will soon be integrated into the following frameworks:
- PyPTO
- TileLang

## Target Users
PTOAS is mainly intended for:
- Compiler and framework backend developers
- High-performance operator/kernel developers
- Engineering teams that need to generate, debug, and deploy PTO Bytecode

## Main Capabilities
- Full PTO Dialect flow: definition, parsing, verification, and printing
- IR support for Tile abstractions, address spaces, and the synchronization model
- PTO Bytecode to C++ generation
- Python-side dialect construction and test examples

## Minimum Platform and Dependencies
- **Operating system**: macOS (Darwin) or Linux (Ubuntu 20.04+)
- **Compiler**: Clang >= 12 or GCC >= 9, with C++17 support
- **Build tools**: CMake >= 3.20, Ninja
- **Python**: Python 3.8+

## How to Use PTOAS and Where to Find PTO IR Details
- Build and environment configuration: `README.md`
- PTO Bytecode definition: `docs/PTO_IR_manual.md`
