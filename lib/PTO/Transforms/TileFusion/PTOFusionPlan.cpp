// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// This program is free software, you can redistribute it and/or modify it under the terms and conditions of
// CANN Open Software License Agreement Version 2.0 (the "License").
// Please refer to the License for details. You may not use this file except in compliance with the License.
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
// See LICENSE in the root of the software repository for the full text of the License.

#include "PTO/Transforms/TileFusion/FusionAnalysis.h"
#include "PTO/Transforms/TileFusion/FusionOpSemantics.h"

#include "PTO/IR/PTO.h"
#include "PTO/Transforms/Passes.h"
#include "PTO/Transforms/TemplateAttributes.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/Pass/Pass.h"

#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/Support/raw_ostream.h"

#include <algorithm>
#include <optional>
#include <set>
#include <string>

namespace mlir {
namespace pto {
// Passes.h (included above) pulls in the global GEN_PASS_DECL block, which
// defines GEN_PASS_DECL_FUSIONPLAN and leaves it set.  Undef it before
// re-including the .inc for GEN_PASS_DEF so the options struct is not defined
// twice.
#undef GEN_PASS_DECL_FUSIONPLAN
#define GEN_PASS_DEF_FUSIONPLAN
#include "PTO/Transforms/Passes.h.inc"
} // namespace pto
} // namespace mlir

using namespace mlir;

namespace {

static constexpr llvm::StringLiteral kFusionGroupIdAttr =
    "pto.fusion.group_id";
static constexpr llvm::StringLiteral kFusionOrderAttr = "pto.fusion.order";

using TileOpImplVersion = pto::TemplateCandidateMetadata;

struct PlannedFusionGroup {
  SmallVector<const pto::FusionComputeNode *, 8> members;
};

struct PlanningContext {
  const pto::FusionBlockAnalysis &blockAnalysis;
};

struct PlanningCost {
  int64_t dependencyBenefit = 0;
  int64_t loopMergeBenefit = 0;
  int64_t versionCompatibilityBenefit = 0;
  int64_t liveTilePenalty = 0;
  int64_t vfParameterPenalty = 0;
  int64_t versionPenalty = 0;
  bool rejectedForDynamicShape = false;

  int64_t total() const {
    return dependencyBenefit + loopMergeBenefit +
           versionCompatibilityBenefit - liveTilePenalty -
           vfParameterPenalty - versionPenalty;
  }
};

struct PlannedFusionMember {
  const pto::FusionComputeNode *node = nullptr;
  TileOpImplVersion version;
};

struct PlanningDecision {
  bool accept = false;
  PlanningCost cost;
};

struct GroupState {
  SmallVector<PlannedFusionMember, 8> members;
  DenseSet<unsigned> nodeIds;
  PlanningCost cost;

  bool contains(const pto::FusionComputeNode &node) const {
    return nodeIds.contains(node.id);
  }

  SmallVector<const pto::FusionComputeNode *, 8> getNodes() const {
    SmallVector<const pto::FusionComputeNode *, 8> nodes;
    nodes.reserve(members.size());
    for (const PlannedFusionMember &member : members)
      nodes.push_back(member.node);
    return nodes;
  }

