// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under the terms and conditions of
// CANN Open Software License Agreement Version 2.0 (the "License").
// Please refer to the License for details. You may not use this file except in compliance with the License.
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
// See LICENSE in the root of the software repository for the full text of the License.

//===---------- SyncSolverCodeGen.cpp ---- Graph Sync Solver --------------===//
//===----------------------------------------------------------------------===//

#include "PTO/Transforms/GraphSyncSolver/SyncSolverCodeGen.h"

#include "PTO/IR/PTO.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "llvm/Support/Casting.h"

using namespace mlir;
using namespace mlir::pto;
using namespace mlir::pto::syncsolver;

static PipeAttr makePipe(MLIRContext *ctx, PIPE pipe) {
  return PipeAttr::get(ctx, pipe);
}

static EventAttr makeEvent(MLIRContext *ctx, int64_t eventId) {
  return EventAttr::get(ctx, static_cast<EVENT>(eventId));
}

static bool isConstantIndexEqualTo(Value value, int64_t expected) {
  if (!value)
    return false;
  if (auto constant = value.getDefiningOp<arith::ConstantIndexOp>())
    return constant.value() == expected;
  if (auto constant = value.getDefiningOp<arith::ConstantOp>()) {
    if (auto intAttr = dyn_cast<IntegerAttr>(constant.getValue()))
      return intAttr.getInt() == expected;
  }
  return false;
}

Operation *CodeGenerator::resolveSyncAnchor(OperationBase *opBase) {
  if (!opBase)
    return nullptr;
  if (auto *ph = dyn_cast<PlaceHolder>(opBase)) {
    if (ph->beforeOp)
      return ph->beforeOp->op;
    if (ph->afterOp)
      return ph->afterOp->op;
    if (ph->block)
      return ph->block->getParentOp();
    return nullptr;
  }
  return opBase->op;
}

Location CodeGenerator::resolveSyncLoc(OperationBase *opBase) {
  if (Operation *anchor = resolveSyncAnchor(opBase))
    return anchor->getLoc();
  return funcOp.getLoc();
}

void CodeGenerator::setInsertionPoint(IRRewriter &rewriter,
                                      OperationBase *opBase,
                                      bool insertAfter) {
  if (auto *ph = dyn_cast_or_null<PlaceHolder>(opBase)) {
    // Block-start placeholder: insert at the very top of the block.
    if (ph->scopeBegin && ph->block) {
      rewriter.setInsertionPointToStart(ph->block);
      return;
    }
    // Block-end placeholder: insert before the terminator if any, otherwise
    // at the end of the block.
    if (ph->scopeEnd && ph->block) {
      if (!ph->block->empty() &&
          ph->block->back().hasTrait<OpTrait::IsTerminator>())
        rewriter.setInsertionPoint(&ph->block->back());
      else
        rewriter.setInsertionPointToEnd(ph->block);
      return;
    }
    // Loop-boundary slot. The placeholder names the linked loop op via
    // beforeOp/afterOp; the side is picked by the `insertAfter` flag, which
    // by the solver's convention agrees with the field that is set.
    OperationBase *linked = ph->beforeOp ? ph->beforeOp : ph->afterOp;
    if (linked && linked->op) {
      if (insertAfter)
        rewriter.setInsertionPointAfter(linked->op);
      else
        rewriter.setInsertionPoint(linked->op);
      return;
    }
    // Malformed placeholder: fall back to the function entry to keep the
    // pass from crashing.
    rewriter.setInsertionPointToStart(&funcOp.getBody().front());
    return;
  }
  Operation *anchor = opBase ? opBase->op : nullptr;
  if (!anchor) {
    rewriter.setInsertionPointToStart(&funcOp.getBody().front());
    return;
  }
  if (insertAfter)
    rewriter.setInsertionPointAfter(anchor);
  else
    rewriter.setInsertionPoint(anchor);
}

