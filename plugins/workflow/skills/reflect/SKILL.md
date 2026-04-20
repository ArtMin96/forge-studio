---
name: reflect
description: Reflect-Memorize step. Read a completed sprint (plan contract + test output + git diff), emit a three-line insight (worked / surprised / watch), route to /remember. Optional post-tdd-loop phase.
disable-model-invocation: true
argument-hint: [plan-path]
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# /reflect — Reflect-Memorize Step

MUSE-style Plan-Execute-**Reflect-Memorize** closure (Zhao et al., 2025). The plan + tests + diff are the raw experience; this skill compresses them into durable, scannable lessons.

Runs in ~30 seconds. Skip when the sprint is trivial (one-line fix, no new contract). Trigger automatically at the end of `/tdd-loop` Phase 3 when `WORKFLOW_TDD_REFLECT=1`.

## Input

Optional `[plan-path]`. Default: most recent `.claude/plans/*.md`.

## Flow

### Step 1 — Gather inputs

- Read the plan's `## Contract` section. If missing, stop — without a contract there's nothing to reflect against.
- Run `git diff HEAD~1 HEAD --stat` (if git available). Capture files + line counts.
- Read the last test command output if trace telemetry recorded it (`~/.claude/traces/*-summary.md` newest). Look for pass/fail counts and duration.

### Step 2 — Draft the insight (three lines, total)

```
Worked:     <what contract said vs what shipped — specific>
Surprised:  <one thing you discovered mid-implementation that wasn't in the plan>
Watch:      <one leading indicator that this will break later>
```

Rules:
- Each line ≤ 120 chars.
- No hedging ("maybe", "possibly"). If you don't know, omit the line.
- No code snippets. Insights are conceptual; details live in git.
- "Watch" is a *signal*, not a task — "retry logic assumes idempotency; test non-idempotent consumers" not "add idempotency tests."

### Step 3 — Deduplicate against memory

Search `.claude/memory/topics/*.md` for any topic whose content already contains the same insight. If found, update the `Last verified:` date on that topic instead of creating a new one. Skip the topic write if the insight adds nothing.

### Step 4 — Hand off to /remember

If the insight is new, invoke `/remember` with:

- Topic slug: `sprint-<YYMMDD>-<kebab-plan-name>` (or append to an existing topic for the same feature area)
- Content: the three-line insight + a `Source: <plan-path>` line

`/remember` handles the version header and ledger entry (see its SKILL.md after the memory versioning update).

### Step 5 — Report

One line:

```
Reflect: <topic-slug> (<new|updated|skipped-duplicate>)
```

## When To Skip

- Sprint had no `## Contract` section.
- No git history available (fresh repo, first commit).
- Insight duplicates an existing topic verbatim.
- User explicitly said "no reflect" for this sprint.

Silent skip — do not nag.

## Do NOT

- Do not invent plan content. If the contract is vague, write "Worked: contract too vague to reflect against" and stop.
- Do not write full postmortems here. `/postmortem` (evaluator) handles incidents. `/reflect` is the lightweight, every-sprint version.
- Do not feed the insight to `/evolve`. Reflection builds memory; evolution acts on traces. They share no pipeline.
