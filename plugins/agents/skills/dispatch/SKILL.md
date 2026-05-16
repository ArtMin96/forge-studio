---
name: dispatch
description: Use when the user describes a multi-step feature or refactor and you need to decide whether to handle it solo, dispatch a parallel `/fan-out`, or run a `/worktree-team` planner→generator→reviewer pipeline. Outputs a routing recommendation with the reasoning behind it.
when_to_use: Reach for this before starting any task that may touch 5+ files, has independent sub-tasks worth parallelizing, or carries enough risk to warrant separated planning and review. Do NOT use for executing the dispatched pattern — use `/fan-out` for parallel batches or `/worktree-team` for full pipelines instead.
disable-model-invocation: true
allowed-tools:
  - Read
counterexamples:
  - "Executing the dispatched pattern — use /fan-out or /worktree-team after the route is picked."
  - "A one-line fix or small bug touching ≤2 files — execute directly without routing overhead."
  - "Exploratory questions where no concrete task exists to route."
contract:
  required_outputs:
    - "Routing recommendation block (Route / Reason / Agent(s) / Estimated scope / Risk level)."
  budget: "1 model turn"
  permission_scope: "Read-only on task description"
  completion_conditions:
    - "Exactly one route classification emitted (Single Agent | Fan-Out | Pipeline | TDD-Loop)."
    - "One-sentence reason and risk level included."
  output_paths:
    - "stdout"
scheduling: user describes a task whose scope, file count, or operation type warrants a routing decision before execution
structural:
  - Read the task description and infer file count, operation type, interdependence
  - Apply the dispatch decision matrix (single-agent vs fan-out vs pipeline vs tdd-loop)
  - Emit a route classification with reason and risk level
  - Hand off to the chosen pattern's invocation skill
logical: a single route classification (single-agent | fan-out | pipeline | tdd-loop) is emitted with a one-line reason and a risk-level tag
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

## Reviewer prompt template

When dispatching a reviewer subagent, structure the prompt so the response starts with a 2-line verdict, then evidence, then findings. This survives output truncation: the verdict is always readable even if the tail is cut.

```
Verdict (≤2 lines): ACCEPT | REJECT | NEEDS DISCUSSION
Per-check evidence:
1. <criterion> — <quoted output / file:line>
...
Findings:
[SEVERITY: …] [path:line] Issue: … Impact: … Fix: …
```

## Injecting the active contract

Before constructing any generator or reviewer subagent prompt, run:

```bash
bash plugins/agents/skills/dispatch/scripts/inject-contract.sh
```

If the script prints output, prepend that output verbatim to the subagent's prompt — preserving the `[contract]` header line. This gives the subagent the freshly-written contract block that `contract-reread.sh` produced at SubagentStart time, rather than a potentially compacted in-context copy.

If the script prints nothing (missing or empty `active-contract.md`), proceed without contract injection. This is normal for non-pipeline workflows where no active plan exists.

Why: `contract-reread.sh` fires on every SubagentStart and writes the current plan's `## Contract` section to `.claude/state/active-contract.md` with a fresh mtime. Reading it at dispatch time — rather than recalling from context — guarantees the subagent sees a post-compaction-safe contract per Sprint Contract Protocol (HARNESS_SPEC.md). File-based handoff survives context boundaries; in-context memory does not.

## Known Failure Modes

- **Route picked from file count alone.** Five similar files reading "fan-out" can still be sequential if each step depends on the previous result. Before locking the route, check interdependence, not just count.
- **Pipeline chosen for a one-shot bug fix.** The planner→generator→reviewer round-trip costs ~3× tokens; a 1–3 file fix doesn't earn the overhead. Prefer Single Agent unless the change spans concerns or carries deploy risk.
- **Fan-out with shared mutable state.** Two parallel subagents editing the same file race; both succeed, second overwrites first. The dispatch decision should refuse fan-out when the file list overlaps.
- **LLM fallback non-termination.** When `route-prompt-llm.sh` is in play and disagrees with the shell verdict, the router can flap. Cap with `WORKFLOW_ROUTER_MODE=shell` for deterministic dispatch when investigating.

## Rebuttals

Common rationalizations for shortcutting the routing decision, with rebuttals:

| Excuse | Rebuttal |
|---|---|
| "It's obviously a single-file change — single-agent." | "Obvious" is the most common failure pre-condition. Single-file edits with cross-cutting type or test impact still benefit from pipeline review. The classification cost is one inference; the cost of a wrong route is the whole task. |
| "Fan-out is overkill for 3 files." | Fan-out's value is **isolation**, not parallelism. Three independent files in one context window contaminate each other; three subagents do not. File count is a weak proxy for the right route. |
| "Skip TDD just this once — the requirement is clear." | "Clear" requirements are exactly when TDD is cheapest — the test writes itself. Skipping it forfeits the artifact that proves the requirement was met. |
| "I'll just do it without recording the route." | An undocumented routing decision is unreviewable. The one-line classification with reason is the audit trail; without it, a wrong route looks identical to a right one in retrospect. |
| "Pipeline is too heavy for a refactor." | Pipeline overhead is fixed; refactor risk scales with surface area. Renaming three callers across two files is exactly when the planner→generator→reviewer separation pays off. |
