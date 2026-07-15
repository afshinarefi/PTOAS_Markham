# Tile Fusion Version-Aware Planning

## Goal

`PTOFusionPlan.cpp` currently creates fusion groups over `FusionComputeNode`
objects only. The next planner should create and compare groups over:

```text
compute node + selected TileOp implementation version
```

The implementation versions come from the `candidates` metadata attached by
`InsertTemplateAttributes.cpp`. Different versions may have different loop
nests or requirements. For example, a tile op may have a normal 2D
implementation and a specialized 1D implementation when the tile is contiguous.

The planner should:

1. Read legal implementation versions for every plannable tile op.
2. Enumerate valid versioned groups from each seed.
3. Score every valid group with a cost model.
4. Pick the best node group for that seed.
5. Shrink each selected member's `candidates` list to the versions that
   participate in an equally best-scoring assignment for that node group.
6. Insert the selected group into the final group list. A downstream pass still
   makes the final implementation-version choice from the narrowed lists.

Implementation note: version-aware work now lives in the existing
`PTOFusionPlan.cpp` pass. The public fusion-planning entry point remains
`pto-fusion-plan`.

This design intentionally preserves the current block-local greedy assignment:
after a selected group is emitted, its compute nodes are marked assigned and
cannot participate in later seed groups.

## Current Planner

The previous node-only planner used:

```text
ConservativeDAGCostModel
planBlockVersionAware
```

The current group shape is logically:

```text
PlannedFusionGroup
  members: [A, B, C]
```

The active block algorithm is:

```text
assigned = {}

for seed in block.computeNodes:
  if seed is assigned:
    continue
  if seed cannot start a group:
    continue

  group = [seed]

  repeat while group changed:
    for candidate in block.computeNodes:
      if candidate is assigned or already in group:
        continue
      if candidate can append to group:
        group.push(candidate)

  if group.size >= 2:
    emit group
    mark all group nodes assigned
```

Diagram:

```text
Block order:

  A    noise0    B    noise1    C
  |              |              ^
  |              +--------------+
  +-----------------------------+

Current DAG greedy result:

  group 0 = [A, B, C]
  noise0 and noise1 are not grouped
```

## Target Planner Model

The search state must become version-aware:

```text
PlannedFusionGroup
  members:
    A : retained candidate versions [0, 1]
    B : retained candidate versions [2]
    C : retained candidate versions [1, 3]
  cost:
    dependencyBenefit
    loopMergeBenefit
    liveTilePenalty
    vfParameterPenalty
```

During search, each state still contains one exact version per node. This lets
the planner distinguish groups with the same nodes but different
implementations, while retaining every tied best version for later selection:

```text
Group candidate 1:
  A:2D -> B:2D -> C:2D

Group candidate 2:
  A:1D -> B:1D -> C:1D

Group candidate 3:
  A:2D -> B:1D -> C:1D
```

## Template Candidate Metadata

`InsertTemplateAttributes.cpp` attaches legal implementation candidates as:

```text
candidates = [
  {
    id = 0,
    name = "...",
    loop_depth = 2,
    postupdate = 0,
    tail = 0
  },
  {
    id = 1,
    name = "...",
    loop_depth = 1,
    postupdate = 0,
    tail = 0
  }
]
```

The authoritative operation attribute name is:

```text
candidates
```

Both `InsertTemplateAttributes.cpp` and `PTOFusionPlan.cpp` should use the same
constant and parser. The preferred shared home is a focused transform helper,
not the generic transform utilities:

```text
include/PTO/Transforms/TemplateAttributes.h
lib/PTO/Transforms/TemplateAttributes.cpp
```

Suggested shared API:

```cpp
struct TemplateCandidateMetadata {
  int64_t id;
  std::string name;
  int64_t loopDepth;
  bool isPostUpdate;
  bool hasTail;
};

constexpr llvm::StringLiteral kTemplateCandidatesAttr = "candidates";

FailureOr<SmallVector<TemplateCandidateMetadata, 4>>
getTemplateCandidates(Operation *op);
```

`Utils.h`/`Utils.cpp` should stay for broadly reusable transform utilities. The
candidate metadata schema is specific enough that a named helper file makes the
contract clearer and avoids turning `Utils` into a catch-all.

The planner-side representation is:

```cpp
struct TileOpImplVersion {
  int64_t id = 0;
  std::string name;
  int64_t loopDepth = 0;
  bool isPostUpdate = false;
  bool hasTail = false;
};

struct PlannedFusionMember {
  const pto::FusionComputeNode *node = nullptr;
  TileOpImplVersion version;
};

struct PlannedFusionGroup {
  SmallVector<const FusionComputeNode *, 8> members;
  DenseMap<unsigned, SmallVector<TileOpImplVersion, 4>> retainedVersions;
};
```

