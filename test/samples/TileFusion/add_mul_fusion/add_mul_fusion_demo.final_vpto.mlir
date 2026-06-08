module attributes {pto.target_arch = "a5"} {
  module attributes {pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
    func.func @add_mul_fusion_demo() {
      %c0_i64 = arith.constant 0 : i64
      %c4096_i64 = arith.constant 4096 : i64
      %c8192_i64 = arith.constant 8192 : i64
      %c12288_i64 = arith.constant 12288 : i64
      %c16384_i64 = arith.constant 16384 : i64
      %c32 = arith.constant 32 : index
      %c0 = arith.constant 0 : index
      %c1 = arith.constant 1 : index
      %c32_i32 = arith.constant 32 : i32
      pto.vecscope {
        %0 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
        %1 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
        %2 = pto.castptr %c12288_i64 : i64 -> !pto.ptr<f32, ub>
        scf.for %arg0 = %c0 to %c32 step %c1 {
          %mask, %scalar_out = pto.plt_b32 %c32_i32 : i32 -> !pto.mask<b32>, i32
          %5 = arith.muli %arg0, %c32 : index
          %6 = pto.addptr %0, %5 : <f32, ub> -> <f32, ub>
          %7 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %8 = pto.addptr %1, %5 : <f32, ub> -> <f32, ub>
          %9 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %10 = pto.vadd %7, %9, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %11 = pto.addptr %2, %5 : <f32, ub> -> <f32, ub>
          pto.vsts %10, %11[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        }
        %3 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
        %4 = pto.castptr %c16384_i64 : i64 -> !pto.ptr<f32, ub>
        scf.for %arg0 = %c0 to %c32 step %c1 {
          %mask, %scalar_out = pto.plt_b32 %c32_i32 : i32 -> !pto.mask<b32>, i32
          %5 = arith.muli %arg0, %c32 : index
          %6 = pto.addptr %2, %5 : <f32, ub> -> <f32, ub>
          %7 = pto.vlds %6[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %8 = pto.addptr %3, %5 : <f32, ub> -> <f32, ub>
          %9 = pto.vlds %8[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %10 = pto.vmul %7, %9, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %11 = pto.addptr %4, %5 : <f32, ub> -> <f32, ub>
          pto.vsts %10, %11[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        }
      }
      return
    }
  }
}

