module attributes {pto.kernel_kind = #pto.kernel_kind<vector>} {
  func.func @TAddTCvt() {
    %add_a = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>
    %add_b = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>
    %add_dst = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>

    %cvt_dst = pto.alloc_tile
      : !pto.tile_buf<loc=vec, dtype=f16, rows=16, cols=64, v_row=16, v_col=64,
                      blayout=row_major, slayout=none_box, fractal=512, pad=0>

    pto.tadd ins(%add_a, %add_b : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                             blayout=row_major, slayout=none_box, fractal=512, pad=0>,
                         !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                             blayout=row_major, slayout=none_box, fractal=512, pad=0>)
             outs(%add_dst : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                                  blayout=row_major, slayout=none_box, fractal=512, pad=0>)
             { loop_depth = [1, 2], vf_impl_kind = ["PostUpdate", "NoPostUpdate"] }

    pto.tcvt ins(%add_dst : !pto.tile_buf<loc=vec, dtype=f32, rows=16, cols=64, v_row=16, v_col=64,
                                blayout=row_major, slayout=none_box, fractal=512, pad=0>)
             outs(%cvt_dst : !pto.tile_buf<loc=vec, dtype=f16, rows=16, cols=64, v_row=16, v_col=64,
                                  blayout=row_major, slayout=none_box, fractal=512, pad=0>)

    return
  }
}