  void append(PlannedFusionMember member, const PlanningCost &appendCost = {}) {
    nodeIds.insert(member.node->id);
    cost.dependencyBenefit += appendCost.dependencyBenefit;
    cost.loopMergeBenefit += appendCost.loopMergeBenefit;
    cost.versionCompatibilityBenefit +=
        appendCost.versionCompatibilityBenefit;
    cost.liveTilePenalty += appendCost.liveTilePenalty;
    cost.vfParameterPenalty += appendCost.vfParameterPenalty;
    cost.versionPenalty += appendCost.versionPenalty;
    cost.rejectedForDynamicShape |= appendCost.rejectedForDynamicShape;
    members.push_back(std::move(member));
  }
};

// Version metadata is not emitted by FusionPlan yet. It is still part of the
// search state so candidate groups can be compared using version traits before
// the final group_id/order annotations are written for downstream passes.
static PlanningCost
computeVersionTraitCost(ArrayRef<PlannedFusionMember> members) {
  static constexpr int64_t kAllOneDimensionalBenefit = 3;
  static constexpr int64_t kMixedLoopDepthPenalty = 2;
  static constexpr int64_t kTailPenalty = 1;
  static constexpr int64_t kPostUpdatePenalty = 2;

  PlanningCost cost;
  if (members.empty())
    return cost;

  bool allOneDimensional = true;
  DenseSet<int64_t> loopDepths;
  for (const PlannedFusionMember &member : members) {
    loopDepths.insert(member.version.loopDepth);
    allOneDimensional &= member.version.loopDepth == 1;
    if (member.version.hasTail)
      cost.versionPenalty += kTailPenalty;
    if (member.version.isPostUpdate)
      cost.versionPenalty += kPostUpdatePenalty;
  }

  if (members.size() > 1 && allOneDimensional)
    cost.versionCompatibilityBenefit += kAllOneDimensionalBenefit;
  if (loopDepths.size() > 1)
    cost.versionPenalty +=
        kMixedLoopDepthPenalty * static_cast<int64_t>(loopDepths.size() - 1);
  return cost;
}

static PlanningCost combineCosts(const PlanningCost &lhs,
                                 const PlanningCost &rhs) {
  PlanningCost cost;
  cost.dependencyBenefit = lhs.dependencyBenefit + rhs.dependencyBenefit;
  cost.loopMergeBenefit = lhs.loopMergeBenefit + rhs.loopMergeBenefit;
  cost.versionCompatibilityBenefit =
      lhs.versionCompatibilityBenefit + rhs.versionCompatibilityBenefit;
  cost.liveTilePenalty = lhs.liveTilePenalty + rhs.liveTilePenalty;
  cost.vfParameterPenalty = lhs.vfParameterPenalty + rhs.vfParameterPenalty;
  cost.versionPenalty = lhs.versionPenalty + rhs.versionPenalty;
  cost.rejectedForDynamicShape =
      lhs.rejectedForDynamicShape || rhs.rejectedForDynamicShape;
  return cost;
}

static PlanningCost computeFinalGroupCost(const GroupState &state) {
  return combineCosts(state.cost, computeVersionTraitCost(state.members));
}

static bool isCurrentlyPlannableOp(StringRef opName) {
  return llvm::StringSwitch<bool>(opName)
      .Cases("tmul", "tdiv", "tadd", "tsub", "tmax", "tmin", true)
      .Cases("tmuls", "tdivs", "tadds", "tsubs", "tmaxs", "tmins", true)
      .Case("texp", true)
      .Case("texpands", true)
      .Cases("trowexpandsub", "trowexpandmul", "trowexpanddiv", true)
      .Cases("trowsum", "trowmax", "trowmin", true)
      .Cases("tcolsum", "tcolmax", "tcolmin", true)
      .Default(false);
}

static bool isProvenIterationDomain(
    const pto::FusionBlockAnalysis &blockAnalysis,
    const pto::FusionComputeNode &node) {
  if (node.iterationDomainClass >= blockAnalysis.iterationDomainClasses.size())
    return false;
  return blockAnalysis.iterationDomainClasses[node.iterationDomainClass]
             .info.proof == pto::IterationDomainProof::Proven;
}

static bool hasHardBoundaryBetween(const pto::FusionComputeNode &a,
                                   const pto::FusionComputeNode &b) {
  const pto::FusionComputeNode &earlier =
      a.blockOrder < b.blockOrder ? a : b;
  const pto::FusionComputeNode &later =
      a.blockOrder < b.blockOrder ? b : a;

  Operation *cursor = earlier.op->getNextNode();
  while (cursor && cursor != later.op) {
    if (cursor->hasTrait<OpTrait::IsTerminator>() ||
        !cursor->getRegions().empty() || isa<CallOpInterface>(cursor))
      return true;
    cursor = cursor->getNextNode();
  }
  return false;
}

static bool hasHardBoundaryToGroup(
    ArrayRef<const pto::FusionComputeNode *> group,
    const pto::FusionComputeNode &candidate) {
  for (const pto::FusionComputeNode *member : group)
    if (hasHardBoundaryBetween(*member, candidate))
      return true;
  return false;
}

static bool dependsOnPreviousNode(
    const pto::FusionBlockAnalysis &blockAnalysis,
    const pto::FusionComputeNode &previous,
    const pto::FusionComputeNode &current) {
  for (unsigned edgeId : current.incomingEdges) {
    if (edgeId >= blockAnalysis.edges.size())
      continue;
    if (blockAnalysis.edges[edgeId].producerNode == previous.id)
      return true;
  }

  for (Value output : previous.semantics.tileOutputs)
    if (llvm::is_contained(current.semantics.tileInputs, output))
      return true;

  return false;
}

static SmallVector<const pto::FusionComputeNode *, 8>
buildStableInGroupOrder(ArrayRef<const pto::FusionComputeNode *> members) {
  SmallVector<const pto::FusionComputeNode *, 8> ordered(members.begin(),
                                                         members.end());
  llvm::stable_sort(ordered, [](const pto::FusionComputeNode *lhs,
                                const pto::FusionComputeNode *rhs) {
    if (lhs->blockOrder != rhs->blockOrder)
      return lhs->blockOrder < rhs->blockOrder;
    return lhs->id < rhs->id;
  });
  return ordered;
}

static SmallVector<PlannedFusionMember, 8>
buildStableInGroupMemberOrder(ArrayRef<PlannedFusionMember> members) {
  SmallVector<PlannedFusionMember, 8> ordered(members.begin(), members.end());
  llvm::stable_sort(ordered, [](const PlannedFusionMember &lhs,
                                const PlannedFusionMember &rhs) {
    if (lhs.node->blockOrder != rhs.node->blockOrder)
      return lhs.node->blockOrder < rhs.node->blockOrder;
    return lhs.node->id < rhs.node->id;
  });
  return ordered;
}

static unsigned getEarliestBlockOrder(ArrayRef<PlannedFusionMember> members) {
  unsigned earliest = ~0u;
  for (const PlannedFusionMember &member : members)
    earliest = std::min(earliest, member.node->blockOrder);
  return earliest;
}

static bool isBetterCandidateGroup(ArrayRef<PlannedFusionMember> lhsMembers,
                                   const PlanningCost &lhsCost,
                                   ArrayRef<PlannedFusionMember> rhsMembers,
                                   const PlanningCost &rhsCost) {
  if (rhsMembers.empty())
    return !lhsMembers.empty();

  if (lhsCost.total() != rhsCost.total())
    return lhsCost.total() > rhsCost.total();

  if (lhsMembers.size() != rhsMembers.size())
    return lhsMembers.size() > rhsMembers.size();

  const unsigned lhsFirstOrder = getEarliestBlockOrder(lhsMembers);
  const unsigned rhsFirstOrder = getEarliestBlockOrder(rhsMembers);
  if (lhsFirstOrder != rhsFirstOrder)
    return lhsFirstOrder < rhsFirstOrder;

  SmallVector<PlannedFusionMember, 8> lhsOrdered =
      buildStableInGroupMemberOrder(lhsMembers);
  SmallVector<PlannedFusionMember, 8> rhsOrdered =
      buildStableInGroupMemberOrder(rhsMembers);
  for (auto [lhsMember, rhsMember] : llvm::zip(lhsOrdered, rhsOrdered)) {
    if (lhsMember.node->id != rhsMember.node->id)
      return lhsMember.node->id < rhsMember.node->id;
    if (lhsMember.version.id != rhsMember.version.id)
      return lhsMember.version.id < rhsMember.version.id;
  }

  return false;
}

static void assignStableGroupMetadata(ArrayRef<PlannedFusionGroup> groups,
                                      MLIRContext *ctx,
                                      int64_t &nextGroupId) {
  SmallVector<const PlannedFusionGroup *, 8> orderedGroups;
  orderedGroups.reserve(groups.size());
  for (const PlannedFusionGroup &group : groups)
    orderedGroups.push_back(&group);

  llvm::stable_sort(orderedGroups, [](const PlannedFusionGroup *lhs,
                                      const PlannedFusionGroup *rhs) {
    const pto::FusionComputeNode *lhsFirst = lhs->members.front();
    const pto::FusionComputeNode *rhsFirst = rhs->members.front();
    if (lhsFirst->blockOrder != rhsFirst->blockOrder)
      return lhsFirst->blockOrder < rhsFirst->blockOrder;
    return lhsFirst->id < rhsFirst->id;
  });

  for (const PlannedFusionGroup *group : orderedGroups) {
    const int64_t groupId = nextGroupId++;
    SmallVector<const pto::FusionComputeNode *, 8> stableOrder =
        buildStableInGroupOrder(group->members);
    for (auto [order, node] : llvm::enumerate(stableOrder)) {
      node->op->setAttr(kFusionGroupIdAttr,
                        IntegerAttr::get(IntegerType::get(ctx, 64), groupId));
      node->op->setAttr(
          kFusionOrderAttr,
          IntegerAttr::get(IntegerType::get(ctx, 64),
                           static_cast<int64_t>(order)));
    }
  }
}

static bool isSupportedPlanningNode(const pto::FusionComputeNode &node) {
  return node.semantics.kind == pto::FusionOpKind::Compute &&
         isCurrentlyPlannableOp(node.semantics.opName);
}

static unsigned
countEdgesFromGroup(const pto::FusionBlockAnalysis &blockAnalysis,
                    ArrayRef<const pto::FusionComputeNode *> group,
                    const pto::FusionComputeNode &candidate) {
  DenseSet<unsigned> producerIds;
  for (const pto::FusionComputeNode *member : group)
    producerIds.insert(member->id);

  unsigned count = 0;
  for (unsigned edgeId : candidate.incomingEdges) {
    if (edgeId >= blockAnalysis.edges.size())
      continue;
    if (producerIds.contains(blockAnalysis.edges[edgeId].producerNode))
      ++count;
  }
  return count;
}

static TileOpImplVersion getDefaultImplVersion() {
  return TileOpImplVersion{/*id=*/0, /*name=*/"default", /*loopDepth=*/2,
                           /*isPostUpdate=*/false, /*hasTail=*/false};
}

// Older tests and manually authored IR often do not carry template candidate
// metadata. Treat those ops as having one neutral implementation so version
// scoring does not perturb existing fusion plans.
static FailureOr<SmallVector<TileOpImplVersion, 4>>
getLegalImplVersions(const pto::FusionComputeNode &node) {
  FailureOr<SmallVector<pto::TemplateCandidateMetadata, 4>> candidates =
      pto::getTemplateCandidateAttrs(node.op);
  if (failed(candidates))
    return failure();
  if (candidates->empty())
    return SmallVector<TileOpImplVersion, 4>{getDefaultImplVersion()};

  SmallVector<TileOpImplVersion, 4> versions;
  versions.reserve(candidates->size());
  for (const pto::TemplateCandidateMetadata &candidate : *candidates)
    versions.push_back(candidate);
  return versions;
}

static FailureOr<SmallVector<GroupState, 4>>
createSeedStates(const pto::FusionComputeNode &seed) {
  FailureOr<SmallVector<TileOpImplVersion, 4>> versions =
      getLegalImplVersions(seed);
  if (failed(versions))
    return failure();

  SmallVector<GroupState, 4> states;
  states.reserve(versions->size());
  for (const TileOpImplVersion &version : *versions) {
    GroupState state;
    state.append(PlannedFusionMember{&seed, version});
    states.push_back(std::move(state));
  }
  return states;
}

struct GroupFootprint {
  unsigned liveTileCount = 0;
  unsigned vfParameterCount = 0;
};

static bool nodesHaveDirectDataFlowConnection(
    const pto::FusionBlockAnalysis &blockAnalysis,
    const pto::FusionComputeNode &lhs, const pto::FusionComputeNode &rhs) {
  for (unsigned edgeId : lhs.outgoingEdges) {
    if (edgeId >= blockAnalysis.edges.size())
      continue;
    if (blockAnalysis.edges[edgeId].consumerNode == rhs.id)
      return true;
  }

  for (unsigned edgeId : lhs.incomingEdges) {
    if (edgeId >= blockAnalysis.edges.size())
      continue;
    if (blockAnalysis.edges[edgeId].producerNode == rhs.id)
      return true;
  }

  for (Value output : lhs.semantics.tileOutputs)
    if (llvm::is_contained(rhs.semantics.tileInputs, output))
      return true;

  for (Value output : rhs.semantics.tileOutputs)
    if (llvm::is_contained(lhs.semantics.tileInputs, output))
      return true;

  return false;
}

static unsigned
countConnectionsToGroup(const pto::FusionBlockAnalysis &blockAnalysis,
                        ArrayRef<const pto::FusionComputeNode *> group,
                        const pto::FusionComputeNode &candidate) {
  unsigned connections = 0;
  for (const pto::FusionComputeNode *member : group)
    if (nodesHaveDirectDataFlowConnection(blockAnalysis, *member, candidate))
      ++connections;
  return connections;
}

static GroupFootprint
computeGroupFootprint(ArrayRef<const pto::FusionComputeNode *> members) {
  DenseSet<Value> producedTiles;
  DenseSet<Value> touchedTiles;
  DenseSet<Value> externalInputs;

  for (const pto::FusionComputeNode *member : members) {
    for (Value output : member->semantics.tileOutputs) {
      producedTiles.insert(output);
      touchedTiles.insert(output);
    }
  }

  for (const pto::FusionComputeNode *member : members) {
    for (Value input : member->semantics.tileInputs) {
      touchedTiles.insert(input);
      if (!producedTiles.contains(input))
        externalInputs.insert(input);
    }
  }

  GroupFootprint footprint;
  footprint.liveTileCount = touchedTiles.size();
  footprint.vfParameterCount = externalInputs.size() + producedTiles.size();
  return footprint;
}

class CostModel {
public:
  virtual ~CostModel() = default;

