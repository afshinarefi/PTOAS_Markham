<!--
Copyright (c) 2026 Huawei Technologies Co., Ltd.
This program is free software, you can redistribute it and/or modify it under the terms and conditions of
CANN Open Software License Agreement Version 2.0 (the "License").
Please refer to the License for details. You may not use this file except in compliance with the License.
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
See LICENSE in the root of the software repository for the full text of the License.
-->

# PR786 Loop Fusion Samples

These cases were run with the PR786 build at commit `0df074f` from
`/Users/melikanorouzbeygi/Workspace/Huawei/ptoas-pr786-vf-fusion`, using:

```bash
/Users/melikanorouzbeygi/Workspace/Huawei/ptoas-pr786-vpto-llvm-noassert-rerun/tools/ptoas/ptoas \
  --pto-arch=a5 --pto-level=level2 --pto-backend=vpto --emit-vpto \
  --enable-op-fusion --enable-tile-op-expand \
  <case>.pto \
  --mlir-print-ir-before=pto-low-level-loop-fusion \
  --mlir-print-ir-after=pto-low-level-loop-fusion \
  -o <case>.final_vpto.mlir
```

## Results

| Case | Loop shape | Result |
| --- | --- | --- |
| `pointwise_diamond_fusion.pto` | Eight elementwise stages: `tmax`, two `tsub`, two `texp`, two `tmul`, final `tadd` | Fused. The low-level pass rewrites eight same-domain 2D loop nests into one outer `scf.for` with one inner `scf.for` carrying eight iter args. See `pointwise_diamond_fusion.stderr.txt`. |
| `row_reduction_expand_fusion.pto` | Row reduction `trowsum` followed by `trowexpandmul` | Not fused. The VPTO dump before and after `pto-low-level-loop-fusion` is structurally unchanged: one reduction loop nest with `pto.vcadd`, followed by a separate broadcast multiply loop nest with `pto.vdup` and `pto.vmul`. |
| `column_reduction_expand_fusion.pto` | Column reduction `tcolsum` followed by `tcolexpandmul` | Not fused. The VPTO dump before and after `pto-low-level-loop-fusion` is structurally unchanged: one column-reduction loop nest, followed by a separate column-broadcast multiply loop nest. |

The reduction cases compile and emit final VPTO, but no `pto.fusion_region` is
formed for them before `pto-low-level-loop-fusion`, so PR786's low-level pass has
no fusion group to merge in those examples.

The `.stderr.txt` files may contain TileLang daemon RPC fallback messages. These
runs still completed with exit code `0`; the fallback path regenerated the tile
op bodies through subprocess mode before the pass dumps were emitted.
