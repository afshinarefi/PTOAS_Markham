# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Shared A5 binary elementwise TileLib helpers.

This mirrors the pto-isa ``TBinOp`` shape at the PTODSL template level: op-specific
templates provide the vector instruction (``pto.vadd``, ``pto.vmul``, ...), while this
module owns the variant dispatch and traversal skeletons.
"""

import ptodsl.tilelib as pto

VFIMPL_1D_NO_POST_UPDATE = "1d_no_post_update"
VFIMPL_2D_NO_POST_UPDATE = "2d_no_post_update"
VFIMPL_1D_POST_UPDATE = "1d_post_update"
VFIMPL_2D_POST_UPDATE = "2d_post_update"


def is_single_row_tile(src0: pto.Tile, src1: pto.Tile, dst: pto.Tile):
    """Trace-time shape check for the basic 1D tile-slice implementation."""
    return src0.shape[0] == 1 and src1.shape[0] == 1 and dst.shape[0] == 1


def has_tail(operand_sizes, **_):
    # Placeholder until this matches the final binop tail rule.
    return operand_sizes[0] % 8 != 0


def BinaryInstr(dst: pto.Tile, src0: pto.Tile, src1: pto.Tile, op, version):
    """Dispatch a binary TileOp implementation variant, mirroring pto-isa BinaryInstr."""
    if version == VFIMPL_1D_NO_POST_UPDATE:
        TBinOps_1D_NoPostUpdate(dst, src0, src1, op)
    elif version == VFIMPL_2D_NO_POST_UPDATE:
        TBinOps_2D_NoPostUpdate(dst, src0, src1, op)
    elif version == VFIMPL_1D_POST_UPDATE:
        TBinOps_1D_PostUpdate(dst, src0, src1, op)
    elif version == VFIMPL_2D_POST_UPDATE:
        TBinOps_2D_PostUpdate(dst, src0, src1, op)
    else:
        if is_single_row_tile(src0, src1, dst):
            TBinOps_1D_NoPostUpdate(dst, src0, src1, op)
        else:
            TBinOps_2D_NoPostUpdate(dst, src0, src1, op)


def TBinOps_1D_NoPostUpdate(dst: pto.Tile, src0: pto.Tile, src1: pto.Tile, op):
    """Emit a basic single-row no-post-update binary op."""
    dtype = dst.element_type
    _, valid_cols = dst.valid_shape
    lanes = pto.get_lanes(dtype)

    col_loop = pto.for_(0, valid_cols, step=lanes).carry(remained=valid_cols)
    with col_loop:
        col = col_loop.iv
        mask, remained = pto.make_mask(dtype, col_loop.remained)
        vreg0 = pto.vlds(src0[0, col:])
        vreg1 = pto.vlds(src1[0, col:])
        vreg2 = op.BinInstr(vreg0, vreg1, mask)
        pto.vsts(vreg2, dst[0, col:], mask)
        col_loop.update(remained=remained)


def TBinOps_1D_PostUpdate(dst: pto.Tile, src0: pto.Tile, src1: pto.Tile, op):
    """Placeholder post-update 1D variant; currently emits the no-post-update body."""
    TBinOps_1D_NoPostUpdate(dst, src0, src1, op)


def TBinOps_2D_NoPostUpdate(dst: pto.Tile, src0: pto.Tile, src1: pto.Tile, op):
    """Emit the generic row/column no-post-update binary op."""
    dtype = dst.element_type
    valid_rows, valid_cols = dst.valid_shape
    lanes = pto.get_lanes(dtype)

    with pto.for_(0, valid_rows, step=1) as row:
        col_loop = pto.for_(0, valid_cols, step=lanes).carry(remained=valid_cols)
        with col_loop:
            col = col_loop.iv
            mask, remained = pto.make_mask(dtype, col_loop.remained)
            vreg0 = pto.vlds(src0[row, col:])
            vreg1 = pto.vlds(src1[row, col:])
            vreg2 = op.BinInstr(vreg0, vreg1, mask)
            pto.vsts(vreg2, dst[row, col:], mask)
            col_loop.update(remained=remained)


def TBinOps_2D_PostUpdate(dst: pto.Tile, src0: pto.Tile, src1: pto.Tile, op):
    """Placeholder post-update 2D variant; currently emits the no-post-update body."""
    TBinOps_2D_NoPostUpdate(dst, src0, src1, op)


__all__ = [
    "is_single_row_tile",
    "has_tail",
    "BinaryInstr",
    "TBinOps_1D_NoPostUpdate",
    "TBinOps_1D_PostUpdate",
    "TBinOps_2D_NoPostUpdate",
    "TBinOps_2D_PostUpdate",
    "VFIMPL_1D_NO_POST_UPDATE",
    "VFIMPL_2D_NO_POST_UPDATE",
    "VFIMPL_1D_POST_UPDATE",
    "VFIMPL_2D_POST_UPDATE",
]