  virtual PlanningDecision evaluateSeed(const PlanningContext &ctx,
                                        const pto::FusionComputeNode &candidate)
      const = 0;

  virtual PlanningDecision
  evaluateAppend(const PlanningContext &ctx,
                 ArrayRef<const pto::FusionComputeNode *> currentGroup,
                 const pto::FusionComputeNode &candidate) const = 0;
};

class ConservativeGreedyCostModel final : public CostModel {
public:
  PlanningDecision
  evaluateSeed(const PlanningContext &ctx,
               const pto::FusionComputeNode &candidate) const override {
    PlanningDecision decision;
    if (!isSupportedPlanningNode(candidate))
      return decision;

    if (!isProvenIterationDomain(ctx.blockAnalysis, candidate)) {
      decision.cost.rejectedForDynamicShape = true;
      return decision;
    }

    decision.accept = true;
    return decision;
  }

  PlanningDecision
  evaluateAppend(const PlanningContext &ctx,
                 ArrayRef<const pto::FusionComputeNode *> currentGroup,
                 const pto::FusionComputeNode &candidate) const override {
    PlanningDecision seedDecision = evaluateSeed(ctx, candidate);
    if (!seedDecision.accept)
      return seedDecision;

    PlanningDecision decision;
    if (currentGroup.empty()) {
      decision.accept = true;
      return decision;
    }

    const pto::FusionComputeNode &previous = *currentGroup.back();
    const bool sameDomainClass =
        previous.iterationDomainClass == candidate.iterationDomainClass;
    const bool contiguousInBlock =
        candidate.blockOrder == previous.blockOrder + 1;
    const bool directlyDependent =
        dependsOnPreviousNode(ctx.blockAnalysis, previous, candidate);
    if (!sameDomainClass || !contiguousInBlock || !directlyDependent)
      return decision;

    SmallVector<const pto::FusionComputeNode *, 8> proposedGroup(
        currentGroup.begin(), currentGroup.end());
    proposedGroup.push_back(&candidate);
    GroupFootprint footprint = computeGroupFootprint(proposedGroup);

    decision.cost.dependencyBenefit =
        4 * static_cast<int64_t>(
                countEdgesFromGroup(ctx.blockAnalysis, currentGroup, candidate));
    decision.cost.loopMergeBenefit = 2;
    decision.cost.liveTilePenalty =
        std::max<int64_t>(0, static_cast<int64_t>(footprint.liveTileCount) - 4);
    decision.cost.vfParameterPenalty = std::max<int64_t>(
        0, static_cast<int64_t>(footprint.vfParameterCount) - 6);
    decision.accept = decision.cost.total() > 0;
    return decision;
  }
};

static FailureOr<std::optional<GroupState>>
tryAppendVersionedCandidate(const PlanningContext &ctx,
                            const CostModel &costModel,
                            const GroupState &state,
                            const pto::FusionComputeNode &candidate,
                            const TileOpImplVersion &version) {
  if (state.contains(candidate))
    return std::optional<GroupState>{};

  SmallVector<const pto::FusionComputeNode *, 8> currentNodes =
      state.getNodes();
  PlanningDecision appendDecision =
      costModel.evaluateAppend(ctx, currentNodes, candidate);
  if (!appendDecision.accept)
    return std::optional<GroupState>{};

  GroupState nextState = state;
  nextState.append(PlannedFusionMember{&candidate, version},
                   appendDecision.cost);
  return std::optional<GroupState>{std::move(nextState)};
}

static std::string getStateSignature(const GroupState &state) {
  SmallVector<PlannedFusionMember, 8> orderedMembers =
      buildStableInGroupMemberOrder(state.members);

  std::string signature;
  llvm::raw_string_ostream os(signature);
  for (const PlannedFusionMember &member : orderedMembers)
    os << member.node->id << ':' << member.version.id << ';';
  return os.str();
}

static FailureOr<SmallVector<GroupState, 16>>
enumerateVersionedStatesFromSeed(const PlanningContext &ctx,
                                 const CostModel &costModel,
                                 const pto::FusionComputeNode &seed,
                                 const DenseSet<unsigned> &assignedNodes) {
  FailureOr<SmallVector<GroupState, 4>> seedStates = createSeedStates(seed);
  if (failed(seedStates))
    return failure();

  SmallVector<GroupState, 16> validStates;
  SmallVector<GroupState, 16> frontier(seedStates->begin(), seedStates->end());
  std::set<std::string> seenStates;
  for (const GroupState &state : frontier)
    seenStates.insert(getStateSignature(state));

  // Explore all reachable dataflow-connected groups for this seed, not just
  // the first greedy path through block order. The state signature includes the
  // selected implementation version for each node, so the same node set can be
  // scored multiple ways when TileOp template candidates differ.
  while (!frontier.empty()) {
    GroupState state = std::move(frontier.pop_back_val());
    for (const pto::FusionComputeNode &candidate :
         ctx.blockAnalysis.computeNodes) {
      if (assignedNodes.contains(candidate.id) || state.contains(candidate))
        continue;

      FailureOr<SmallVector<TileOpImplVersion, 4>> versions =
          getLegalImplVersions(candidate);
      if (failed(versions))
        return failure();

      for (const TileOpImplVersion &version : *versions) {
        FailureOr<std::optional<GroupState>> maybeNextState =
            tryAppendVersionedCandidate(ctx, costModel, state, candidate,
                                        version);
        if (failed(maybeNextState))
          return failure();
        if (!*maybeNextState)
          continue;

        GroupState nextState = std::move(**maybeNextState);
        std::string signature = getStateSignature(nextState);
        if (!seenStates.insert(signature).second)
          continue;

        if (nextState.members.size() >= 2)
          validStates.push_back(nextState);
        frontier.push_back(std::move(nextState));
      }
    }
  }

  return validStates;
}

static FailureOr<std::optional<GroupState>>
findBestVersionedGroupForSeed(const PlanningContext &ctx,
                              const CostModel &costModel,
                              const pto::FusionComputeNode &seed,
                              const DenseSet<unsigned> &assignedNodes) {
  FailureOr<SmallVector<GroupState, 16>> states =
      enumerateVersionedStatesFromSeed(ctx, costModel, seed, assignedNodes);
  if (failed(states))
    return failure();

  std::optional<GroupState> bestState;
  PlanningCost bestCost;
  for (GroupState &state : *states) {
    PlanningCost finalCost = computeFinalGroupCost(state);
    if (bestState &&
        !isBetterCandidateGroup(state.members, finalCost, bestState->members,
                                bestCost))
      continue;

    state.cost = finalCost;
    bestCost = finalCost;
    bestState = std::move(state);
  }

  return bestState;
}

class ConservativeDAGGreedyCostModel final : public CostModel {
public:
  PlanningDecision
  evaluateSeed(const PlanningContext &ctx,
               const pto::FusionComputeNode &candidate) const override {
    PlanningDecision decision;
    if (!isSupportedPlanningNode(candidate))
      return decision;

    if (!isProvenIterationDomain(ctx.blockAnalysis, candidate)) {
      decision.cost.rejectedForDynamicShape = true;
      return decision;
    }

    decision.accept = true;
    return decision;
  }

