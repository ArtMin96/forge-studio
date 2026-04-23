---
name: living-spec
description: Initialize .claude/spec.md from the latest plan's ## Contract. after-subagent.sh then appends delta blocks as each agent completes. Pairs with /contract (static criteria) + /feature-list (testable JSON) to form the plan→execute→verify loop.
when_to_use: After a plan is approved and before dispatching the generator. Re-run only if the plan changes.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---

# /living-spec — Initialize the Living Spec

Write `.claude/spec.md` from the latest plan's `## Contract`. Unlike `/contract` (which just re-reads static criteria to fight context decay), the living spec is **continuously updated** by `after-subagent.sh` as each phase (planner → generator → reviewer) completes. The reviewer compares code vs the spec — not just vs the original plan.

## Process

1. **Find the latest plan.** Glob `.claude/plans/*.md`; pick the most recently modified. If none, stop: `No plan found. Run Plan mode first.`

2. **Extract `## Contract`.** If missing, stop: `Plan has no ## Contract section. /living-spec expects one.`

3. **If `.claude/spec.md` already exists** — read it. Check the `Plan:` header line. If it matches the current plan file, report `spec.md already initialized for this plan. Use after-subagent updates instead.` and stop.

4. **Write `.claude/spec.md`** with this exact structure:

   ```markdown
   # Living Spec

   Plan: .claude/plans/<file>.md
   Initialized: <UTC ISO8601>

   ## Contract (from plan)

   <verbatim copy of the ## Contract section>

   ## Deltas

   <!-- after-subagent.sh appends blocks here, newest last:
   ### <UTC> — <agent>
   Completed:
     - ...
   Pending:
     - ...
   -->
   ```

5. **Report:** `spec.md initialized with N contract items. after-subagent.sh will append deltas as agents complete.`

## Integration

**Writers:**
- `/living-spec` (this skill) — initializes
- `plugins/workflow/hooks/after-subagent.sh` — appends delta blocks on each SubagentStop

**Readers:**
- Reviewer step — diffs spec vs code state; flags unfinished items
- `/verify` — cross-references deltas with features.json
- `surface-progress.sh` (SessionStart) — surfaces the last delta
- `/session-resume` — includes spec tail in briefing
- `/rest-audit` Reliability axis — checks spec presence + delta density

**Paired artifacts:**
- `.claude/plans/*.md` — the input
- `.claude/features.json` — the parallel testable view (from `/feature-list`)

## Failure Modes

- Plan's `## Contract` is empty → write spec.md with `## Contract` section empty + warn.
- `.claude/spec.md` is a directory → fail loudly.
- No write permission to `.claude/` → fail loudly; do NOT fall back to writing elsewhere.

## Do NOT

- Do not overwrite an existing spec.md without explicit user confirmation.
- Do not rewrite deltas — they are append-only history.
- Do not mix spec content with `claude-progress.txt` — those are different artifacts (spec = current plan state, progress = session-to-session history).
