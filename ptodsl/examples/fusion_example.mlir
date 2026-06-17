module attributes {pto.kernel_kind = #pto.kernel_kind<vector>} {
  func.func @TADD() {
    %tadd_a = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>
    %tadd_b = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>
    %tadd_dst = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>

    pto.tadd ins(%tadd_a, %tadd_b : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                             blayout=row_major, slayout=none_box, fractal=512, pad=0>,
                         !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                             blayout=row_major, slayout=none_box, fractal=512, pad=0>)
             outs(%tadd_dst : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                                  blayout=row_major, slayout=none_box, fractal=512, pad=0>)

    %tmul_a = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>
    %tmul_b = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>
    %tmul_dst = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>

    pto.tmul ins(%tmul_a, %tmul_b : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                             blayout=row_major, slayout=none_box, fractal=512, pad=0>,
                         !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                             blayout=row_major, slayout=none_box, fractal=512, pad=0>)
             outs(%tmul_dst : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                                  blayout=row_major, slayout=none_box, fractal=512, pad=0>)
    return
  }
}