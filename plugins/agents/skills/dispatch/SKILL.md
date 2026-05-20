---
name: dispatch
description: Use when the user describes a multi-step feature or refactor and you need to decide whether to handle it solo, dispatch a parallel `/fan-out`, or run a `/worktree-team` planner→generator→reviewer pipeline. Outputs a routing recommendation with the reasoning behind it.
when_to_use: Reach for this before starting any task that may touch 5+ files, has independent sub-tasks worth parallelizing, or carries enough risk to warrant separated planning and review. After the planner phase, dispatch also scales the reviewer pool adaptively (N≥3 independent files → N parallel reviewers, capped at 5). Do NOT use for executing the dispatched pattern — use `/fan-out` for parallel batches or `/worktree-team` for full pipelines instead. Do NOT spawn a pool for mutually coupled files where review must consider all files together — use a single reviewer.
disable-model-invocation: true
allowed-tools:
  - Read
counterexamples:
  - "Executing the dispatched pattern — use /fan-out or /worktree-team after the route is picked."
  - "A one-line fix or small bug touching ≤2 files — execute directly without routing overhead."
  - "Exploratory questions where no concrete task exists to route."
  - "Non-independent file work (mutual coupling means review must consider all files together — use single reviewer)."
contract:
  required_outputs:
    - "Routing recommendation block (Route / Reason / Agent(s) / Estimated scope / Risk level)."
    - "Reviewer pool decision block when running the Pipeline route (pool_size, files, decision_reason)."
  budget: "1 model turn"
  permission_scope: "Read-only on task description"
  completion_conditions:
    - "Exactly one route classification emitted (Single Agent | Fan-Out | Pipeline | TDD-Loop)."
    - "One-sentence reason and risk level included."
    - "Pool decision logged to .claude/handoffs.jsonl when pipeline route is chosen."
  output_paths:
    - "stdout"
scheduling: user describes a task whose scope, file count, or operation type warrants a routing decision before execution; or a planner output arrives and reviewer pool size must be decided
structural:
  - Read the task description and infer file count, operation type, interdependence
  - Apply the dispatch decision matrix (single-agent vs fan-out vs pipeline vs tdd-loop)
  - Emit a route classification with reason and risk level
  - When pipeline route: parse planner output for explicitly enumerated independent files; decide pool size; log decision; dispatch reviewers
  - Hand off to the chosen pattern's invocation skill
logical: a single route classification (single-agent | fan-out | pipeline | tdd-loop) is emitted with a one-line reason and a risk-level tag; reviewer pool size matches planner's declared file count (capped at 5)
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

## Adaptive Reviewer Pool

After the planner subagent finishes, scan its output for explicitly enumerated independent files before dispatching reviewers. "Independent" is the planner's call to declare — dispatch counts what the planner lists, it does not infer independence from file content.

### Parsing planner output for independent files

Look for any of these markers in the planner's output:

1. **Numbered list with file paths** — lines matching `^\d+\. .*(\.py|\.sh|\.md|\.json|\.ts|\.js)`.
2. **Explicit FILES: block** — lines following a `FILES:` or `## Files` heading, each starting with `- ` or a path.
3. **Markdown task list** — lines matching `^- \[ \] .*path.*` that name distinct file paths.

Count only paths from the planner's explicit enumeration. If the planner describes work in prose without a list, treat file count as 0 and fall through to single-reviewer behavior.

### Pool size decision

```
N = count of explicitly enumerated independent files (as listed by planner)
N = min(N, 5)   ← hard cap; context overhead at 6+ reviewers outweighs coverage gain

if N >= 3:
    dispatch N reviewer subagents in parallel (one Agent tool call per file, with target_file: <path>)
    dispatch 1 aggregator reviewer (sees all N individual findings, no target_file)
else:
    dispatch 1 reviewer (current behavior, no target_file needed)
```

The cap is enforced in the pool decision, not just documented. If the planner enumerates 8 files, dispatch 5 reviewers + 1 aggregator covering files 1–5; note the cap in the handoff log.

### Dispatcher prompt for a pooled reviewer

```
You are reviewer-<N> in a parallel review pool. Review only the file assigned to you.
target_file: <path>
Scope your review to <path> and its direct callers or tests that import it.
Do not re-review files assigned to sibling reviewers.
Emit your findings in the standard reviewer format (Verdict, per-check evidence, findings).
```