The first compatibility step is:

```text
If op has candidates:
  use candidate list
If op has no candidates:
  use one default implementation version
```

This keeps existing non-PTODSL tests working while the version-aware planner is
introduced.

## Search State

The new planner should not grow one group per seed. It should grow many partial
group states:

```cpp
struct GroupState {
  SmallVector<PlannedFusionMember, 8> members;
  DenseSet<unsigned> nodeIds;
  PlanningCost cost;
  GroupConstraints constraints;
};
```

`GroupConstraints` can start small and grow as needed:

```text
GroupConstraints
  commonIterationDomainClass
  loopDepth compatibility
  contiguous-layout requirements
  tail handling requirements
```

At the beginning, `GroupConstraints` can be implicit in `tryAppend`. It does not
need to be a full struct until the rules become non-trivial.

## Version-Aware Enumeration

For one seed:

```text
frontier = all legal seed versions
validGroups = {}

while frontier is not empty:
  state = pop(frontier)

  for candidate in block.computeNodes:
    if candidate is already assigned globally:
      continue
    if candidate is already in state:
      continue

    for version in legal versions of candidate:
      next = tryAppend(state, candidate, version)
      if next is invalid:
        continue

      push next into frontier

      if next.members.size >= 2:
        add next to validGroups

best = chooseBestNodeGroup(validGroups)
equallyBest = all states with the best node set and best total cost
retainedVersions = union versions per node across equallyBest
```

The loop belongs inside the current first seed loop in `planBlockVersionAware`:

```text
for seed in block.computeNodes:
  if seed is assigned:
    continue
  if seed cannot start a group:
    continue

  old:
    greedily grow one node-only group

  new:
    enumerate many versioned group states from this seed
    choose the best node group by cost
    retain every version participating in an equally scored state for that
      node group
    emit the selected node group and narrowed candidate lists
```

Concrete skeleton:

```cpp
for (const FusionComputeNode &seed : ctx.blockAnalysis.computeNodes) {
  if (assignedNodes.contains(seed.id))
    continue;

  if (!costModel.evaluateSeed(ctx, seed).accept)
    continue;

  FailureOr<SmallVector<GroupState, 8>> groupsForSeed =
      enumerateGroupsForSeed(ctx, costModel, seed, assignedNodes);
  if (failed(groupsForSeed) || groupsForSeed->empty())
    continue;

  GroupState best = chooseBestGroup(*groupsForSeed);
  groups.push_back(toPlannedFusionGroup(best));

  for (const PlannedFusionMember &member : best.members)
    assignedNodes.insert(member.node->id);
}
```

Diagram:

```text
                       seed A
                         |
          --------------------------------
          |                              |
        A:2D                           A:1D
          |                              |
     -------------                 -------------
     |           |                 |           |
  +B:2D       +B:1D             +B:2D       +B:1D
     |           |                 |           |
 [A:2D,      [A:2D,            reject      [A:1D,
  B:2D]       B:1D]                        B:1D]
     |           |                             |
  +C:2D      reject                         +C:1D
     |                                         |
 [A:2D, B:2D, C:2D]                    [A:1D, B:1D, C:1D]
```

The planner compares every valid group:

```text
candidate groups:

  G0 = [A:2D, B:2D]          cost = 12
  G1 = [A:2D, B:2D, C:2D]    cost = 15
  G2 = [A:1D, B:1D]          cost = 18
  G3 = [A:1D, B:1D, C:1D]    cost = 16

choose G2
```

Important: the planner must keep non-terminal groups. The best group is not
necessarily the largest group.

```text
[A, B]        cost = 20
[A, B, C]     cost = 14
[A, B, C, D]  cost = -2

Best group is [A, B], not the maximal group.
```

## Exhaustiveness

For one seed, all possible groups have been found when:

```text
No partial group state in the frontier can append any unassigned candidate
node with any legal implementation version.
```

The search is finite because:

```text
1. A state cannot contain the same compute node twice.
2. Every append increases state.members.size.
3. state.members.size <= number of compute nodes in the block.
4. Each node has a finite candidate version list.
```

Diagram:

```text
frontier level 0:
  [A:v0]
  [A:v1]

frontier level 1:
  [A:v0, B:v0]
  [A:v0, B:v1]
  [A:v1, C:v0]

frontier level 2:
  [A:v0, B:v0, C:v0]

frontier level 3:
  empty

At empty frontier:
  enumeration for seed A is complete.
```

## Append Rules

The existing DAG append rules remain the base legality checks:

