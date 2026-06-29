# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Shared PTODSL implementation for column argmax/argmin."""

import ptodsl.tilelib as pto


DTYPE_SIGNATURES = [
    ("ui8", "ui8", "i32"),
    ("i8", "i8", "i32"),
    ("f16", "f16", "i32"),
    ("ui16", "ui16", "i32"),
    ("f32", "f32", "i32"),
    ("ui32", "ui32", "i32"),
]


def validate(
    src_valid_shape=(),
    dst_valid_shape=(),
    src_config=None,
    tmp_config=None,
    dst_config=None,
    src_dtype=None,
    tmp_dtype=None,
    **_,
):
    configs = (src_config, tmp_config, dst_config)
    return (
        all(config is not None for config in configs)
        and all(config.b_layout == pto.BLayout.ROW_MAJOR for config in configs)
        and all(config.s_layout == pto.SLayout.NONE_BOX for config in configs)
        and dst_valid_shape[0] == 1
        and src_dtype == tmp_dtype
    )


def _select(new_value, old_value, mask, is_max):
    if pto.constexpr(is_max):
        return pto.vmax(old_value, new_value, mask)
    return pto.vmin(old_value, new_value, mask)


def _compare(new_value, old_value, mask, is_max):
    if pto.constexpr(is_max):
        return pto.vcmp(new_value, old_value, mask, "gt")
    return pto.vcmp(new_value, old_value, mask, "lt")


@pto.inline_proc
def column_arg(src, dst, is_max):
    valid_rows, valid_cols = src.valid_shape
    src_dtype = src.element_type

    if pto.constexpr(str(src_dtype) in ("f32", "ui32")):
        lanes = pto.get_lanes(pto.f32)
        remained = valid_cols
        for col in range(0, valid_cols, lanes):
            full_mask = pto.make_mask(pto.f32, pto.MaskPattern.ALL)
            mask, remained = pto.make_mask(pto.f32, remained)
            old_index = pto.vdup(pto.scalar(0, pto.i32), mask)
            new_index = pto.vdup(pto.scalar(0, pto.i32), mask)
            old_value = pto.vlds(src[0, col:])
            for row in range(1, valid_rows, 1):
                new_index = pto.vadds(new_index, pto.scalar(1, pto.i32), mask)
                new_value = pto.vlds(src[row, col:])
                select = _compare(new_value, old_value, full_mask, is_max)
                old_index = pto.vsel(new_index, old_index, select)
                old_value = _select(new_value, old_value, mask, is_max)
            pto.vsts(old_index, dst[0, col:], mask)

    elif pto.constexpr(str(src_dtype) in ("f16", "ui16")):
        lanes16 = pto.get_lanes(pto.f16)
        lanes32 = pto.get_lanes(pto.i32)
        full_mask = pto.make_mask(pto.f16, pto.MaskPattern.ALL)
        for col in range(0, valid_cols, lanes16):
            remained = valid_cols - col
            mask16, _ = pto.make_mask(pto.f16, remained)
            mask32_0, remained = pto.make_mask(pto.i32, remained)
            mask32_1, _ = pto.make_mask(pto.i32, remained)
            old_index = pto.vdup(pto.scalar(0, pto.i16), mask16)
            new_index = pto.vdup(pto.scalar(0, pto.i16), mask16)
            old_value = pto.vlds(src[0, col:])
            for row in range(1, valid_rows, 1):
                new_index = pto.vadds(new_index, pto.scalar(1, pto.i16), mask16)
                new_value = pto.vlds(src[row, col:])
                select = _compare(new_value, old_value, full_mask, is_max)
                old_index = pto.vsel(new_index, old_index, select)
                old_value = _select(new_value, old_value, mask16, is_max)
            even = pto.vcvt(old_index, pto.i32, full_mask, part=pto.VcvtPartMode.EVEN)
            odd = pto.vcvt(old_index, pto.i32, full_mask, part=pto.VcvtPartMode.ODD)
            low, high = pto.vintlv(even, odd)
            pto.vsts(low, dst[0, col:], mask32_0)
            pto.vsts(high, dst[0, col + lanes32:], mask32_1)

    else:
        lanes8 = pto.get_lanes(src_dtype)
        lanes32 = pto.get_lanes(pto.i32)
        if pto.constexpr(str(src_dtype) == "ui8"):
            intermediate = pto.ui16
            final_dtype = pto.ui32
        else:
            intermediate = pto.i16
            final_dtype = pto.i32
        full8 = pto.make_mask(src_dtype, pto.MaskPattern.ALL)
        full16 = pto.make_mask(intermediate, pto.MaskPattern.ALL)
        for col in range(0, valid_cols, lanes8):
            remained = valid_cols - col
            mask0, remained = pto.make_mask(pto.i32, remained)
            mask1, remained = pto.make_mask(pto.i32, remained)
            mask2, remained = pto.make_mask(pto.i32, remained)
            mask3, _ = pto.make_mask(pto.i32, remained)
            old_even = pto.vdup(pto.scalar(0, intermediate), full16)
            old_odd = pto.vdup(pto.scalar(0, intermediate), full16)
            new_even = pto.vdup(pto.scalar(0, intermediate), full16)
            new_odd = pto.vdup(pto.scalar(0, intermediate), full16)
            old = pto.vlds(src[0, col:])
            value_even = pto.vcvt(old, intermediate, full8, part=pto.VcvtPartMode.EVEN)
            value_odd = pto.vcvt(old, intermediate, full8, part=pto.VcvtPartMode.ODD)
            for row in range(1, valid_rows, 1):
                new_even = pto.vadds(new_even, pto.scalar(1, intermediate), full16)
                new_odd = pto.vadds(new_odd, pto.scalar(1, intermediate), full16)
                new = pto.vlds(src[row, col:])
                current_even = pto.vcvt(
                    new, intermediate, full8, part=pto.VcvtPartMode.EVEN
                )
                current_odd = pto.vcvt(
                    new, intermediate, full8, part=pto.VcvtPartMode.ODD
                )
                select_even = _compare(current_even, value_even, full16, is_max)
                select_odd = _compare(current_odd, value_odd, full16, is_max)
                old_even = pto.vsel(new_even, old_even, select_even)
                old_odd = pto.vsel(new_odd, old_odd, select_odd)
                value_even = _select(current_even, value_even, full16, is_max)
                value_odd = _select(current_odd, value_odd, full16, is_max)

            index0, index1 = pto.vintlv(old_even, old_odd)
            even = pto.vcvt(index0, final_dtype, full16, part=pto.VcvtPartMode.EVEN)
            odd = pto.vcvt(index0, final_dtype, full16, part=pto.VcvtPartMode.ODD)
            out0, out1 = pto.vintlv(even, odd)
            pto.vsts(pto.vbitcast(out0, pto.i32), dst[0, col:], mask0)
            pto.vsts(pto.vbitcast(out1, pto.i32), dst[0, col + lanes32:], mask1)
            even = pto.vcvt(index1, final_dtype, full16, part=pto.VcvtPartMode.EVEN)
            odd = pto.vcvt(index1, final_dtype, full16, part=pto.VcvtPartMode.ODD)
            out0, out1 = pto.vintlv(even, odd)
            pto.vsts(pto.vbitcast(out0, pto.i32), dst[0, col + 2 * lanes32:], mask2)
            pto.vsts(pto.vbitcast(out1, pto.i32), dst[0, col + 3 * lanes32:], mask3)
