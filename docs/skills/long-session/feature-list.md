# Feature List

`/feature-list` turns the `## Contract` section of your latest approved plan into `.claude/features.json` — a machine-readable array of testable requirements, each with a stable ID, a description, a verification command, and a status field. It belongs to the `long-session` plugin, which keeps work coherent across sessions, compactions, and subagents by maintaining a shared set of durable artifacts.

---

## Install

```bash
/plugin install long-session@forge-studio
```

```text
/feature-list
```

No arguments. The skill locates the active plan automatically and reads its `## Contract` section as its source material.

## Why you need it

A plan's contract is written for humans — bullet points that describe what "done" looks like. Once work starts, that prose needs to become something a tool can query, verify, and update without re-reading the whole plan every time. Without a structured requirements file, `/verify` has nothing concrete to run, `after-subagent.sh` has nowhere to record completion, and the progress surface at session start can only say "plan exists" rather than "3 of 7 criteria met."

`/feature-list` closes that gap. It reads each bullet, derives the most specific verification command it can infer from the repo stack — a test-runner filter, a `test -f` check, a `grep -q` on a file — and emits a stable JSON array with IDs that remain consistent across re-expansions. Subsequent tools and hooks all read that single file rather than independently parsing the plan, so the entire pipeline shares one definition of done.

## When to use it

- Immediately after a plan is approved (ExitPlanMode) and before the generator dispatches work — `/tdd-loop` and `/verify` need the file to exist before they can operate.
- Whenever a contract gains new criteria mid-project; re-running `/feature-list` merges the additions while preserving any items already marked `done`.
- Before running `/session-resume` in a fresh session where the features file is absent or stale.

Do not use it for free-form work without a plan — `/feature-list` expects a structured `## Contract` section as its source of truth. If you need to track ad-hoc tasks within a conversation, use `TaskCreate` / `TaskUpdate` instead.

## Best practices

- **Run it right after plan approval, not later.** The sooner `.claude/features.json` exists, the more of the pipeline can use it. Waiting until mid-implementation means early generator turns have no verification target.
- **Trust the `# manual` flag.** When a criterion can't be reduced to a command, the skill emits `verify_cmd: "# manual"` rather than guessing. Review those items before running `/verify` — they need a human check or a richer criterion added to the contract.
- **Do not hand-edit the file between runs.** Statuses you set manually (marking `done` for items you completed by hand) are safe — re-expansion preserves `done` entries. But editing descriptions or IDs will cause mismatches with the plan and confuse downstream consumers.
- **Pair it with `/tdd-loop` for test-first work.** The features file gives `/tdd-loop` a complete list of items to drive Red/Green/Refactor cycles against, rather than rediscovering the requirements each time.

## How it improves your workflow

Expanding the contract once — at plan-approval time — means every subsequent tool that asks "what needs to be done?" reads a structured, versioned file rather than re-parsing prose. `/verify` runs the commands. `after-subagent.sh` flips statuses when subagents complete matching work. `surface-progress.sh` surfaces pending/in-progress/done counts at every SessionStart. The result is a pipeline where progress is visible, verifiable, and shared across sessions without anyone maintaining a separate todo list.

## Related

- [`/session-resume`](session-resume.md) — reads `.claude/features.json` to surface pending and in-progress items at session start
- [`/progress-log`](progress-log.md) — records completed work; pairs with features.json as the two halves of the durable session record
- [`../agents/contract.md`](../agents/contract.md) — the contract skill re-reads a plan's success criteria; feature-list expands those same criteria into a machine-readable form
- [`../../architecture.md`](../../architecture.md) — the long-session artifact pattern in the harness model