### Aggregator reviewer role

The aggregator receives all individual reviewer findings (not the original code) and has a distinct job from per-file reviewers:

- **Merge** findings across files, deduplicating identical issues reported by multiple reviewers.
- **Surface inter-file inconsistencies** — a type declared in `a.py` but used incorrectly in `b.py` that no single reviewer saw because each scoped to one file.
- **Escalate** any finding that a single reviewer marked low-severity but which, in context of other findings, rises to high-severity.
- **Emit a unified verdict** (ACCEPT / REJECT / NEEDS DISCUSSION) with a summary of merged high/medium/low counts.

```
You are the aggregator reviewer. You have received findings from <N> parallel per-file reviewers.
Your job: merge, deduplicate, surface inter-file inconsistencies, and emit a single unified verdict.
You do NOT re-read source files. You reason over the reviewer findings only.
```

### Logging the pool decision

After deciding pool size, append one JSONL entry to `.claude/handoffs.jsonl`:

```json
{"event": "reviewer_pool_decision", "ts": "<ISO-8601>", "pool_size": <N>, "files": ["<path1>", "..."], "decision_reason": "<single-file|pool-of-N|capped-from-M>"}
```

Use `date -u +%Y-%m-%dT%H:%M:%SZ` for the timestamp. Append with `>>` — do not overwrite the file.

```bash
printf '{"event":"reviewer_pool_decision","ts":"%s","pool_size":%d,"files":[%s],"decision_reason":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$POOL_SIZE" \
  "$FILES_JSON" \
  "$DECISION_REASON" \
  >> .claude/handoffs.jsonl
```

Paper reference: arXiv:2605.18747 §4.1.3 (SoA, MAGIS) — agent pool size should scale with task complexity; fixed-size pools leave coverage gaps on large file sets.

---

## Output Format

```text
DISPATCH RECOMMENDATION:
Route: [Single Agent | Fan-Out | Pipeline]
Reason: <one sentence>
Agent(s): <which agents to use>
Estimated scope: <files/operations count>
Risk level: <low/medium/high>
```

When Pipeline route is chosen, also emit:

```text
REVIEWER POOL:
Pool size: <1 or N> reviewer(s) [+ 1 aggregator if N≥3]
Files: <list or "single-reviewer mode">
Decision reason: <single-file|pool-of-N|capped-from-M>
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

## Execution Checklist

- [ ] Read task description; classify route (single-agent / fan-out / pipeline / tdd-loop)
- [ ] Emit `DISPATCH RECOMMENDATION` block with route, reason, agent(s), scope, risk level
- [ ] If pipeline route: wait for planner subagent to finish
- [ ] Parse planner output for explicitly enumerated independent files (numbered list, FILES: block, or `- [ ]` task list)
- [ ] Compute N = min(file_count, 5); decide pool size (N≥3 → pool, else single reviewer)
- [ ] Emit `REVIEWER POOL` block showing pool size, files, and decision reason
- [ ] Append pool decision to `.claude/handoffs.jsonl` as a JSONL entry with `event`, `ts`, `pool_size`, `files`, `decision_reason`
- [ ] If N≥3: dispatch N parallel reviewer Agent calls (each with `target_file:` arg), then dispatch 1 aggregator reviewer
- [ ] If N<3: dispatch single reviewer (current behavior, no `target_file:` needed)
- [ ] Pass aggregator or single reviewer findings to `/verify`

## Input/Output Examples

### Example 1 — Single-reviewer flow (N=1 file)

```
Input:
  Planner output (excerpt):
    "The only file to modify is plugins/agents/skills/dispatch/SKILL.md. No other files are touched."

Output:
  DISPATCH RECOMMENDATION:
  Route: Pipeline
  Reason: architectural change to dispatch heuristic, review warranted
  Agent(s): generator → reviewer → /verify
  Estimated scope: 1 file
  Risk level: medium

  REVIEWER POOL:
  Pool size: 1 reviewer
  Files: single-reviewer mode
  Decision reason: single-file (N=1 < 3 threshold)

  Handoff log entry:
  {"event":"reviewer_pool_decision","ts":"2026-05-20T09:00:00Z","pool_size":1,"files":["plugins/agents/skills/dispatch/SKILL.md"],"decision_reason":"single-file"}
