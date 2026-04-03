---
name: dispatch
description: Analyze a task and recommend agent decomposition level. Routes to single-agent, fan-out, or planner-generator-reviewer pipeline.
disable-model-invocation: true
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
  1. **Planner** (read-only): Explore codebase, identify patterns, propose approach
  2. **Generator** (read-write): Implement based on planner's output
  3. **Reviewer** (read-only): Challenge the implementation, find issues

## Output Format

```
DISPATCH RECOMMENDATION:
Route: [Single Agent | Fan-Out | Pipeline]
Reason: <one sentence>
Agent(s): <which agents to use>
Estimated scope: <files/operations count>
Risk level: <low/medium/high>
```
