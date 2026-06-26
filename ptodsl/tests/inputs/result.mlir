/home/a84369921/miniconda3/envs/ptoas/lib/python3.10/runpy.py:126: RuntimeWarning: 'ptodsl.tilelib.serving.daemon' found in sys.modules after import of package 'ptodsl.tilelib.serving', but prior to execution of 'ptodsl.tilelib.serving.daemon'; this may result in unpredictable behaviour
  warn(RuntimeWarning(msg))
TileLang daemon started (pid=3417587, socket=/tmp/tilelang_daemon_3417541.sock)
Info: TileLang daemon started successfully
// -----// IR Dump After PTOCanonicalizeIR (pto-canonicalize-ir) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOCanonicalizeIR (pto-canonicalize-ir) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOAssignDefaultFrontendPipeId (pto-assign-default-frontend-pipe-id) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOAssignDefaultFrontendPipeId (pto-assign-default-frontend-pipe-id) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOLowerFrontendPipeOps (pto-lower-frontend-pipe-ops) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOLowerFrontendPipeOps (pto-lower-frontend-pipe-ops) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOInferValidatePipeInit (pto-infer-validate-pipe-init) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
    pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
    return
  }
}


// -----// IR Dump After PTOInferValidatePipeInit (pto-infer-validate-pipe-init) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
    pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
    return
  }
}


// -----// IR Dump After PTOLoweringSyncToPipe (pto-lowering-sync-to-pipe) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOLoweringSyncToPipe (pto-lowering-sync-to-pipe) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After InferPTOLayout (pto-infer-layout) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After InferPTOLayout (pto-infer-layout) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOA5NormalizeTMov (pto-a5-normalize-tmov) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOA5NormalizeTMov (pto-a5-normalize-tmov) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOValidateIntToPtrUses (pto-validate-inttoptr-uses) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOValidateIntToPtrUses (pto-validate-inttoptr-uses) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>)
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>)
  return
}

// -----// IR Dump After PTOAddTemplateAttributePass (pto-add-template-attribute) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {versions = [{id = 1 : i64, loop_depth = 2 : i64, name = "template_tmul_2d_post_update", tail = "has_tail", vf_impl_kind = "PostUpdate"}, {id = 2 : i64, loop_depth = 1 : i64, name = "template_tmul_1d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}, {id = 3 : i64, loop_depth = 1 : i64, name = "template_tmul_1d_post_update", tail = "no_tail", vf_impl_kind = "PostUpdate"}, {id = 4 : i64, loop_depth = 2 : i64, name = "template_tmul_2d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}]}
    pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>) {versions = [{id = 1 : i64, loop_depth = 2 : i64, name = "template_tadd_2d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}, {id = 2 : i64, loop_depth = 1 : i64, name = "template_tadd_1d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}, {id = 3 : i64, loop_depth = 2 : i64, name = "template_tadd_2d_post_update", tail = "has_tail", vf_impl_kind = "PostUpdate"}, {id = 4 : i64, loop_depth = 1 : i64, name = "template_tadd_1d_post_update", tail = "no_tail", vf_impl_kind = "PostUpdate"}]}
    return
  }
}


// -----// IR Dump After PTOAddTemplateAttributePass (pto-add-template-attribute) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {versions = [{id = 1 : i64, loop_depth = 2 : i64, name = "template_tmul_2d_post_update", tail = "has_tail", vf_impl_kind = "PostUpdate"}, {id = 2 : i64, loop_depth = 1 : i64, name = "template_tmul_1d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}, {id = 3 : i64, loop_depth = 1 : i64, name = "template_tmul_1d_post_update", tail = "no_tail", vf_impl_kind = "PostUpdate"}, {id = 4 : i64, loop_depth = 2 : i64, name = "template_tmul_2d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}]}
    pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>) {versions = [{id = 1 : i64, loop_depth = 2 : i64, name = "template_tadd_2d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}, {id = 2 : i64, loop_depth = 1 : i64, name = "template_tadd_1d_no_post_update", tail = "no_tail", vf_impl_kind = "NoPostUpdate"}, {id = 3 : i64, loop_depth = 2 : i64, name = "template_tadd_2d_post_update", tail = "has_tail", vf_impl_kind = "PostUpdate"}, {id = 4 : i64, loop_depth = 1 : i64, name = "template_tadd_1d_post_update", tail = "no_tail", vf_impl_kind = "PostUpdate"}]}
    return
  }
}


// -----// IR Dump After FusionPlanVersionSelection (pto-fusion-plan-version-selection) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 0 : i64, version_name = "template_tmul_1d_no_post_update"}
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 1 : i64, version_name = "template_tadd_1d_no_post_update"}
  return
}

// -----// IR Dump After FusionPlanVersionSelection (pto-fusion-plan-version-selection) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 0 : i64, version_name = "template_tmul_1d_no_post_update"}
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 1 : i64, version_name = "template_tadd_1d_no_post_update"}
  return
}

// -----// IR Dump After OpScheduling (pto-op-scheduling) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 0 : i64, version_name = "template_tmul_1d_no_post_update"}
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 1 : i64, version_name = "template_tadd_1d_no_post_update"}
  return
}