void CodeGenerator::emitSyncOp(IRRewriter &rewriter, SyncOp *syncOp) {
  if (auto *barrier = dyn_cast<BarrierOp>(syncOp)) {
    rewriter.create<pto::BarrierOp>(resolveSyncLoc(barrier),
                                    makePipe(rewriter.getContext(),
                                             barrier->pipe));
    return;
  }

  auto *setWait = dyn_cast<SetWaitOp>(syncOp);
  if (!setWait || setWait->eventIds.empty())
    return;

  // The first/last-iter wrapping path (scf.if(isFirstIter/isLastIter) {
  // set/wait }) lives behind the MmadL1 decomposition optimization in the
  // solver, which is currently force-disabled by SyncSolverOptions ctor.
  // If anyone re-enables it, codegen needs a matching update before this
  // assert can be relaxed.
  assert(!setWait->checkFirstIter &&
         "checkFirstIter wrapping not implemented in codegen");
  assert(!setWait->checkLastIter &&
         "checkLastIter wrapping not implemented in codegen");

  if (!setWait->allAtOnce && setWait->eventIdInfo.isMultiBuffer() &&
      emitMultiBufferSetWaitOp(rewriter, setWait))
    return;

  // One set/wait op per assigned event id. The current solver only assigns
  // a single id per node, but the codegen handles multi-id assignments so a
  // future multi-buffer pass can plug in without re-touching this layer.
  auto srcAttr = makePipe(rewriter.getContext(), setWait->pipeSrc);
  auto dstAttr = makePipe(rewriter.getContext(), setWait->pipeDst);
  Location loc = resolveSyncLoc(setWait);
  bool isSet = isa<SetFlagOp>(setWait);
  bool isWait = isa<WaitFlagOp>(setWait);
  for (int64_t eventId : setWait->eventIds) {
    auto eventAttr = makeEvent(rewriter.getContext(), eventId);
    if (isSet)
      rewriter.create<pto::SetFlagOp>(loc, srcAttr, dstAttr, eventAttr);
    else if (isWait)
      rewriter.create<pto::WaitFlagOp>(loc, srcAttr, dstAttr, eventAttr);
  }
}

Value CodeGenerator::getOrCreateLoopCounter(IRRewriter &rewriter,
                                            scf::ForOp forOp,
                                            int64_t eventIdNum, Location loc) {
  auto counterKey = std::make_pair(forOp.getOperation(), eventIdNum);
  auto counterIt = loopCounterCache_.find(counterKey);
  if (counterIt != loopCounterCache_.end())
    return counterIt->second;

  PatternRewriter::InsertionGuard guard(rewriter);
  rewriter.setInsertionPointToStart(forOp.getBody());
  Value iv = forOp.getInductionVar();
  Value normalized = iv;
  if (!isConstantIndexEqualTo(forOp.getLowerBound(), 0))
    normalized = rewriter.create<arith::SubIOp>(loc, normalized,
                                                forOp.getLowerBound());
  if (!isConstantIndexEqualTo(forOp.getStep(), 1))
    normalized =
        rewriter.create<arith::DivUIOp>(loc, normalized, forOp.getStep());
  Value divisor = rewriter.create<arith::ConstantIndexOp>(loc, eventIdNum);
  Value counter = rewriter.create<arith::RemUIOp>(loc, normalized, divisor);
  loopCounterCache_[counterKey] = counter;
  return counter;
}

