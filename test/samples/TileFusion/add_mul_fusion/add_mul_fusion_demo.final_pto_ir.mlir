module attributes {pto.kernel_kind = #pto.kernel_kind<vector>, pto.target_arch = "a5"} {
  func.func @add_mul_fusion_demo() {
    %c0_i64 = arith.constant 0 : i64
    %c4096_i64 = arith.constant 4096 : i64
    %c8192_i64 = arith.constant 8192 : i64
    %c12288_i64 = arith.constant 12288 : i64
    %c16384_i64 = arith.constant 16384 : i64
    %c32 = arith.constant 32 : index
    %c32_0 = arith.constant 32 : index
    %0 = pto.pointer_cast(%c0_i64) %c32, %c32_0 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %1 = pto.bind_tile %0, %c32, %c32_0 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>> -> memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %c32_1 = arith.constant 32 : index
    %c32_2 = arith.constant 32 : index
    %2 = pto.pointer_cast(%c4096_i64) %c32_1, %c32_2 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %3 = pto.bind_tile %2, %c32_1, %c32_2 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>> -> memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %c32_3 = arith.constant 32 : index
    %c32_4 = arith.constant 32 : index
    %4 = pto.pointer_cast(%c8192_i64) %c32_3, %c32_4 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %5 = pto.bind_tile %4, %c32_3, %c32_4 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>> -> memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %c32_5 = arith.constant 32 : index
    %c32_6 = arith.constant 32 : index
    %6 = pto.pointer_cast(%c12288_i64) %c32_5, %c32_6 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %7 = pto.bind_tile %6, %c32_5, %c32_6 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>> -> memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %c32_7 = arith.constant 32 : index
    %c32_8 = arith.constant 32 : index
    %8 = pto.pointer_cast(%c16384_i64) %c32_7, %c32_8 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    %9 = pto.bind_tile %8, %c32_7, %c32_8 {config = #pto.tile_buf_config<blayout=#pto.blayout<row_major>, slayout=#pto.slayout<none_box>, s_fractal_size=512, pad=#pto.pad_value<null>, compact=#pto.compact_mode<null>>} : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>> -> memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>
    pto.tadd ins(%1, %3 : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>, memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>) outs(%7 : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 0 : i64, pto.last_use = array<i64: 1, 1, 0>}
    pto.tmul ins(%7, %5 : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>, memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>) outs(%9 : memref<32x32xf32, strided<[32, 1], offset: ?>, #pto.address_space<vec>>) {pto.fusion.group_id = 0 : i64, pto.fusion.order = 1 : i64, pto.last_use = array<i64: 1, 1, 0>}
    return
  }
}
