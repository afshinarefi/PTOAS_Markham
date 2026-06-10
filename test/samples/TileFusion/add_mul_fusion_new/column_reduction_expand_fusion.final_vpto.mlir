module attributes {pto.backend = "vpto", pto.target_arch = "a5"} {
  module attributes {pto.backend = "vpto", pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
    func.func @column_reduction_expand_fusion() {
      %c32_i32 = arith.constant 32 : i32
      %c32 = arith.constant 32 : index
      %c1 = arith.constant 1 : index
      %c0 = arith.constant 0 : index
      %c128_i64 = arith.constant 128 : i64
      %c4096_i64 = arith.constant 4096 : i64
      %c0_i64 = arith.constant 0 : i64
      %c8192_i64 = arith.constant 8192 : i64
      pto.vecscope {
        %0 = pto.castptr %c8192_i64 : i64 -> !pto.ptr<f32, ub>
        %1 = pto.castptr %c0_i64 : i64 -> !pto.ptr<f32, ub>
        %mask, %scalar_out = pto.plt_b32 %c32_i32 : i32 -> !pto.mask<b32>, i32
        %2 = pto.addptr %0, %c0 : <f32, ub> -> <f32, ub>
        %result = pto.vlds %2[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
        %3 = scf.for %arg0 = %c1 to %c32 step %c1 iter_args(%arg1 = %result) -> (!pto.vreg<64xf32>) {
          %6 = arith.muli %arg0, %c32 : index
          %7 = pto.addptr %0, %6 : <f32, ub> -> <f32, ub>
          %result_0 = pto.vlds %7[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %8 = pto.vadd %arg1, %result_0, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          scf.yield %8 : !pto.vreg<64xf32>
        }
        pto.vsts %3, %1[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        %4 = pto.castptr %c4096_i64 : i64 -> !pto.ptr<f32, ub>
        %5 = pto.castptr %c128_i64 : i64 -> !pto.ptr<f32, ub>
        scf.for %arg0 = %c0 to %c32 step %c1 {
          %6 = arith.muli %arg0, %c32 : index
          %7 = pto.addptr %4, %6 : <f32, ub> -> <f32, ub>
          %result_0 = pto.vlds %7[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %result_1 = pto.vlds %1[%c0] : !pto.ptr<f32, ub> -> !pto.vreg<64xf32>
          %8 = pto.vmul %result_0, %result_1, %mask : !pto.vreg<64xf32>, !pto.vreg<64xf32>, !pto.mask<b32> -> !pto.vreg<64xf32>
          %9 = pto.addptr %5, %6 : <f32, ub> -> <f32, ub>
          pto.vsts %8, %9[%c0], %mask : !pto.vreg<64xf32>, !pto.ptr<f32, ub>, !pto.mask<b32>
        }
      }
      return
    }
  }
}

