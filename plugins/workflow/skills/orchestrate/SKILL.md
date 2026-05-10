---
name: orchestrate
description: Manually invoke the agentic workflow for the current task. Reads the active plan and dispatches the right pattern (single-agent, pipeline, fan-out, TDD loop).
when_to_use: Reach for this when you want to skip the automatic router, override its routing decision, or explicitly choose a dispatch pattern (single-agent, pipeline, fan-out, TDD loop). Do NOT use to *decide* which pattern fits — that's `/dispatch`; orchestrate is the executor once the pattern is already chosen.
disable-model-invocation: true
argument-hint: [pattern]
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
scheduling: an active plan exists in `.claude/plans/` and the user invokes manual entry into the agentic workflow (overriding route-prompt.sh classification)
structural:
  - Locate the active plan via mtime
  - Resolve the requested pattern (single | pipeline | fan-out | tdd | auto)
  - "Pipeline pattern dispatches /contract then the planner -> generator -> reviewer chain"
  - "Fan-out pattern invokes /fan-out with an explicit file list drawn from the plan"
  - "TDD pattern hands off to /tdd-loop with acceptance criteria"
  - Report the dispatched pattern and next gate
logical: exactly one pattern is dispatched; report line names the pattern and the next hook/skill that fires
---

# /orchestrate — Manual Entry Into the Agentic Workflow

The `route-prompt.sh` hook auto-classifies every prompt. This skill is the manual escape hatch — invoke it when:

- You disagree with the hook's routing and want to override it
- You want to start a new sprint from an existing plan file
- You need to re-dispatch after a failed pipeline run

## How to Run

**Argument** (optional, from `$ARGUMENTS`): `single | pipeline | fan-out | tdd | auto`. Default `auto`.

### Step 1 — Locate the active plan

```bash
ls -t .claude/plans/*.md 2>/dev/null | head -1
```

If no plan exists, tell the user: **"No active plan. Run the planner first (agents plugin → `/dispatch` → planner) or write a plan by hand in `.claude/plans/`."** Do not fabricate a plan.

Read the plan's `## Contract` section. If absent, tell the user — a plan without a contract defeats the sprint-contract protocol (see `HARNESS_SPEC.md` §Sprint Contract Protocol).

### Step 2 — Resolve the pattern

| `$ARGUMENTS` | Action |
|---|---|
| `single` | Execute directly. No subagents. Keep changes narrow. |
| `pipeline` | Dispatch the planner → generator → reviewer chain from the `agents` plugin. |
| `fan-out` | Dispatch `agents` plugin `/fan-out`. Batch size 3–5 (Anthropic multi-agent research, 2026). |
| `tdd` | Hand off to `/tdd-loop` (this plugin). |
| `auto` (default) | Apply the decision matrix from `plugins/agents/skills/dispatch/SKILL.md` against the plan's scope. |

### Step 3 — Dispatch

For `pipeline`:

1. Invoke `/dispatch` from the agents plugin once at the start, scoped to the whole plan, so its routing logic stays the single source of truth. Do **not** re-implement routing here.
2. Parse the plan for `#### T<n>` headings under `### Tasks`. Build an ordered task list `[T1, T2, …]`; the loop iterates this list one task at a time. If the plan has no `#### T<n>` headings, fall back to a single-pass dispatch and emit one warning line. (Most plans in `.claude/plans/` follow the heading convention; the fallback exists for old or hand-written plans.)
3. For each task in order:
   - Invoke `/contract` (agents plugin) so the plan's full Contract is re-read from disk fresh for this task (prevents context decay through compaction — `HARNESS_SPEC.md` §Sprint Contract).
   - Dispatch one `agents:generator` subagent scoped to **only this task's** Files / Success criteria block. Do not include sibling tasks in the subagent's prompt — keep its tool-call surface small to stay under the agent-loop budget (`maxTurns` / `task_budget`).
   - When the generator returns, dispatch one `agents:reviewer` subagent for the same task. Pass the generator's reported diff and the task's success criteria.
   - When the reviewer returns, invoke `/verify` (evaluator plugin) for that task only.
   - On failure (verify exit ≠ 0, reviewer rejects, or generator truncates without producing the declared artifacts): STOP. Report which task failed and why. Do not auto-advance; the user decides whether to fix and resume.
   - On success: optionally commit per-task (one commit per task is the recommended granularity; bundling is allowed when the user explicitly asks).
4. After the last task verifies clean, emit one summary line.

For `fan-out`:
- Invoke `/fan-out` (agents plugin) with an explicit file list drawn from the plan.

For `tdd`:
- Delegate immediately to `/tdd-loop`. Pass the plan's acceptance criteria as the test-writer's input.

For `single`:
- Execute the change directly. After the change, run the evaluator's `/healthcheck` or the project's test command as the verification step.

### Step 4 — Report

End with one line: `Dispatched: <pattern>. Next gate: <which hook / skill will fire next>.`

## Do NOT

- Do not rewrite the plan unless the user asked
- Do not skip the contract re-read (step 3.2) — it is the reliability mechanism that survives compaction
- Do not invoke multiple patterns in parallel — pick one and report
- Do not duplicate logic from `agents:/dispatch`, `evaluator:/verify`, or `long-session:/progress-log` — compose them

## Rebuttals

Common rationalizations for shortcutting orchestration, with rebuttals:

| Excuse | Rebuttal |
|---|---|
| "User said 'just do it' — skip the contract re-read." | "Just do it" sets urgency, not scope. Re-reading the Contract before each task is what *makes* dispatch reliable across compaction; skipping turns the orchestrator into a manual edit. |
| "I already know the pattern from earlier in this session." | Earlier-session memory is the failure mode this skill exists to bypass. The plan file on disk is the canonical source — read it. |
| "The plan only has one task — bundle dispatch." | Per-task dispatch boundaries are how regressions get attributed. Bundling means a failed task can't be isolated from a passing one. The single-task case still benefits from one verify pass. |
| "Auto-router already classified the prompt — no need to verify." | The auto-router classifies the **prompt**; orchestrate verifies the **plan**. Different inputs, different decisions. Don't trust upstream classification as a substitute for downstream re-read. |
| "Skip per-task verify on small tasks to save time." | The verify gate is what makes the dispatched pattern's success criterion measurable. Skipping it doesn't save time — it defers the failure to the next task. |
