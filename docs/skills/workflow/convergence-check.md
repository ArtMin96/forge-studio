# Convergence Check

`/convergence-check` is an internal helper skill in the `workflow` plugin that evaluates whether a plan's declared convergence criterion has been satisfied. It parses the `## Convergence` section from the active (or specified) plan file, runs the criterion shell command with a ten-second timeout, and returns a structured report with `met`, `evidence`, and `gap` fields. You rarely invoke this directly — it surfaces through [`/verify`](../evaluator/verify.md) and [`/status`](status.md), which call it automatically.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/convergence-check .claude/plans/s6-auth.md
```

The optional argument is a path to a specific plan file. When omitted, the skill resolves the active plan automatically.

## Why you need it

Some sprints have a goal that is only truly complete when a machine-checkable predicate holds across the whole codebase — not just "the new file exists" or "the tests pass" but something like "the plugin count is exactly 20" or "the marketplace JSON parses and the README header agrees." These multi-step criteria are hard to evaluate from memory or from reading code; they need to be run against the actual state of the repo.

A plan's `## Convergence` section encodes exactly that kind of criterion as a shell command. `/convergence-check` runs that command and reports back in a structured format that downstream skills — `/verify` when deciding whether to mark a sprint done, `/status` when reporting where you are — can interpret without re-parsing the plan file themselves. It is the single, consistent evaluator for convergence state, so the answer is always computed the same way regardless of which skill asks.

## When to use it

- When `/verify` is evaluating whether a plan's sprint is complete and the plan declares a `## Convergence` section.
- When `/status` is reporting current progress and you want to see whether the convergence criterion is currently met.
- When you want to manually check convergence state mid-sprint without waiting for a full verify run — pass the plan path as an argument.

Do not use it for ad-hoc edits that have no associated plan. Convergence only applies when a plan explicitly declares a `## Convergence` section. For plan-less verification work, use [`/verify`](../evaluator/verify.md) directly.

## Best practices

- **Keep criteria machine-checkable.** The `criterion` field must be a shell command that exits zero when the condition is met and non-zero when it is not. Criteria that depend on model judgment ("the code looks clean") cannot be evaluated here — encode them in the `/verify` contract instead.
- **Mind the ten-second timeout.** The criterion command runs with `timeout 10`. Long-running commands (full test suites, network calls) will be killed and the criterion will appear unmet. Keep convergence criteria fast — counting files, grepping a header line, or parsing a JSON file are all appropriate. Running a full integration suite is not.
- **Understand the exit codes.** Exit 0 means the criterion is met; exit 1 means it is unmet; exit 2 means the plan has no `## Convergence` block (which is valid — convergence is opt-in); exit 3 means the plan file was not found. Exit 2 is a graceful skip, not a failure.
- **Use `max_iterations` to pace retries.** The convergence block supports a `max_iterations` field that tells orchestrating skills how many fix-and-retry cycles are reasonable before escalating to the user. Set a realistic ceiling rather than leaving it open-ended.

## How it improves your workflow

`/convergence-check` closes the gap between "individual tasks done" and "sprint goal achieved." A plan can have all its `#### T<N>` tasks checked off while still failing its convergence criterion — for example, every file change was made correctly, but the count in the README header was not updated to match. By separating task completion from convergence evaluation, the pipeline can catch that mismatch before marking the sprint done. The structured output (`met`, `evidence_lines`, `gap`) gives `/verify` and `/status` the information they need to either advance or stop and report, without either skill needing to re-implement the criterion parsing logic.

## Related

- [`/verify`](../evaluator/verify.md) — calls this skill to gate "done" claims on convergence-aware plans
- [`/status`](status.md) — calls this skill to show convergence state in its situational report
- [`/orchestrate`](orchestrate.md) — the pipeline driver that halts on convergence failure
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