```text
candidate is supported
candidate has proven iteration domain
candidate has same iterationDomainClass as the group
no hard boundary exists between candidate and any member
candidate has direct data-flow connection to the group
cost total is profitable
```

Version-aware append adds rules such as:

```text
candidate version is legal for candidate op
candidate version is compatible with existing group versions
candidate version satisfies required tile layout or contiguity constraints
candidate version does not break loop-depth compatibility
candidate version has acceptable tail/postupdate behavior
```

The first version-aware implementation can keep the existing node-only
`CostModel::evaluateAppend` as the base check and layer version checks around
it:

```text
tryAppend(state, candidate, candidateVersion):
  currentNodes = nodes(state.members)

  if base evaluateAppend(currentNodes, candidate) rejects:
    reject

  if candidateVersion is not compatible with state constraints:
    reject

  next = state + candidate:version
  next.cost = computeVersionAwareCost(next)
  accept next
```

This keeps the existing dynamic-shape, hard-boundary, iteration-domain, and
data-flow behavior intact while version-specific rules are added incrementally.

Base data-flow diagram:

```text
Accepted:

  A produces %x
       |
       v
  B consumes %x

  [A:*] + B:* can be considered

Rejected:

  A produces %x       C produces %y
       |                   |
       v                   v
  B consumes %x       D consumes %y

  [A:*, B:*] + C:* has no direct connection
```

Hard-boundary diagram:

```text
Accepted:

  A
  pure/simple op
  B

Rejected:

  A
  call / region op / terminator
  B
```

## Cost Model Direction

The current DAG cost is:

```text
dependencyBenefit = 4 * connectionCount
loopMergeBenefit  = 4
liveTilePenalty   = max(0, liveTileCount - 10)
vfParameterPenalty= max(0, vfParameterCount - 12)

accept if:
  dependencyBenefit + loopMergeBenefit
  - liveTilePenalty - vfParameterPenalty > 0
```

Version-aware cost should extend this with implementation-specific terms:

```text
versionLoopBenefit
  reward compatible loop depths or 1D loop merging

layoutBenefit
  reward contiguous layouts when a 1D implementation is selected

tailPenalty
  penalize versions with tail handling if other choices avoid it

postUpdatePenalty
  penalize post-update versions when they complicate fusion

versionMismatchPenalty
  penalize groups mixing incompatible loop forms
```

Example:

```text
Group A:
  A:2D, B:2D
  base cost = 12
  version cost = 0
  total = 12

Group B:
  A:1D, B:1D
  base cost = 12
  versionLoopBenefit = 8
  total = 20

Group C:
  A:1D, B:2D
  base cost = 12
  versionMismatchPenalty = 6
  total = 6
```

## Group Selection

For each seed:

```text
allGroups = enumerateGroupsForSeed(seed)
best = min/max by cost model objective
equallyBest = states with the same node set and total cost as best
emit best node group and the union of its equallyBest versions
mark best node ids assigned
```

The existing global behavior remains greedy:

```text
Once a group is selected, its nodes are assigned.
Later seeds cannot reuse those nodes.
```

Tie-breaking should be deterministic so tests are stable:

```text
1. higher total cost
2. larger member count
3. earlier first member blockOrder
4. lower lexicographic member node ids
5. lower lexicographic version ids
```

This is not globally optimal across the whole block, but it preserves the
current planner architecture and keeps the first version-aware implementation
small.

Diagram:

```text
Block nodes:

  A -> B -> C -> D

Seed A alternatives:
  G0 = [A:v0, B:v0]          cost 10
  G1 = [A:v1, B:v1, C:v1]    cost 18  <-- choose

assigned = {A, B, C}

Seed B:
  skipped, already assigned

Seed C:
  skipped, already assigned

Seed D:
  no size >= 2 group
```

## Pruning

The exact enumeration can grow quickly:

```text
number of states roughly grows with:
  node choices * version choices * append order choices
```

Start exact first. Add pruning only after correctness is clear.

Safe first pruning:

```text
For the same member node set:
  keep only states that are not dominated.
```

Dominance means:

```text
State X dominates State Y if:
  same member node ids
  X has no worse cost
  X has equivalent or less restrictive constraints
  X has at least the same future append capability
```

If future append capability is hard to prove, do not prune aggressively.

Heuristic later:

```text
beam size per seed
maximum group size
maximum versions per op
minimum cost threshold
```

These are useful, but they make the search non-exhaustive.

## Staged Implementation Plan

### Step 1: Shared metadata helper

Create the shared metadata contract:

```text
include/PTO/Transforms/TemplateAttributes.h
lib/PTO/Transforms/TemplateAttributes.cpp
```