```

### Example 2 — Parallel pool flow (N=4 files)

```
Input:
  Planner output (excerpt):
    FILES:
    - plugins/agents/skills/dispatch/SKILL.md
    - plugins/agents/agents/reviewer.md
    - docs/agentic-workflow.md
    - docs/architecture.md

Output:
  DISPATCH RECOMMENDATION:
  Route: Pipeline
  Reason: multi-file architectural changes with independent scope per file
  Agent(s): generator → [reviewer-1, reviewer-2, reviewer-3, reviewer-4] + aggregator → /verify
  Estimated scope: 4 files
  Risk level: medium

  REVIEWER POOL:
  Pool size: 4 reviewers + 1 aggregator
  Files: plugins/agents/skills/dispatch/SKILL.md, plugins/agents/agents/reviewer.md,
         docs/agentic-workflow.md, docs/architecture.md
  Decision reason: pool-of-4 (N=4 ≥ 3 threshold)

  Agent tool calls (parallel):
    Agent(reviewer, "Review plugins/agents/skills/dispatch/SKILL.md. target_file: plugins/agents/skills/dispatch/SKILL.md")
    Agent(reviewer, "Review plugins/agents/agents/reviewer.md. target_file: plugins/agents/agents/reviewer.md")
    Agent(reviewer, "Review docs/agentic-workflow.md. target_file: docs/agentic-workflow.md")
    Agent(reviewer, "Review docs/architecture.md. target_file: docs/architecture.md")

  Then (after all four return):
    Agent(reviewer, "You are the aggregator. Merge findings from 4 reviewers. [findings pasted]")

  Handoff log entry:
  {"event":"reviewer_pool_decision","ts":"2026-05-20T09:10:00Z","pool_size":4,"files":["plugins/agents/skills/dispatch/SKILL.md","plugins/agents/agents/reviewer.md","docs/agentic-workflow.md","docs/architecture.md"],"decision_reason":"pool-of-4"}
```

## Known Failure Modes

- **Route picked from file count alone.** Five similar files reading "fan-out" can still be sequential if each step depends on the previous result. Before locking the route, check interdependence, not just count.
- **Pipeline chosen for a one-shot bug fix.** The planner→generator→reviewer round-trip costs ~3× tokens; a 1–3 file fix doesn't earn the overhead. Prefer Single Agent unless the change spans concerns or carries deploy risk.
- **Fan-out with shared mutable state.** Two parallel subagents editing the same file race; both succeed, second overwrites first. The dispatch decision should refuse fan-out when the file list overlaps.
- **LLM fallback non-termination.** When `route-prompt-llm.sh` is in play and disagrees with the shell verdict, the router can flap. Cap with `WORKFLOW_ROUTER_MODE=shell` for deterministic dispatch when investigating.
- **Pool spawned for coupled files.** If the planner lists 4 files but they share mutable state or a type that crosses all of them, per-file reviewers will miss the cross-cutting inconsistency. The aggregator catches some of this, but the planner should mark files as non-independent when coupling is tight.
- **Planner prose instead of list.** If the planner describes files in prose without a numbered/task list, the file count is treated as 0 and single-reviewer mode applies. Ask the planner to re-emit a `FILES:` block if pooling is desired.

## Rebuttals

Common rationalizations for shortcutting the routing decision, with rebuttals:

| Excuse | Rebuttal |
|---|---|
| "It's obviously a single-file change — single-agent." | "Obvious" is the most common failure pre-condition. Single-file edits with cross-cutting type or test impact still benefit from pipeline review. The classification cost is one inference; the cost of a wrong route is the whole task. |
| "Fan-out is overkill for 3 files." | Fan-out's value is **isolation**, not parallelism. Three independent files in one context window contaminate each other; three subagents do not. File count is a weak proxy for the right route. |
| "Skip TDD just this once — the requirement is clear." | "Clear" requirements are exactly when TDD is cheapest — the test writes itself. Skipping it forfeits the artifact that proves the requirement was met. |
| "I'll just do it without recording the route." | An undocumented routing decision is unreviewable. The one-line classification with reason is the audit trail; without it, a wrong route looks identical to a right one in retrospect. |
| "Pipeline is too heavy for a refactor." | Pipeline overhead is fixed; refactor risk scales with surface area. Renaming three callers across two files is exactly when the planner→generator→reviewer separation pays off. |
