---
name: dispatch
description: Use when the user describes a multi-step feature or refactor and you need to decide whether to handle it solo, dispatch a parallel `/fan-out`, or run a `/worktree-team` planner→generator→reviewer pipeline. Outputs a routing recommendation with the reasoning behind it.
when_to_use: Reach for this before starting any task that may touch 5+ files, has independent sub-tasks worth parallelizing, or carries enough risk to warrant separated planning and review. Do NOT use it as the executor itself — once a route is picked, hand off to `/fan-out` for parallel batches or `/worktree-team` for full pipelines.
disable-model-invocation: true
logical: route classification (single-agent / fan-out / pipeline / tdd-loop) emitted with reason and risk level
---

# /dispatch — Task Decomposition Router

## Decision Matrix

Analyze the task against these criteria:

| Signal | Single Agent | Fan-Out | Pipeline (P/G/R) |
|--------|-------------|---------|-------------------|
| Files touched | 1-3 | 4-15 (similar ops) | 4-15 (different ops) |
| Task type | Bug fix, small feature | Batch migration, bulk refactor | New feature, architecture change |
| Interdependence | High (changes depend on each other) | Low (same operation, different files) | Medium (phases depend on prior phase) |
| Risk | Low | Low-Medium | Medium-High |

## Routing Rules

### Route 1: Single Agent (do it yourself)
- Task touches ≤ 3 files
- Changes are interdependent
- No ambiguity in requirements
- **Action:** Execute directly, no subagents needed

### Route 2: Fan-Out (parallel batch)
- Same operation applied to multiple files
- Changes are independent of each other
- **Action:** Use `/fan-out` to dispatch parallel subagents
- **Sweet spot:** 3-5 parallel agents. More than that is hard to review.

### Route 3: Planner → Generator → Reviewer Pipeline
- New feature or architectural change
- Multiple phases with different concerns
- Higher risk warrants review before completion
- **Action:** Dispatch agents sequentially:
  1. **Planner** (read-only): Explore codebase, identify patterns, propose approach. **Must include a `## Contract` section** with testable criteria and verification method.
  2. **Generator** (read-write): Invoke `/contract` to confirm criteria, then implement based on planner's output.
  3. **Reviewer** (read-only): Check contract compliance first, then challenge the implementation.

## Output Format

```text
DISPATCH RECOMMENDATION:
Route: [Single Agent | Fan-Out | Pipeline]
Reason: <one sentence>
Agent(s): <which agents to use>
Estimated scope: <files/operations count>
Risk level: <low/medium/high>
```

## Known Failure Modes

- **Route picked from file count alone.** Five similar files reading "fan-out" can still be sequential if each step depends on the previous result. Before locking the route, check interdependence, not just count.
- **Pipeline chosen for a one-shot bug fix.** The planner→generator→reviewer round-trip costs ~3× tokens; a 1–3 file fix doesn't earn the overhead. Prefer Single Agent unless the change spans concerns or carries deploy risk.
- **Fan-out with shared mutable state.** Two parallel subagents editing the same file race; both succeed, second overwrites first. The dispatch decision should refuse fan-out when the file list overlaps.
- **LLM fallback non-termination.** When `route-prompt-llm.sh` is in play and disagrees with the shell verdict, the router can flap. Cap with `WORKFLOW_ROUTER_MODE=shell` for deterministic dispatch when investigating.
