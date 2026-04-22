---
name: orchestrate
description: Manually invoke the agentic workflow for the current task. Reads the active plan and dispatches the right pattern (single-agent, pipeline, fan-out, TDD loop).
when_to_use: When you want to skip the automatic router, override its routing decision, or explicitly choose a dispatch pattern.
disable-model-invocation: true
argument-hint: [pattern]
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
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

1. Invoke `/dispatch` from the agents plugin so its routing logic stays the single source of truth. Do **not** re-implement routing here.
2. Before the generator starts, invoke `/contract` (agents plugin) so the plan's Contract section is re-read from disk (prevents context decay through compaction — `HARNESS_SPEC.md` §Sprint Contract).
3. After the reviewer returns, invoke `/verify` (evaluator plugin) to produce evidence-backed completion confirmation.

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
- Do not duplicate logic from `agents:/dispatch`, `evaluator:/verify`, or `context-engine:/handoff` — compose them
