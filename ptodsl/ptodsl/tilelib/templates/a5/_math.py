# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""A5 software arithmetic helpers shared by PTODSL TileLib templates."""

import ptodsl.tilelib as pto


@pto.inline_proc
def vmod_i32(vector, divisor, mask):
    """TileLang-compatible signed i32 floor remainder."""
    zero = pto.scalar(0, pto.i32)
    neg_one = pto.scalar(-1, pto.i32)
    false_mask = pto.pset_b32(pto.MaskPattern.ALLF)

    zero_mask = pto.vcmps(divisor, zero, mask, pto.CmpMode.EQ)
    active_mask = pto.pnot(zero_mask, mask)
    abs_x = pto.vbitcast(pto.vabs(vector, active_mask), pto.ui32)
    abs_y = pto.vbitcast(pto.vabs(divisor, active_mask), pto.ui32)
    sign_matches = pto.vcmps(
        pto.vxor(vector, divisor, active_mask),
        zero,
        active_mask,
        pto.CmpMode.GE,
    )

    y_float = pto.vcvt(
        pto.vbitcast(abs_y, pto.i32),
        pto.f32,
        active_mask,
        rnd=pto.VcvtRoundMode.R,
    )
    reciprocal = pto.vdiv(
        pto.vbr(pto.scalar(1.0, pto.f32)),
        y_float,
        active_mask,
    )
    reciprocal_bits = pto.vadds(
        pto.vbitcast(reciprocal, pto.ui32),
        pto.scalar(0x0FFFFFFE, pto.ui32),
        active_mask,
    )

    low_mask, high_mask = pto.pintlv_b32(active_mask, false_mask)
    low_bits, high_bits = pto.vintlv(
        reciprocal_bits,
        pto.vbr(pto.scalar(0, pto.ui32)),
    )
    low_i64 = pto.vcvt(
        pto.vbitcast(low_bits, pto.f32),
        pto.i64,
        low_mask,
        rnd=pto.VcvtRoundMode.F,
        sat=pto.VcvtSatMode.NOSAT,
        part=pto.VcvtPartMode.EVEN,
    )
    high_i64 = pto.vcvt(
        pto.vbitcast(high_bits, pto.f32),
        pto.i64,
        high_mask,
        rnd=pto.VcvtRoundMode.F,
        sat=pto.VcvtSatMode.NOSAT,
        part=pto.VcvtPartMode.EVEN,
    )
    estimate, _ = pto.vdintlv(
        pto.vbitcast(low_i64, pto.ui32),
        pto.vbitcast(high_i64, pto.ui32),
    )
    active_mask, _ = pto.pdintlv_b32(low_mask, high_mask)

    negative_estimate = pto.vcmps(
        pto.vbitcast(reciprocal_bits, pto.f32),
        pto.scalar(0.0, pto.f32),
        active_mask,
        pto.CmpMode.LT,
    )
    estimate = pto.vsel(
        pto.vbr(pto.scalar(0, pto.ui32)),
        estimate,
        negative_estimate,
    )

    correction = pto.vmul(estimate, abs_y, active_mask)
    correction = pto.vbitcast(
        pto.vneg(pto.vbitcast(correction, pto.i32), active_mask),
        pto.ui32,
    )
    _, estimate_high = pto.vmull(estimate, correction, active_mask)
    estimate = pto.vadd(estimate, estimate_high, active_mask)

    _, quotient = pto.vmull(abs_x, estimate, active_mask)
    product = pto.vmul(quotient, abs_y, active_mask)
    remainder_magnitude = pto.vsub(abs_x, product, active_mask)
    for _ in range(0, 2, 1):
        too_large = pto.vcmp(
            remainder_magnitude,
            abs_y,
            active_mask,
            pto.CmpMode.GE,
        )
        remainder_magnitude = pto.vsel(
            pto.vsub(remainder_magnitude, abs_y, active_mask),
            remainder_magnitude,
            too_large,
        )
        quotient = pto.vsel(
            pto.vadds(quotient, pto.scalar(1, pto.ui32), active_mask),
            quotient,
            too_large,
        )

    negative_quotient = pto.vneg(
        pto.vbitcast(quotient, pto.i32),
        active_mask,
    )
    quotient = pto.vsel(
        pto.vbitcast(quotient, pto.i32),
        negative_quotient,
        sign_matches,
    )
    remainder = pto.vsub(
        vector,
        pto.vmul(quotient, divisor, active_mask),
        active_mask,
    )
    nonzero = pto.vcmps(
        pto.vbitcast(remainder_magnitude, pto.i32),
        zero,
        active_mask,
        pto.CmpMode.NE,
    )
    sign_x = pto.vcmps(vector, zero, active_mask, pto.CmpMode.GE)
    sign_y = pto.vcmps(divisor, zero, active_mask, pto.CmpMode.GE)
    needs_floor_fix = pto.pand(
        pto.pxor(sign_x, sign_y, active_mask),
        nonzero,
        active_mask,
    )
    remainder = pto.vsel(
        pto.vadd(divisor, remainder, active_mask),
        remainder,
        needs_floor_fix,
    )
    return pto.vsel(pto.vbr(neg_one), remainder, zero_mask)