  PlanningDecision
  evaluateAppend(const PlanningContext &ctx,
                 ArrayRef<const pto::FusionComputeNode *> currentGroup,
                 const pto::FusionComputeNode &candidate) const override {
    PlanningDecision seedDecision = evaluateSeed(ctx, candidate);
    if (!seedDecision.accept)
      return seedDecision;

    PlanningDecision decision;
    if (currentGroup.empty()) {
      decision.accept = true;
      return decision;
    }

    if (currentGroup.front()->iterationDomainClass !=
        candidate.iterationDomainClass)
      return decision;

    if (hasHardBoundaryToGroup(currentGroup, candidate))
      return decision;

    const unsigned connectionCount =
        countConnectionsToGroup(ctx.blockAnalysis, currentGroup, candidate);
    if (connectionCount == 0)
      return decision;

    SmallVector<const pto::FusionComputeNode *, 8> proposedGroup(
        currentGroup.begin(), currentGroup.end());
    proposedGroup.push_back(&candidate);
    GroupFootprint footprint = computeGroupFootprint(proposedGroup);

    decision.cost.dependencyBenefit = 4 * static_cast<int64_t>(connectionCount);
    decision.cost.loopMergeBenefit = 4;
    decision.cost.liveTilePenalty = std::max<int64_t>(
        0, static_cast<int64_t>(footprint.liveTileCount) - 10);
    decision.cost.vfParameterPenalty = std::max<int64_t>(
        0, static_cast<int64_t>(footprint.vfParameterCount) - 12);
    decision.accept = decision.cost.total() > 0;
    return decision;
  }
};

class StrategyEngine {
public:
  virtual ~StrategyEngine() = default;

