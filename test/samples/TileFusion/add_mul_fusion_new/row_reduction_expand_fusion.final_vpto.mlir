module attributes {pto.backend = "vpto", pto.target_arch = "a5"} {
  module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
    func.func @row_reduction_expand_fusion() {
      %c32_i32 = arith.constant 32 : i32
      %c1_i32 = arith.constant 1 : i32
      %cst = arith.constant 0.000000e+00 : f32
      %c32 = arith.constant 32 : index
      %c0 = arith.constant 0 : index
      %c1 = arith.constant 1 : index
      %c5120_i64 = arith.constant 5120 : i64
      %c8192_i64 = arith.constant 8192 : i64
      %c4096_i64 = arith.constant 4096 : i64
      %c12288_i64 = arith.constant 12288 : i64
      %c8 = arith.constant 8 : index
      pto.vecscope {
        %0 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
        %1 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
        %mask, %scalar_out = pto.plt_b32 %c1_i32 : i32 -> !pto.mask<b32>, i32
        scf.for %arg0 = %c0 to %c32 step %c1 {
          %4 = pto.vbr %cst : f32 -> !pto.vreg<64xf32>
          %mask_0, %scalar_out_1 = pto.plt_b32 %c32_i32 : i32 -> !pto.mask<b32>, i32
          %5 = arith.muli %arg0, %c32 : index
          %6 = pto.addptr %0, %5 : <f32, ub> -> <f32, ub>
          %result = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %7 = pto.vcadd %result, %mask_0 : !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %8 = pto.vadd %4, %7, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %9 = arith.muli %arg0, %c8 : index
          %10 = pto.addptr %1, %9 : <f32, ub> -> <f32, ub>
          pto.vsts %8, %10[%c0], %mask {dist = "1PT_B32"} : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        }
        %2 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
        %3 = pto.castptr %c5120_i64 : i64 -> !pto.ptr<f32, ub>
        scf.for %arg0 = %c0 to %c32 step %c1 {
          %mask_0, %scalar_out_1 = pto.plt_b32 %c32_i32 : i32 -> !pto.mask<b32>, i32
          %4 = arith.muli %arg0, %c8 : index
          %5 = pto.addptr %1, %4 : <f32, ub> -> <f32, ub>
          %result = pto.vlds %5[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %6 = pto.vdup %result, %mask_0 {position = "LOWEST"} : !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %7 = arith.muli %arg0, %c32 : index
          %8 = pto.addptr %2, %7 : <f32, ub> -> <f32, ub>
          %result_2 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %9 = pto.vmul %result_2, %6, %mask_0 : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %10 = pto.addptr %3, %7 : <f32, ub> -> <f32, ub>
          pto.vsts %9, %10[%c0], %mask_0 : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        }
      }
      return
    }
  }
}

