---
name: feature-list
description: Expand the ## Contract section of the latest plan into .claude/features.json — a machine-readable list of testable requirements with verify_cmd per item. Consumed by /tdd-loop, /verify, and after-subagent updates.
when_to_use: Reach for this immediately after a plan is approved (ExitPlanMode) and before the generator dispatches — `/tdd-loop` and `/verify` both read the resulting features.json. Do NOT use for free-form work without a plan; feature-list expects a structured `## Contract` section as its source of truth.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
logical: .claude/features.json contains a testable requirements array derived from the plan's contract
---

# /feature-list — Contract → Testable Requirements JSON

Convert the latest plan's `## Contract` into `.claude/features.json`. This file becomes the shared source of truth for what "done" means; `/tdd-loop` consumes it, `/verify` runs the verify_cmds, and `after-subagent.sh` flips items to `status: done`.

## Process

1. **Locate the latest plan.** Glob `.claude/plans/*.md`; pick the most recently modified. If none, stop: `No plan found. Run Plan mode first.`

2. **Extract `## Contract`.** Read the plan; find the `## Contract` section. If missing, stop: `Plan has no ## Contract section. /feature-list expects one.`

3. **Parse criteria.** Each bullet under `## Contract` becomes one feature. Trim; skip empty lines and sub-bullets (sub-bullets become part of the parent `description`).

4. **Derive verify_cmd per item.** Inspect the criterion text and the repo stack:
   - Mentions a test? → `<test-runner> --filter=<hint>` (pest/pytest/jest/cargo test/go test).
   - Mentions a file edit? → `test -f <path>` or `grep -q '<expected>' <path>`.
   - Mentions a command output? → `<cmd> | grep -q '<pattern>'`.
   - No clear verification → `# manual` — flag for review.

5. **Emit `.claude/features.json`** (overwrite if present; this is a fresh expansion per plan):
   ```json
   [
     {
       "id": "F1",
       "description": "<contract bullet>",
       "verify_cmd": "<command or '# manual'>",
       "status": "pending",
       "plan": ".claude/plans/<file>.md"
     }
   ]
   ```
   IDs are stable: `F1`, `F2`, ... in Contract order.

6. **Report**: `Expanded N features from <plan>. Run /tdd-loop or /verify to execute verify_cmds.`

## Integration

- `.claude/features.json` is read by:
  - `/tdd-loop` — drives RED/GREEN cycles.
  - `/verify` (evaluator plugin) — runs each verify_cmd and writes results.
  - `after-subagent.sh` (workflow plugin) — flips `status` when matching work completes.
  - `surface-progress.sh` (this plugin, SessionStart) — summarizes pending/in_progress/done counts.
  - `/rest-audit` — Efficiency axis (pending/done ratio).

## Failure Modes

- `.claude/features.json` exists and has `done` items → do NOT clobber silently. Read it; preserve completed entries when re-expanding; assign new IDs to new items.
- Contract bullets are ambiguous → emit `verify_cmd: "# manual"` and report count; the user can refine.
- No recognizable stack for test command → emit `# manual`.