  virtual SmallVector<PlannedFusionGroup, 8>
  planBlock(const PlanningContext &ctx, const CostModel &costModel) const = 0;
};

class ConservativeGreedyStrategyEngine final : public StrategyEngine {
public:
  SmallVector<PlannedFusionGroup, 8>
  planBlock(const PlanningContext &ctx,
            const CostModel &costModel) const override {
    SmallVector<PlannedFusionGroup, 8> groups;
    SmallVector<const pto::FusionComputeNode *, 8> chain;

    auto flushChain = [&]() {
      if (chain.size() < 2) {
        chain.clear();
        return;
      }

      PlannedFusionGroup group;
      group.members = chain;
      groups.push_back(std::move(group));
      chain.clear();
    };

    for (const pto::FusionComputeNode &node : ctx.blockAnalysis.computeNodes) {
      PlanningDecision seedDecision = costModel.evaluateSeed(ctx, node);
      if (!seedDecision.accept) {
        flushChain();
        continue;
      }

      if (chain.empty()) {
        chain.push_back(&node);
        continue;
      }

      PlanningDecision appendDecision =
          costModel.evaluateAppend(ctx, chain, node);
      if (!appendDecision.accept) {
        flushChain();
        chain.push_back(&node);
        continue;
      }

      chain.push_back(&node);
    }

    flushChain();
    return groups;
  }
};

class ConservativeDAGGreedyStrategyEngine final : public StrategyEngine {
public:
  SmallVector<PlannedFusionGroup, 8>
  planBlock(const PlanningContext &ctx,
            const CostModel &costModel) const override {
    SmallVector<PlannedFusionGroup, 8> groups;
    DenseSet<unsigned> assignedNodes;

    for (const pto::FusionComputeNode &seed : ctx.blockAnalysis.computeNodes) {
      if (assignedNodes.contains(seed.id))
        continue;

      PlanningDecision seedDecision = costModel.evaluateSeed(ctx, seed);
      if (!seedDecision.accept)
        continue;

      SmallVector<const pto::FusionComputeNode *, 8> groupMembers;
      DenseSet<unsigned> groupNodeIds;
      groupMembers.push_back(&seed);
      groupNodeIds.insert(seed.id);

      bool changed = true;
      while (changed) {
        changed = false;
        for (const pto::FusionComputeNode &candidate :
             ctx.blockAnalysis.computeNodes) {
          if (assignedNodes.contains(candidate.id) ||
              groupNodeIds.contains(candidate.id))
            continue;

          PlanningDecision appendDecision =
              costModel.evaluateAppend(ctx, groupMembers, candidate);
          if (!appendDecision.accept)
            continue;

          groupMembers.push_back(&candidate);
          groupNodeIds.insert(candidate.id);
          changed = true;
        }
      }

      if (groupMembers.size() < 2)
        continue;

      PlannedFusionGroup group;
      group.members = buildStableInGroupOrder(groupMembers);
      groups.push_back(group);
      for (const pto::FusionComputeNode *member : group.members)
        assignedNodes.insert(member->id);
    }

    return groups;
  }
};

static FailureOr<SmallVector<PlannedFusionGroup, 8>>
planBlockVersionAware(const PlanningContext &ctx, const CostModel &costModel) {
  SmallVector<PlannedFusionGroup, 8> groups;
  DenseSet<unsigned> assignedNodes;

  for (const pto::FusionComputeNode &seed : ctx.blockAnalysis.computeNodes) {
    if (assignedNodes.contains(seed.id))
      continue;

    PlanningDecision seedDecision = costModel.evaluateSeed(ctx, seed);
    if (!seedDecision.accept)
      continue;

    FailureOr<std::optional<GroupState>> maybeBestState =
        findBestVersionedGroupForSeed(ctx, costModel, seed, assignedNodes);
    if (failed(maybeBestState))
      return failure();
    if (!*maybeBestState)
      continue;

    GroupState bestState = std::move(**maybeBestState);
    PlannedFusionGroup group;
    for (const PlannedFusionMember &member :
         buildStableInGroupMemberOrder(bestState.members))
      group.members.push_back(member.node);
    groups.push_back(std::move(group));

    for (const pto::FusionComputeNode *member : groups.back().members)
      assignedNodes.insert(member->id);
  }

  return groups;
}

static void clearPlanningAttrs(func::FuncOp func) {
  func.walk([](Operation *op) {
    op->removeAttr(kFusionGroupIdAttr);
    op->removeAttr(kFusionOrderAttr);
  });
}

struct FusionPlanPass : public pto::impl::FusionPlanBase<FusionPlanPass> {
  using pto::impl::FusionPlanBase<FusionPlanPass>::FusionPlanBase;

