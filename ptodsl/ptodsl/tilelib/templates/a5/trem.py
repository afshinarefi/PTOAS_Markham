# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""PTODSL TileLib template for pto.trem."""

import ptodsl.tilelib as pto

from ._math import vmod_i32


@pto.tile_template(
    op="pto.trem",
    target="a5",
    name="template_trem",
    dtypes=[
        ("f32", "f32", "f32", "f32"),
        ("f16", "f16", "f16", "f16"),
        ("i32", "i32", "i32", "i32"),
    ],
)
def template_trem(src0: pto.Tile, src1: pto.Tile, tmp: pto.Tile, dst: pto.Tile):
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape
    for row in range(0, valid_rows, 1):
        remained = valid_cols
        for col in range(0, valid_cols, pto.get_lanes(dtype)):
            mask, remained = pto.make_mask(dtype, remained)
            lhs = pto.vlds(src0[row, col:])
            rhs = pto.vlds(src1[row, col:])
            if pto.constexpr(str(dtype) == "f16"):
                lhs_even = pto.vcvt(lhs, pto.f32, mask, part=pto.VcvtPartMode.EVEN)
                lhs_odd = pto.vcvt(lhs, pto.f32, mask, part=pto.VcvtPartMode.ODD)
                rhs_even = pto.vcvt(rhs, pto.f32, mask, part=pto.VcvtPartMode.EVEN)
                rhs_odd = pto.vcvt(rhs, pto.f32, mask, part=pto.VcvtPartMode.ODD)
                rem_even = pto.vsub(
                    lhs_even,
                    pto.vmul(
                        pto.vtrc(pto.vdiv(lhs_even, rhs_even, mask), mask, rnd="F"),
                        rhs_even,
                        mask,
                    ),
                    mask,
                )
                rem_odd = pto.vsub(
                    lhs_odd,
                    pto.vmul(
                        pto.vtrc(pto.vdiv(lhs_odd, rhs_odd, mask), mask, rnd="F"),
                        rhs_odd,
                        mask,
                    ),
                    mask,
                )
                even = pto.vcvt(
                    rem_even, pto.f16, mask, rnd="Z", sat=pto.VcvtSatMode.SAT,
                    part=pto.VcvtPartMode.EVEN,
                )
                odd = pto.vcvt(
                    rem_odd, pto.f16, mask, rnd="Z", sat=pto.VcvtSatMode.SAT,
                    part=pto.VcvtPartMode.ODD,
                )
                result = pto.vor(even, odd, mask)
            else:
                if pto.constexpr(str(dtype) == "f32"):
                    quotient = pto.vtrc(pto.vdiv(lhs, rhs, mask), mask, rnd="F")
                    result = pto.vsub(lhs, pto.vmul(quotient, rhs, mask), mask)
                else:
                    result = vmod_i32(lhs, rhs, mask)
            if pto.constexpr(str(dtype) in ("f16", "f32")):
                sign_diff = pto.vcmps(
                    pto.vmul(rhs, result, mask), 0.0, mask, "lt"
                )
                result = pto.vsel(pto.vadd(result, rhs, sign_diff), result, sign_diff)
            pto.vsts(result, dst[row, col:], mask)
