# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.trems."""

import ptodsl.tilelib as pto


@pto.tile_template(
    op="pto.trems",
    target="a5",
    name="template_trems",
    dtypes=[
        ("f32", "f32", "f32", "f32"),
        ("f16", "f16", "f16", "f16"),
    ],
)
def template_trems(
    src: pto.Tile,
    scalar: pto.Scalar,
    tmp: pto.Tile,
    dst: pto.Tile,
):
    dtype = src.element_type
    valid_rows, valid_cols = src.valid_shape

    if pto.constexpr(str(dtype) == "f32"):
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            for col in range(0, valid_cols, pto.get_lanes(dtype)):
                mask, remained = pto.make_mask(dtype, remained)
                vec = pto.vlds(src[row, col:])
                quotient = pto.vtrc(
                    pto.vdiv(vec, pto.vbr(scalar), mask),
                    mask,
                    rnd="Z",
                )
                pto.vsts(
                    pto.vsub(vec, pto.vmuls(quotient, scalar, mask), mask),
                    dst[row, col:],
                    mask,
                )
    else:
        full_b16 = pto.make_mask(pto.f16, pto.MaskPattern.ALL)
        full_b32 = pto.make_mask(pto.f32, pto.MaskPattern.ALL)
        scalar_f32 = pto.vcvt(
            pto.vbr(scalar),
            pto.f32,
            full_b16,
            part=pto.VcvtPartMode.EVEN,
        )
        for row in range(0, valid_rows, 1):
            remained = valid_cols
            remained_f32 = valid_cols
            for col in range(0, valid_cols, pto.get_lanes(pto.f16)):
                mask16, remained = pto.make_mask(pto.f16, remained)
                mask32, remained_f32 = pto.make_mask(pto.f32, remained_f32)
                vec = pto.vlds(src[row, col:])
                even = pto.vcvt(vec, pto.f32, full_b16, part=pto.VcvtPartMode.EVEN)
                odd = pto.vcvt(vec, pto.f32, full_b16, part=pto.VcvtPartMode.ODD)
                quotient_even = pto.vtrc(pto.vdiv(even, scalar_f32, mask32), mask32, rnd="F")
                quotient_odd = pto.vtrc(pto.vdiv(odd, scalar_f32, mask32), mask32, rnd="F")
                result_even = pto.vsub(
                    even, pto.vmul(quotient_even, scalar_f32, mask32), mask32
                )
                result_odd = pto.vsub(
                    odd, pto.vmul(quotient_odd, scalar_f32, mask32), mask32
                )
                result16_even = pto.vcvt(
                    result_even,
                    pto.f16,
                    full_b32,
                    rnd=pto.VcvtRoundMode.Z,
                    sat=pto.VcvtSatMode.SAT,
                    part=pto.VcvtPartMode.EVEN,
                )
                result16_odd = pto.vcvt(
                    result_odd,
                    pto.f16,
                    full_b32,
                    rnd=pto.VcvtRoundMode.Z,
                    sat=pto.VcvtSatMode.SAT,
                    part=pto.VcvtPartMode.ODD,
                )
                pto.vsts(
                    pto.vor(result16_even, result16_odd, mask16),
                    dst[row, col:],
                    mask16,
                )