  FusionPlanPass() = default;

  void runOnOperation() override {
    func::FuncOp func = getOperation();
    if (func.isExternal())
      return;

    clearPlanningAttrs(func);

    // Reuse the shared (analysis-manager-cached) pre-fusion dataflow graph
    // rather than rebuilding it from scratch.  The DFG — compute nodes, edges,
    // liveness, write instances — is identical regardless of whether shape
    // inference is enabled, so it is built once by PreFusionAnalysis and shared
    // with FusionRegionGen via the analysis manager.  Only iteration-domain
    // inference depends on the --enable-shape-inference option, so we run that
    // separable step ourselves on a local copy of the cached graph.
    const pto::PreFusionAnalysis &sharedAnalysis =
        getAnalysis<pto::PreFusionAnalysis>();
    if (!sharedAnalysis.isValid()) {
      signalPassFailure();
      return;
    }
    pto::PreFusionAnalysisResult analysis = sharedAnalysis.getResult();
    if (failed(pto::inferIterationDomainClasses(analysis, enableShapeInference))) {
      signalPassFailure();
      return;
    }

    MLIRContext *ctx = &getContext();
    int64_t nextGroupId = 0;
    ConservativeDAGGreedyCostModel costModel;

    for (const pto::FusionBlockAnalysis &blockAnalysis : analysis.blocks) {
      PlanningContext planningCtx{blockAnalysis};
      FailureOr<SmallVector<PlannedFusionGroup, 8>> groups =
          planBlockVersionAware(planningCtx, costModel);
      if (failed(groups)) {
        signalPassFailure();
        return;
      }
      assignStableGroupMetadata(*groups, ctx, nextGroupId);
    }

    // The fusion metadata we annotate (group_id/order) is a planning *output*;
    // it does not alter tile semantics, operand types, aliasing or liveness,
    // so it cannot invalidate the shared PreFusionAnalysis DFG.  Preserve it so
    // the downstream FusionRegionGen pass reuses the cached graph instead of
    // rebuilding it.
    markAnalysesPreserved<pto::PreFusionAnalysis>();
  }
};

} // namespace

std::unique_ptr<Pass> mlir::pto::createFusionPlanPass() {
  return std::make_unique<FusionPlanPass>();
}

std::unique_ptr<Pass>
mlir::pto::createFusionPlanPass(const pto::FusionPlanOptions &options) {
  return std::make_unique<FusionPlanPass>(options);
}