Value CodeGenerator::getOrCreateEventSelector(
    IRRewriter &rewriter, scf::ForOp forOp,
    const llvm::SmallVector<int64_t> &eventIds, Location loc) {
  assert(eventIds.size() > 1);
  std::vector<int64_t> keyEventIds(eventIds.begin(), eventIds.end());
  auto selectKey = std::make_pair(forOp.getOperation(), keyEventIds);
  auto selectIt = loopEventSelectCache_.find(selectKey);
  if (selectIt != loopEventSelectCache_.end())
    return selectIt->second;

  PatternRewriter::InsertionGuard guard(rewriter);
  Value counter =
      getOrCreateLoopCounter(rewriter, forOp,
                             static_cast<int64_t>(eventIds.size()), loc);
  rewriter.setInsertionPointAfter(counter.getDefiningOp());
  Value selected =
      rewriter.create<arith::ConstantIndexOp>(loc, eventIds.front());
  for (int64_t i = 1, e = static_cast<int64_t>(eventIds.size()); i < e; ++i) {
    Value slot = rewriter.create<arith::ConstantIndexOp>(loc, i);
    Value isSlot = rewriter.create<arith::CmpIOp>(
        loc, arith::CmpIPredicate::eq, counter, slot);
    Value eventId = rewriter.create<arith::ConstantIndexOp>(loc, eventIds[i]);
    selected = rewriter.create<arith::SelectOp>(loc, isSlot, eventId,
                                                selected);
  }

  loopEventSelectCache_[selectKey] = selected;
  return selected;
}

bool CodeGenerator::emitMultiBufferSetWaitOp(IRRewriter &rewriter,
                                             SetWaitOp *setWait) {
  PatternRewriter::InsertionGuard guard(rewriter);
  auto loop = dyn_cast_or_null<scf::ForOp>(
      setWait->eventIdInfo.multibufferLoop.getOperation());
  if (!loop)
    return false;

  int64_t eventIdNum = setWait->eventIdInfo.eventIdNum;
  if (eventIdNum <= 1 ||
      static_cast<int64_t>(setWait->eventIds.size()) < eventIdNum)
    return false;

  llvm::SmallVector<int64_t> eventIds;
  eventIds.reserve(eventIdNum);
  for (int64_t i = 0; i < eventIdNum; ++i)
    eventIds.push_back(setWait->eventIds[i]);

  Location loc = setWait->multiBufferDynAnchor
                     ? setWait->multiBufferDynAnchor->getLoc()
                     : loop.getLoc();
  Value selected = getOrCreateEventSelector(rewriter, loop, eventIds, loc);
  auto srcAttr = makePipe(rewriter.getContext(), setWait->pipeSrc);
  auto dstAttr = makePipe(rewriter.getContext(), setWait->pipeDst);

  bool isSet = isa<SetFlagOp>(setWait);
  bool isWait = isa<WaitFlagOp>(setWait);
  if (!isSet && !isWait)
    return false;

  if (setWait->multiBufferDynAnchor) {
    if (isSet)
      rewriter.setInsertionPointAfter(setWait->multiBufferDynAnchor);
    else
      rewriter.setInsertionPoint(setWait->multiBufferDynAnchor);
  } else if (isSet) {
    Operation *terminator = loop.getBody()->getTerminator();
    if (!terminator)
      return false;
    rewriter.setInsertionPoint(terminator);
  } else {
    rewriter.setInsertionPointAfter(selected.getDefiningOp());
  }

  if (isSet)
    rewriter.create<pto::SetFlagDynOp>(loc, srcAttr, dstAttr, selected);
  else
    rewriter.create<pto::WaitFlagDynOp>(loc, srcAttr, dstAttr, selected);
  return true;
}

void CodeGenerator::emitSyncMap(IRRewriter &rewriter, SyncMap &syncMap,
                                bool insertAfter) {
  for (auto &[opBase, syncOps] : syncMap) {
    setInsertionPoint(rewriter, opBase, insertAfter);
    for (auto &syncOp : syncOps)
      emitSyncOp(rewriter, syncOp.get());
  }
}

void CodeGenerator::generateResultOps() {
  IRRewriter rewriter(funcOp.getContext());
  emitSyncMap(rewriter, syncMapBefore, /*insertAfter=*/false);
  emitSyncMap(rewriter, syncMapAfter, /*insertAfter=*/true);
}