// -----// IR Dump After OpScheduling (pto-op-scheduling) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.tmul ins(%2, %3 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 0 : i64, version_name = "template_tmul_1d_no_post_update"}
  pto.tadd ins(%4, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%1 : !pto.tile_buf<vec, 16x64xf32>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 1 : i64, version_name = "template_tadd_1d_no_post_update"}
  return
}

// -----// IR Dump After PTOFusionRegionGen (pto-fusion-region-gen) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.fusion_region {
    %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    pto.tmul ins(%1, %2 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%3 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
    pto.tadd ins(%3, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
    pto.yield() : () -> ()
  } {pto.fusion.group_id = 0 : i64} : 
  return
}

// -----// IR Dump After PTOFusionRegionGen (pto-fusion-region-gen) //----- //
func.func @TADD() {
  %0 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
  pto.fusion_region {
    %3 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile : !pto.tile_buf<vec, 16x64xf32>
    pto.tmul ins(%1, %2 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%3 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
    pto.tadd ins(%3, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
    pto.yield() : () -> ()
  } {pto.fusion.group_id = 0 : i64} : 
  return
}

// -----// IR Dump After PTOViewToMemref (pto-view-to-memref) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %alloc = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %0 = pto.bind_tile %alloc, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %c16_0 = arith.constant 16 : index
    %c64_1 = arith.constant 64 : index
    %alloc_2 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.bind_tile %alloc_2, %c16_0, %c64_1 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %c16_3 = arith.constant 16 : index
    %c64_4 = arith.constant 64 : index
    %alloc_5 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %2 = pto.bind_tile %alloc_5, %c16_3, %c64_4 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    pto.fusion_region {
      %c16_6 = arith.constant 16 : index
      %c64_7 = arith.constant 64 : index
      %alloc_8 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %3 = pto.bind_tile %alloc_8, %c16_6, %c64_7 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      %c16_9 = arith.constant 16 : index
      %c64_10 = arith.constant 64 : index
      %alloc_11 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %4 = pto.bind_tile %alloc_11, %c16_9, %c64_10 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      pto.tmul ins(%1, %2 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%3 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%3, %0 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%4 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PTOViewToMemref (pto-view-to-memref) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %alloc = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %0 = pto.bind_tile %alloc, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %c16_0 = arith.constant 16 : index
    %c64_1 = arith.constant 64 : index
    %alloc_2 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.bind_tile %alloc_2, %c16_0, %c64_1 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %c16_3 = arith.constant 16 : index
    %c64_4 = arith.constant 64 : index
    %alloc_5 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %2 = pto.bind_tile %alloc_5, %c16_3, %c64_4 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    pto.fusion_region {
      %c16_6 = arith.constant 16 : index
      %c64_7 = arith.constant 64 : index
      %alloc_8 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %3 = pto.bind_tile %alloc_8, %c16_6, %c64_7 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      %c16_9 = arith.constant 16 : index
      %c64_10 = arith.constant 64 : index
      %alloc_11 = memref.alloc() : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %4 = pto.bind_tile %alloc_11, %c16_9, %c64_10 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      pto.tmul ins(%1, %2 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%3 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%3, %0 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%4 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PlanMemory (pto-plan-memory) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.bind_tile %0, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %2 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %3 = pto.bind_tile %2, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %4 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %5 = pto.bind_tile %4, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    pto.fusion_region {
      %6 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %7 = pto.bind_tile %6, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      %8 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %9 = pto.bind_tile %8, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      pto.tmul ins(%3, %5 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%7 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%7, %1 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%9 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PlanMemory (pto-plan-memory) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.bind_tile %0, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %2 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %3 = pto.bind_tile %2, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %4 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %5 = pto.bind_tile %4, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    pto.fusion_region {
      %6 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %7 = pto.bind_tile %6, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      %8 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %9 = pto.bind_tile %8, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      pto.tmul ins(%3, %5 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%7 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%7, %1 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%9 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PTOResolveReservedBuffers (pto-resolve-reserved-buffers) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.bind_tile %0, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %2 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %3 = pto.bind_tile %2, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %4 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %5 = pto.bind_tile %4, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    pto.fusion_region {
      %6 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %7 = pto.bind_tile %6, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      %8 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %9 = pto.bind_tile %8, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      pto.tmul ins(%3, %5 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%7 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%7, %1 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%9 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PTOResolveReservedBuffers (pto-resolve-reserved-buffers) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.bind_tile %0, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %2 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %3 = pto.bind_tile %2, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    %4 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %5 = pto.bind_tile %4, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
    pto.fusion_region {
      %6 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %7 = pto.bind_tile %6, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      %8 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %9 = pto.bind_tile %8, %c16, %c64 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>> -> memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>
      pto.tmul ins(%3, %5 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%7 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%7, %1 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>, memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) outs(%9 : memref<16x64xf32, strided<[64, 1], offset: ?>, #pto.address_space<vec>>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PTOMaterializeTileHandles (pto-materialize-tile-handles) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %3 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %5 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %6 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %7 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %8 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %9 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      pto.tmul ins(%3, %5 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%7 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%7, %1 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%9 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After PTOMaterializeTileHandles (pto-materialize-tile-handles) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %1 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %3 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
    %5 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %6 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %7 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %8 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, strided<[64, 1]>, #pto.address_space<vec>>
      %9 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      pto.tmul ins(%3, %5 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%7 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%7, %1 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%9 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      pto.tmul ins(%1, %2 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%3 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%3, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      pto.tmul ins(%1, %2 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%3 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%3, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


TileLang daemon started (pid=3418285, socket=/tmp/tilelang_daemon_3417541.sock)
Info: TileLang daemon started successfully
// -----// IR Dump After VPTOSplitCVModule (vpto-split-cv-module) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      pto.tmul ins(%1, %2 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%3 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
      pto.tadd ins(%3, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}


// -----// IR Dump After VPTONormalizeContainer (vpto-normalize-container) //----- //
module attributes {pto.backend = "vpto", pto.target_arch = "a5"} {
  module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
    func.func @TADD() {
      %c0_i64 = arith.constant 0 : i64
      %c4096_i64 = arith.constant 4096 : i64
      %c8192_i64 = arith.constant 8192 : i64
      %c12288_i64 = arith.constant 12288 : i64
      %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
      %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
      %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      pto.fusion_region {
        %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
        %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
        pto.tmul ins(%1, %2 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%3 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tmul_1d_no_post_update"}
        pto.tadd ins(%3, %0 : !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) outs(%4 : !pto.tile_buf<vec, 16x64xf32>) {version_name = "template_tadd_1d_no_post_update"}
        pto.yield() : () -> ()
      } {pto.fusion.group_id = 0 : i64} : 
      return
    }
  }
}


/home/a84369921/miniconda3/envs/ptoas/lib/python3.10/runpy.py:126: RuntimeWarning: 'ptodsl.tilelib.serving.daemon' found in sys.modules after import of package 'ptodsl.tilelib.serving', but prior to execution of 'ptodsl.tilelib.serving.daemon'; this may result in unpredictable behaviour
  warn(RuntimeWarning(msg))
// -----// IR Dump After ExpandTileOp (pto-expand-tile-op) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      func.call @template_tmul_1d_no_post_update(%1, %2, %3) : (!pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) -> ()
      func.call @template_tadd_1d_no_post_update(%3, %0, %4) : (!pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>, !pto.tile_buf<vec, 16x64xf32>) -> ()
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
  func.func private @template_tmul_1d_no_post_update(%arg0: !pto.tile_buf<vec, 16x64xf32>, %arg1: !pto.tile_buf<vec, 16x64xf32>, %arg2: !pto.tile_buf<vec, 16x64xf32>) attributes {pto.kernel_kind = #pto.kernel_kind<vector>, pto.tilelang.instance} {
    %0 = pto.tile_valid_rows %arg2 : !pto.tile_buf<vec, 16x64xf32> -> index
    %1 = pto.tile_valid_cols %arg2 : !pto.tile_buf<vec, 16x64xf32> -> index
    %c0 = arith.constant 0 : index
    %c64 = arith.constant 64 : index
    %2 = scf.for %arg3 = %c0 to %1 step %c64 iter_args(%arg4 = %1) -> (index) {
      %3 = arith.index_cast %arg4 : index to i32
      %mask, %scalar_out = pto.plt_b32 %3 : i32 -> !pto.mask<b32>, i32
      %4 = arith.index_cast %scalar_out : i32 to index
      %c64_0 = arith.constant 64 : index
      %5 = arith.subi %c64_0, %arg3 : index
      %6 = pto.tile_buf_addr %arg0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview = memref.subview %6[0, %arg3] [1, %5] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_1 = arith.constant 0 : index
      %result = pto.vlds %subview[%c0_1] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %c64_2 = arith.constant 64 : index
      %7 = arith.subi %c64_2, %arg3 : index
      %8 = pto.tile_buf_addr %arg1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_3 = memref.subview %8[0, %arg3] [1, %7] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_4 = arith.constant 0 : index
      %result_5 = pto.vlds %subview_3[%c0_4] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %9 = pto.vmul %result, %result_5, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %c64_6 = arith.constant 64 : index
      %10 = arith.subi %c64_6, %arg3 : index
      %11 = pto.tile_buf_addr %arg2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_7 = memref.subview %11[0, %arg3] [1, %10] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_8 = arith.constant 0 : index
      pto.vsts %9, %subview_7[%c0_8], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      scf.yield %4 : index
    }
    return
  }
  func.func private @template_tadd_1d_no_post_update(%arg0: !pto.tile_buf<vec, 16x64xf32>, %arg1: !pto.tile_buf<vec, 16x64xf32>, %arg2: !pto.tile_buf<vec, 16x64xf32>) attributes {pto.kernel_kind = #pto.kernel_kind<vector>, pto.tilelang.instance} {
    %0 = pto.tile_valid_rows %arg2 : !pto.tile_buf<vec, 16x64xf32> -> index
    %1 = pto.tile_valid_cols %arg2 : !pto.tile_buf<vec, 16x64xf32> -> index
    %c0 = arith.constant 0 : index
    %c64 = arith.constant 64 : index
    %2 = scf.for %arg3 = %c0 to %1 step %c64 iter_args(%arg4 = %1) -> (index) {
      %3 = arith.index_cast %arg4 : index to i32
      %mask, %scalar_out = pto.plt_b32 %3 : i32 -> !pto.mask<b32>, i32
      %4 = arith.index_cast %scalar_out : i32 to index
      %c64_0 = arith.constant 64 : index
      %5 = arith.subi %c64_0, %arg3 : index
      %6 = pto.tile_buf_addr %arg0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview = memref.subview %6[0, %arg3] [1, %5] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_1 = arith.constant 0 : index
      %result = pto.vlds %subview[%c0_1] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %c64_2 = arith.constant 64 : index
      %7 = arith.subi %c64_2, %arg3 : index
      %8 = pto.tile_buf_addr %arg1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_3 = memref.subview %8[0, %arg3] [1, %7] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_4 = arith.constant 0 : index
      %result_5 = pto.vlds %subview_3[%c0_4] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %9 = pto.vadd %result, %result_5, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %c64_6 = arith.constant 64 : index
      %10 = arith.subi %c64_6, %arg3 : index
      %11 = pto.tile_buf_addr %arg2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_7 = memref.subview %11[0, %arg3] [1, %10] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_8 = arith.constant 0 : index
      pto.vsts %9, %subview_7[%c0_8], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      scf.yield %4 : index
    }
    return
  }
}

// -----// IR Dump After PTOInlineLibCall (pto-inline-libcall) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      %5 = pto.tile_valid_rows %3 : !pto.tile_buf<vec, 16x64xf32> -> index
      %6 = pto.tile_valid_cols %3 : !pto.tile_buf<vec, 16x64xf32> -> index
      %c0 = arith.constant 0 : index
      %c64 = arith.constant 64 : index
      %7 = scf.for %arg0 = %c0 to %6 step %c64 iter_args(%arg1 = %6) -> (index) {
        %11 = arith.index_cast %arg1 : index to i32
        %mask, %scalar_out = pto.plt_b32 %11 : i32 -> !pto.mask<b32>, i32
        %12 = arith.index_cast %scalar_out : i32 to index
        %c64_2 = arith.constant 64 : index
        %13 = arith.subi %c64_2, %arg0 : index
        %14 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview = memref.subview %14[0, %arg0] [1, %13] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_3 = arith.constant 0 : index
        %result = pto.vlds %subview[%c0_3] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %c64_4 = arith.constant 64 : index
        %15 = arith.subi %c64_4, %arg0 : index
        %16 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_5 = memref.subview %16[0, %arg0] [1, %15] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_6 = arith.constant 0 : index
        %result_7 = pto.vlds %subview_5[%c0_6] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %17 = pto.vmul %result, %result_7, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
        %c64_8 = arith.constant 64 : index
        %18 = arith.subi %c64_8, %arg0 : index
        %19 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_9 = memref.subview %19[0, %arg0] [1, %18] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_10 = arith.constant 0 : index
        pto.vsts %17, %subview_9[%c0_10], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
        scf.yield %12 : index
      }
      %8 = pto.tile_valid_rows %4 : !pto.tile_buf<vec, 16x64xf32> -> index
      %9 = pto.tile_valid_cols %4 : !pto.tile_buf<vec, 16x64xf32> -> index
      %c0_0 = arith.constant 0 : index
      %c64_1 = arith.constant 64 : index
      %10 = scf.for %arg0 = %c0_0 to %9 step %c64_1 iter_args(%arg1 = %9) -> (index) {
        %11 = arith.index_cast %arg1 : index to i32
        %mask, %scalar_out = pto.plt_b32 %11 : i32 -> !pto.mask<b32>, i32
        %12 = arith.index_cast %scalar_out : i32 to index
        %c64_2 = arith.constant 64 : index
        %13 = arith.subi %c64_2, %arg0 : index
        %14 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview = memref.subview %14[0, %arg0] [1, %13] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_3 = arith.constant 0 : index
        %result = pto.vlds %subview[%c0_3] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %c64_4 = arith.constant 64 : index
        %15 = arith.subi %c64_4, %arg0 : index
        %16 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_5 = memref.subview %16[0, %arg0] [1, %15] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_6 = arith.constant 0 : index
        %result_7 = pto.vlds %subview_5[%c0_6] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %17 = pto.vadd %result, %result_7, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
        %c64_8 = arith.constant 64 : index
        %18 = arith.subi %c64_8, %arg0 : index
        %19 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_9 = memref.subview %19[0, %arg0] [1, %18] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_10 = arith.constant 0 : index
        pto.vsts %17, %subview_9[%c0_10], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
        scf.yield %12 : index
      }
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}

// -----// IR Dump After FoldTileBufIntrinsics (pto-fold-tile-buf-intrinsics) //----- //
func.func @TADD() {
  %c0_i64 = arith.constant 0 : i64
  %c4096_i64 = arith.constant 4096 : i64
  %c8192_i64 = arith.constant 8192 : i64
  %c12288_i64 = arith.constant 12288 : i64
  %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
  pto.fusion_region {
    %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    %c16 = arith.constant 16 : index
    %c64 = arith.constant 64 : index
    %c0 = arith.constant 0 : index
    %c64_0 = arith.constant 64 : index
    %5 = scf.for %arg0 = %c0 to %c64 step %c64_0 iter_args(%arg1 = %c64) -> (index) {
      %7 = arith.index_cast %arg1 : index to i32
      %mask, %scalar_out = pto.plt_b32 %7 : i32 -> !pto.mask<b32>, i32
      %8 = arith.index_cast %scalar_out : i32 to index
      %c64_5 = arith.constant 64 : index
      %9 = arith.subi %c64_5, %arg0 : index
      %10 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview = memref.subview %10[0, %arg0] [1, %9] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_6 = arith.constant 0 : index
      %result = pto.vlds %subview[%c0_6] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %c64_7 = arith.constant 64 : index
      %11 = arith.subi %c64_7, %arg0 : index
      %12 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_8 = memref.subview %12[0, %arg0] [1, %11] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_9 = arith.constant 0 : index
      %result_10 = pto.vlds %subview_8[%c0_9] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %13 = pto.vmul %result, %result_10, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %c64_11 = arith.constant 64 : index
      %14 = arith.subi %c64_11, %arg0 : index
      %15 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_12 = memref.subview %15[0, %arg0] [1, %14] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_13 = arith.constant 0 : index
      pto.vsts %13, %subview_12[%c0_13], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      scf.yield %8 : index
    }
    %c16_1 = arith.constant 16 : index
    %c64_2 = arith.constant 64 : index
    %c0_3 = arith.constant 0 : index
    %c64_4 = arith.constant 64 : index
    %6 = scf.for %arg0 = %c0_3 to %c64_2 step %c64_4 iter_args(%arg1 = %c64_2) -> (index) {
      %7 = arith.index_cast %arg1 : index to i32
      %mask, %scalar_out = pto.plt_b32 %7 : i32 -> !pto.mask<b32>, i32
      %8 = arith.index_cast %scalar_out : i32 to index
      %c64_5 = arith.constant 64 : index
      %9 = arith.subi %c64_5, %arg0 : index
      %10 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview = memref.subview %10[0, %arg0] [1, %9] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_6 = arith.constant 0 : index
      %result = pto.vlds %subview[%c0_6] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %c64_7 = arith.constant 64 : index
      %11 = arith.subi %c64_7, %arg0 : index
      %12 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_8 = memref.subview %12[0, %arg0] [1, %11] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_9 = arith.constant 0 : index
      %result_10 = pto.vlds %subview_8[%c0_9] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %13 = pto.vadd %result, %result_10, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %c64_11 = arith.constant 64 : index
      %14 = arith.subi %c64_11, %arg0 : index
      %15 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_12 = memref.subview %15[0, %arg0] [1, %14] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %c0_13 = arith.constant 0 : index
      pto.vsts %13, %subview_12[%c0_13], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      scf.yield %8 : index
    }
    pto.yield() : () -> ()
  } {pto.fusion.group_id = 0 : i64} : 
  return
}

// -----// IR Dump After PTOLowLevelLoopFusion (pto-low-level-loop-fusion) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      %c16 = arith.constant 16 : index
      %c64 = arith.constant 64 : index
      %c0 = arith.constant 0 : index
      %c64_0 = arith.constant 64 : index
      %c16_1 = arith.constant 16 : index
      %c64_2 = arith.constant 64 : index
      %c0_3 = arith.constant 0 : index
      %c64_4 = arith.constant 64 : index
      %5:2 = scf.for %arg0 = %c0 to %c64 step %c64_0 iter_args(%arg1 = %c64, %arg2 = %c64_2) -> (index, index) {
        %6 = arith.index_cast %arg1 : index to i32
        %mask, %scalar_out = pto.plt_b32 %6 : i32 -> !pto.mask<b32>, i32
        %7 = arith.index_cast %scalar_out : i32 to index
        %c64_5 = arith.constant 64 : index
        %8 = arith.subi %c64_5, %arg0 : index
        %9 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview = memref.subview %9[0, %arg0] [1, %8] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_6 = arith.constant 0 : index
        %result = pto.vlds %subview[%c0_6] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %c64_7 = arith.constant 64 : index
        %10 = arith.subi %c64_7, %arg0 : index
        %11 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_8 = memref.subview %11[0, %arg0] [1, %10] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_9 = arith.constant 0 : index
        %result_10 = pto.vlds %subview_8[%c0_9] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %12 = pto.vmul %result, %result_10, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
        %c64_11 = arith.constant 64 : index
        %13 = arith.subi %c64_11, %arg0 : index
        %14 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_12 = memref.subview %14[0, %arg0] [1, %13] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_13 = arith.constant 0 : index
        pto.vsts %12, %subview_12[%c0_13], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
        %15 = arith.index_cast %arg2 : index to i32
        %mask_14, %scalar_out_15 = pto.plt_b32 %15 : i32 -> !pto.mask<b32>, i32
        %16 = arith.index_cast %scalar_out_15 : i32 to index
        %c64_16 = arith.constant 64 : index
        %17 = arith.subi %c64_16, %arg0 : index
        %18 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_17 = memref.subview %18[0, %arg0] [1, %17] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_18 = arith.constant 0 : index
        %result_19 = pto.vlds %subview_17[%c0_18] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %c64_20 = arith.constant 64 : index
        %19 = arith.subi %c64_20, %arg0 : index
        %20 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_21 = memref.subview %20[0, %arg0] [1, %19] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_22 = arith.constant 0 : index
        %result_23 = pto.vlds %subview_21[%c0_22] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
        %21 = pto.vadd %result_19, %result_23, %mask_14 : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
        %c64_24 = arith.constant 64 : index
        %22 = arith.subi %c64_24, %arg0 : index
        %23 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
        %subview_25 = memref.subview %23[0, %arg0] [1, %22] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
        %c0_26 = arith.constant 0 : index
        pto.vsts %21, %subview_25[%c0_26], %mask_14 : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
        scf.yield %7, %16 : index, index
      }
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}

// -----// IR Dump After Canonicalizer (canonicalize) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c64_i32 = arith.constant 64 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %5 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview = memref.subview %5[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %6 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_0 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %7 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %8 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_3 = memref.subview %8[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      pto.vsts %7, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      %mask_5, %scalar_out_6 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %9 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_7 = memref.subview %9[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_8 = memref.cast %subview_7 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result_9 = pto.vlds %cast_8[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %10 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_10 = memref.subview %10[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_11 = memref.cast %subview_10 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result_12 = pto.vlds %cast_11[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %11 = pto.vadd %result_9, %result_12, %mask_5 : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %12 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_13 = memref.subview %12[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_14 = memref.cast %subview_13 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      pto.vsts %11, %cast_14[%c0], %mask_5 : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}

// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c64_i32 = arith.constant 64 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    pto.fusion_region {
      %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
      %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
      %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %5 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview = memref.subview %5[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %6 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_0 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %7 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %8 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_3 = memref.subview %8[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      pto.vsts %7, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %9 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_6 = memref.subview %9[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
      %10 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %11 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
      %subview_9 = memref.subview %11[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
      %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
      pto.vsts %10, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
      pto.yield() : () -> ()
    } {pto.fusion.group_id = 0 : i64} : 
    return
  }
}

// -----// IR Dump After PTOFusionPredicateElision (pto-fusion-predicate-elision) //----- //
func.func @TADD() {
  %c64_i32 = arith.constant 64 : i32
  %c0 = arith.constant 0 : index
  %c0_i64 = arith.constant 0 : i64
  %c4096_i64 = arith.constant 4096 : i64
  %c8192_i64 = arith.constant 8192 : i64
  %c12288_i64 = arith.constant 12288 : i64
  %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
  pto.fusion_region {
    %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %5 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %5[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %6 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %7 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %8 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %8[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %7, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %9 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %9[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %10 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %11 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %11[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %10, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    pto.yield() : () -> ()
  } {pto.fusion.group_id = 0 : i64} : 
  return
}

// -----// IR Dump After PTOFusionLoadStoreElision (pto-fusion-load-store-elision) //----- //
func.func @TADD() {
  %c64_i32 = arith.constant 64 : i32
  %c0 = arith.constant 0 : index
  %c0_i64 = arith.constant 0 : i64
  %c4096_i64 = arith.constant 4096 : i64
  %c8192_i64 = arith.constant 8192 : i64
  %c12288_i64 = arith.constant 12288 : i64
  %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
  pto.fusion_region {
    %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %5 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %5[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %6 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %7 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %8 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %8[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %7, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %9 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %9[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %10 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %11 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %11[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %10, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    pto.yield() : () -> ()
  } {pto.fusion.group_id = 0 : i64} : 
  return
}

// -----// IR Dump After PTOFlattenFusionRegion (pto-flatten-fusion-region) //----- //
func.func @TADD() {
  %c64_i32 = arith.constant 64 : i32
  %c0 = arith.constant 0 : index
  %c0_i64 = arith.constant 0 : i64
  %c4096_i64 = arith.constant 4096 : i64
  %c8192_i64 = arith.constant 8192 : i64
  %c12288_i64 = arith.constant 12288 : i64
  %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
  %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
  %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
  %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
  %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
  %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
  %5 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
  %subview = memref.subview %5[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %6 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
  %subview_0 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %7 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
  %8 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
  %subview_3 = memref.subview %8[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  pto.vsts %7, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
  %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %9 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
  %subview_6 = memref.subview %9[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %10 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
  %11 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
  %subview_9 = memref.subview %11[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  pto.vsts %10, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
  return
}

// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c64_i32 = arith.constant 64 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %0 = pto.alloc_tile addr = %c12288_i64 : !pto.tile_buf<vec, 16x64xf32>
    %1 = pto.alloc_tile addr = %c8192_i64 : !pto.tile_buf<vec, 16x64xf32>
    %2 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    %3 = pto.alloc_tile addr = %c0_i64 : !pto.tile_buf<vec, 16x64xf32>
    %4 = pto.alloc_tile addr = %c4096_i64 : !pto.tile_buf<vec, 16x64xf32>
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %5 = pto.tile_buf_addr %1 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %5[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %6 = pto.tile_buf_addr %2 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %7 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %8 = pto.tile_buf_addr %3 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %8[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %7, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %9 = pto.tile_buf_addr %0 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %9[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %10 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %11 = pto.tile_buf_addr %4 : !pto.tile_buf<vec, 16x64xf32> -> memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %11[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %10, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After FoldTileBufIntrinsics (pto-fold-tile-buf-intrinsics) //----- //
func.func @TADD() {
  %c64_i32 = arith.constant 64 : i32
  %c0 = arith.constant 0 : index
  %c0_i64 = arith.constant 0 : i64
  %c4096_i64 = arith.constant 4096 : i64
  %c8192_i64 = arith.constant 8192 : i64
  %c12288_i64 = arith.constant 12288 : i64
  %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
  %0 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
  %subview = memref.subview %0[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %1 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
  %subview_0 = memref.subview %1[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %2 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
  %3 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
  %subview_3 = memref.subview %3[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  pto.vsts %2, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
  %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %4 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
  %subview_6 = memref.subview %4[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
  %5 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
  %6 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
  %subview_9 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
  %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
  pto.vsts %5, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
  return
}

// -----// IR Dump After SCCP (sccp) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %0[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %1 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %1[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %2 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %3 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %3[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %2, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %4 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %4[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %5 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %6 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %5, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After Canonicalizer (canonicalize) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %0[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %1 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %1[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %2 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %3 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %3[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %2, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %4 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %4[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %5 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %6 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %5, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After Canonicalizer (canonicalize) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %0[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %1 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %1[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %2 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %3 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %3[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %2, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %4 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %4[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %5 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %6 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %5, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.pointer_cast(%c8192_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview = memref.subview %0[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %subview : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result = pto.vlds %cast[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %1 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_0 = memref.subview %1[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_1 = memref.cast %subview_0 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_2 = pto.vlds %cast_1[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %2 = pto.vmul %result, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %3 = pto.pointer_cast(%c0_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_3 = memref.subview %3[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_4 = memref.cast %subview_3 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %2, %cast_4[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    %result_5 = pto.vlds %cast_4[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %4 = pto.pointer_cast(%c12288_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_6 = memref.subview %4[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %subview_6 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %result_8 = pto.vlds %cast_7[%c0] : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> -> !pto.vreg<64xf32>
    %5 = pto.vadd %result_5, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %6 = pto.pointer_cast(%c4096_i64) {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<16x64xf32, #pto.address_space<vec>>
    %subview_9 = memref.subview %6[0, 0] [1, 64] [1, 1] : memref<16x64xf32, #pto.address_space<vec>> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_10 = memref.cast %subview_9 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    pto.vsts %5, %cast_10[%c0], %mask : !pto.vreg<64xf32>, memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After VPTOPtrNormalize (vpto-ptr-normalize) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
    %c0_0 = arith.constant 0 : index
    %c0_1 = arith.constant 0 : index
    %c64 = arith.constant 64 : index
    %1 = arith.muli %c0_1, %c64 : index
    %2 = arith.addi %c0_0, %1 : index
    %c0_2 = arith.constant 0 : index
    %3 = arith.addi %2, %c0_2 : index
    %4 = pto.addptr %0, %3 : <f32, ub> -> <f32, ub>
    %5 = builtin.unrealized_conversion_cast %4 : !pto.ptr<f32, ub> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast = memref.cast %5 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %6 = builtin.unrealized_conversion_cast %cast : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> to !pto.ptr<f32, ub>
    %result = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %7 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %c0_3 = arith.constant 0 : index
    %c0_4 = arith.constant 0 : index
    %c64_5 = arith.constant 64 : index
    %8 = arith.muli %c0_4, %c64_5 : index
    %9 = arith.addi %c0_3, %8 : index
    %c0_6 = arith.constant 0 : index
    %10 = arith.addi %9, %c0_6 : index
    %11 = pto.addptr %7, %10 : <f32, ub> -> <f32, ub>
    %12 = builtin.unrealized_conversion_cast %11 : !pto.ptr<f32, ub> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_7 = memref.cast %12 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %13 = builtin.unrealized_conversion_cast %cast_7 : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> to !pto.ptr<f32, ub>
    %result_8 = pto.vlds %13[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %14 = pto.vmul %result, %result_8, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %15 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
    %c0_9 = arith.constant 0 : index
    %c0_10 = arith.constant 0 : index
    %c64_11 = arith.constant 64 : index
    %16 = arith.muli %c0_10, %c64_11 : index
    %17 = arith.addi %c0_9, %16 : index
    %c0_12 = arith.constant 0 : index
    %18 = arith.addi %17, %c0_12 : index
    %19 = pto.addptr %15, %18 : <f32, ub> -> <f32, ub>
    %20 = builtin.unrealized_conversion_cast %19 : !pto.ptr<f32, ub> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_13 = memref.cast %20 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %21 = builtin.unrealized_conversion_cast %cast_13 : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> to !pto.ptr<f32, ub>
    pto.vsts %14, %21[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    %result_14 = pto.vlds %21[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %22 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
    %c0_15 = arith.constant 0 : index
    %c0_16 = arith.constant 0 : index
    %c64_17 = arith.constant 64 : index
    %23 = arith.muli %c0_16, %c64_17 : index
    %24 = arith.addi %c0_15, %23 : index
    %c0_18 = arith.constant 0 : index
    %25 = arith.addi %24, %c0_18 : index
    %26 = pto.addptr %22, %25 : <f32, ub> -> <f32, ub>
    %27 = builtin.unrealized_conversion_cast %26 : !pto.ptr<f32, ub> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_19 = memref.cast %27 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %28 = builtin.unrealized_conversion_cast %cast_19 : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> to !pto.ptr<f32, ub>
    %result_20 = pto.vlds %28[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %29 = pto.vadd %result_14, %result_20, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %30 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %c0_21 = arith.constant 0 : index
    %c0_22 = arith.constant 0 : index
    %c64_23 = arith.constant 64 : index
    %31 = arith.muli %c0_22, %c64_23 : index
    %32 = arith.addi %c0_21, %31 : index
    %c0_24 = arith.constant 0 : index
    %33 = arith.addi %32, %c0_24 : index
    %34 = pto.addptr %30, %33 : <f32, ub> -> <f32, ub>
    %35 = builtin.unrealized_conversion_cast %34 : !pto.ptr<f32, ub> to memref<64xf32, strided<[1]>, #pto.address_space<vec>>
    %cast_25 = memref.cast %35 : memref<64xf32, strided<[1]>, #pto.address_space<vec>> to memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>>
    %36 = builtin.unrealized_conversion_cast %cast_25 : memref<?xf32, strided<[1], offset: ?>, #pto.address_space<vec>> to !pto.ptr<f32, ub>
    pto.vsts %29, %36[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After VPTOPtrCastCleanup (vpto-ptr-cast-cleanup) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
    %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
    %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
    %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
    %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
    pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
    %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
    %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %10 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %11 = pto.addptr %10, %c0 : <f32, ub> -> <f32, ub>
    pto.vsts %9, %11[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After ReconcileUnrealizedCasts (reconcile-unrealized-casts) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
    %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
    %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
    %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
    %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
    pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
    %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
    %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %10 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %11 = pto.addptr %10, %c0 : <f32, ub> -> <f32, ub>
    pto.vsts %9, %11[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After VPTOExpandWrapperOps (vpto-expand-wrapper-ops) //----- //
func.func @TADD() {
  %c12288_i64 = arith.constant 12288 : i64
  %c8192_i64 = arith.constant 8192 : i64
  %c4096_i64 = arith.constant 4096 : i64
  %c0_i64 = arith.constant 0 : i64
  %c0 = arith.constant 0 : index
  %c64_i32 = arith.constant 64 : i32
  %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
  %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
  %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
  %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
  %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
  %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
  %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
  %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
  %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
  %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
  pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
  %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
  %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
  %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
  %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
  %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
  %10 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
  %11 = pto.addptr %10, %c0 : <f32, ub> -> <f32, ub>
  pto.vsts %9, %11[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
  return
}

// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
    %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
    %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
    %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
    %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
    pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
    %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
    %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    pto.vsts %9, %3[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    return
  }
}

// -----// IR Dump After PTOInferVPTOVecScope (pto-infer-vpto-vecscope) //----- //
func.func @TADD() {
  pto.vecscope {
    %c12288_i64 = arith.constant 12288 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c0_i64 = arith.constant 0 : i64
    %c0 = arith.constant 0 : index
    %c64_i32 = arith.constant 64 : i32
    %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
    %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
    %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
    %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
    %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
    %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
    %mask_1, %scalar_out_2 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    pto.vsts %4, %6[%c0], %mask_1 : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    %result_3 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
    %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
    %result_4 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
    %mask_5, %scalar_out_6 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    %9 = pto.vadd %result_3, %result_4, %mask_5 : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
    %mask_7, %scalar_out_8 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
    pto.vsts %9, %3[%c0], %mask_7 : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
  }
  return
}

// -----// IR Dump After Canonicalizer (canonicalize) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c64_i32 = arith.constant 64 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    pto.vecscope {
      %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
      %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
      %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
      %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
      %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
      %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
      %mask_1, %scalar_out_2 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      pto.vsts %4, %6[%c0], %mask_1 : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
      %result_3 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
      %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
      %result_4 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %mask_5, %scalar_out_6 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %9 = pto.vadd %result_3, %result_4, %mask_5 : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %mask_7, %scalar_out_8 = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      pto.vsts %9, %3[%c0], %mask_7 : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    }
    return
  }
}

// -----// IR Dump After CSE (cse) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c64_i32 = arith.constant 64 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    pto.vecscope {
      %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
      %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
      %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
      %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
      %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
      %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
      pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
      %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
      %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
      %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      pto.vsts %9, %3[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    }
    return
  }
}

// -----// IR Dump After mlir::pto::{anonymous}::PTOValidateVPTOEmissionIRPass (pto-validate-vpto-emission-ir) //----- //
module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @TADD() {
    %c64_i32 = arith.constant 64 : i32
    %c0 = arith.constant 0 : index
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    pto.vecscope {
      %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
      %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
      %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
      %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
      %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
      %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
      %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
      pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
      %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
      %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
      %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
      %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
      pto.vsts %9, %3[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
    }
    return
  }
}

module attributes {pto.backend = "vpto", pto.target_arch = "a5"} {
  module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
    func.func @TADD() {
      %c64_i32 = arith.constant 64 : i32
      %c0 = arith.constant 0 : index
      %c0_i64 = arith.constant 0 : i64
      %c4096_i64 = arith.constant 4096 : i64
      %c8192_i64 = arith.constant 8192 : i64
      %c12288_i64 = arith.constant 12288 : i64
      pto.vecscope {
        %mask, %scalar_out = pto.plt_b32 %c64_i32 : i32 -> !pto.mask<b32>, i32
        %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
        %1 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
        %result = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
        %2 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
        %3 = pto.addptr %2, %c0 : <f32, ub> -> <f32, ub>
        %result_0 = pto.vlds %3[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
        %4 = pto.vmul %result, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
        %5 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
        %6 = pto.addptr %5, %c0 : <f32, ub> -> <f32, ub>
        pto.vsts %4, %6[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        %result_1 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
        %7 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
        %8 = pto.addptr %7, %c0 : <f32, ub> -> <f32, ub>
        %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
        %9 = pto.vadd %result_1, %result_2, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
        pto.vsts %9, %3[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
      }
      return
    }
  }
}

TileLang daemon stopped (pid=3418285)
