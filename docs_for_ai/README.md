# PTOAS — `docs_for_ai`

Status / architecture docs for the PTOAS project, written to be useful to both humans
skimming for orientation and AI agents picking up a task. Each file covers **one part**
of the system, with concrete `file:line` references and an honest "current status"
section (what works / what is WIP / what is missing).

> **Conventions**
> - Line numbers are accurate as of June 2026 but drift with edits — treat them as
>   "start here", grep the symbol if it moved.
> - `✅ works` / `⚠️ partial / WIP` / `❌ missing / stub` are used consistently.
> - "PTOAS repo" = `/home/mani/Desktop/PTOAS_Markham`. "pto-isa repo" =
>   `/home/mani/Desktop/pto-isa` (a separate checkout, the C++ tile library the
>   generated code calls).

## Read in this order

| Doc | Covers |
|-----|--------|
| [00-overview.md](00-overview.md) | The whole system on one page: the two-DSL problem, the #739 migration plan, how the parts connect, glossary. **Start here.** |
| [01-compiler-pipeline.md](01-compiler-pipeline.md) | The PTO / VPTO MLIR dialect and the full pass pipeline (`.pto` → C++ / object). The compiler core. |
| [02-ptodsl-frontend.md](02-ptodsl-frontend.md) | The **new** `ptodsl` Python frontend: authoring API, tracing engine, status. |
| [03-tilelang-dsl-and-expandtileop.md](03-tilelang-dsl-and-expandtileop.md) | The **legacy** `tilelang-dsl` + the `lib/TileOps` templates + `ExpandTileOp` + the Tilelang daemon. The thing #739 wants to replace. |
| [04-ptoas-cli-and-backends.md](04-ptoas-cli-and-backends.md) | The `ptoas` CLI: flags (`--pto-arch`, `--pto-level`, `--pto-backend`), the EmitC vs VPTO backends, output modes. |
| [05-pto-isa-library.md](05-pto-isa-library.md) | The separate `pto-isa` C++ tile library: arch support, what "version selection" means there (functional vs performance), how generated code links to it. |
| [ptodsl_tilelang_expandtileop_summary.md](ptodsl_tilelang_expandtileop_summary.md) | **Design notes** from the user + GPT + China team on the migration (kept verbatim; the human-decision record behind #739). |

## The one-sentence summary

PTOAS is an out-of-tree MLIR compiler that turns PTO bytecode (`.pto`) into C++/objects
that call the `pto-isa` tile library; today it has **two** Python DSLs doing overlapping
work (`ptodsl` as the user-facing frontend, `tilelang-dsl` as the compiler-internal
template engine for `ExpandTileOp`), and discussion #739 is the plan to collapse them
into one (`ptodsl`-as-TileLib) with compiler-visible version selection.