Move the candidate struct, attr name, parser, and builder there so both
`InsertTemplateAttributes.cpp` and `PTOFusionPlan.cpp` consume one schema.

Diagram:

```text
Before:

  InsertTemplateAttributes.cpp owns CandidateMetadata
  PTOFusionPlan.cpp owns TileOpImplVersion parser

After:

  TemplateAttributes.h/.cpp owns candidate schema
       ^                                  ^
       |                                  |
  InsertTemplateAttributes.cpp       PTOFusionPlan.cpp
```

### Step 2: Version-aware group data

Done conceptually:

```text
PlannedFusionMember = FusionComputeNode* + TileOpImplVersion
PlannedFusionGroup  = members + PlanningCost
```

Short-term compatibility:

```text
Old algorithms still build node-only groups internally.
Before emitting a PlannedFusionGroup, wrap each node with the first legal
version or default version.
```

### Step 3: Read legal versions

Add helpers:

```text
getDefaultImplVersion()
getLegalImplVersions(node)
```

Behavior:

```text
if candidates attr exists:
  parse candidates into TileOpImplVersion list
else:
  return [default version]
```

### Step 4: Make existing planner compile with versioned members

Bridge old raw-node paths:

```text
raw nodes:
  [A, B, C]

wrapped members:
  [A:firstOrDefault, B:firstOrDefault, C:firstOrDefault]
```

Update metadata assignment:

```text
member.node->op->setAttr(pto.fusion.group_id, ...)
member.node->op->setAttr(pto.fusion.order, ...)
```

### Step 5: Add GroupState

Introduce a separate state for enumeration:

```text
GroupState
  members
  nodeIds
  cost
  constraints
```

Keep `PlannedFusionGroup` as the final emitted result.

### Step 6: Add version-aware seed initialization

Current:

```text
group = [seed]
```

New:

```text
frontier = []
for seedVersion in getLegalImplVersions(seed):
  frontier.push([seed:seedVersion])
```

### Step 7: Add version-aware append

Current:

```text
evaluateAppend(currentGroupNodes, candidate)
```

New:

```text
tryAppend(currentState, candidate, candidateVersion)
```

It should check:

```text
existing DAG legality
version compatibility
updated group footprint
updated cost
```

### Step 8: Enumerate all groups for a seed

Add:

```text
enumerateGroupsForSeed(ctx, costModel, seed, assignedNodes)
```

Return:

```text
SmallVector<GroupState>
```

containing every valid group with size >= 2.

### Step 9: Choose the best node group and retain ties

Add:

```text
chooseBestGroup(ArrayRef<GroupState>)
```

After selecting the winning node group, collect all states with that same node
set and total score. For each member, retain the candidate versions appearing
in any of those equally scored states. Versions with a lower score are removed.

Initial tie-breakers:

```text
1. higher total cost
2. larger member count
3. earlier first blockOrder
4. stable lexicographic version id order
```

### Step 10: Preserve downstream metadata contract

The downstream passes still consume:

```text
pto.fusion.group_id
pto.fusion.order
```

FusionPlan narrows the existing `candidates` array but does not choose one final
version. Candidate order remains stable, so later passes can apply their own
selection policy to the surviving candidates. A separate version attribute is
needed only if a later pass must record one final choice. Potential attr:

```text
pto.fusion.impl_version = candidate id
```

Do not add this until a downstream pass makes and needs to record that final
choice.

### Step 11: Tests

Add focused tests:

```text
1. Missing candidates uses default version and preserves existing grouping.
2. Equally scored candidates are retained deterministically while lower-scored
   candidates are removed.
3. 1D-compatible chain prefers 1D versions.
4. Mixed incompatible versions are rejected or penalized.
5. Non-terminal group can beat a larger terminal group.
6. Interleaved join still groups connected ops and ignores unrelated ops.
7. Dynamic-shape and hard-boundary negatives still hold.
```

## Open Questions

1. Should missing `candidates` mean default version or no fusion?
2. Which downstream pass makes the final choice among retained versions?
3. Should version id be written as an IR attr immediately?
4. Is the objective maximum benefit or minimum estimated runtime?
5. Which version constraints are hard legality and which are soft cost terms?
6. Is greedy global assignment good enough, or do we eventually need block-level
   global optimization?

## Summary Diagram

```text
InsertTemplateAttributes
        |
        | attaches candidates attr
        v
Tile ops with legal versions
        |
        v
PreFusionAnalysis DFG
        |
        v
FusionPlan
  for each seed:
    enumerate versioned group states
    score every valid state
    choose best node group
    retain all equally best candidate versions
    emit group_id/order and narrowed candidates
        |
        v
OpScheduling
        |
        v
FusionRegionGen
        |
        v
Lowering / codegen
```
