# Harness Metrics

`/harness-metrics` computes six harness-level quality dimensions from existing Forge Studio artifacts and renders a Markdown scorecard. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/harness-metrics
```

No arguments needed for a standard run. You can optionally pass a path to a synthetic manifest file for testing: `/harness-metrics /tmp/test.jsonl`.

## Why you need it

Running a multi-task sprint produces a lot of activity — hooks fire, agents write to the ledger, verify gates pass and fail. Without a summary view, it is hard to know whether the harness is actually getting better or just staying busy. `/harness-metrics` answers that by computing six dimensions defined in arXiv:2605.18747 §5.2.1: trajectory efficiency, verification strength, recovery ability, state consistency, safety compliance, and replayability. Each dimension is derived purely from artifacts on disk — traces, the change manifest, the belief log, and hook logs — so there is no inference or fabrication involved.

The scorecard writes to both stdout and `.claude/metrics/<YYYY-MM-DD>.json`. When a prior-day file exists, `/session-digest` can compare today's values against it and show a per-dimension delta, making improvement or regression immediately visible.

## When to use it

- After a multi-task sprint, when you want to see whether harness quality moved.
- At the end of a session, as a complement to `/session-digest`'s automatic invocation.
- Any time a dimension score looks suspicious and you want a data-grounded view of what is happening across the harness.

Do not use it as a gate — metrics are observational. Use [`/verify`](../evaluator/verify.md) for gating task completion.

## Best practices

- **Run after populating the ledger.** Metrics derived from the change manifest are only meaningful once `/change-manifest` has been writing evidence bundles. A fresh project with zero entries shows `n/a` or 0% for most dimensions — that is expected, not a bug.
- **Distinguish n/a from 0%.** A dimension that shows `n/a` means the required artifact does not exist (no traces directory, no belief log). A dimension that shows 0% means the artifact exists but the criterion was never met — that is the more urgent signal.
- **Use the daily JSON files for trending.** Each run writes `.claude/metrics/<YYYY-MM-DD>.json`. Keeping those files in version control or reviewing them week-over-week gives you a concrete picture of whether `verification_strength` and `replayability` are climbing.
- **Identify the emptiest dimension and fix the artifact.** If `verification_strength` is 0%, the fix is to populate `checks_run` in your next change-manifest entries. If `replayability` is low, add `rollback_handle` fields. The scorecard tells you where to focus, not just where you stand.

## How it improves your workflow

`/harness-metrics` makes harness health legible. Without it, quality is a feeling; with it, quality is a number that moves or stays flat across sprints. When combined with [`/session-digest`](session-digest.md)'s Harness Metrics delta section, you get a per-session view of which dimensions improved and by how much, giving you an objective basis for deciding whether to ship a sprint or spend another cycle shoring up verification.

## Related

- [`/session-digest`](session-digest.md) — reads the metrics output and shows a delta table at the end of each session
- [`/change-manifest`](change-manifest.md) — the primary source artifact for verification_strength and replayability scores
- [`/verify`](../evaluator/verify.md) — the gating skill; harness-metrics is observational, verify is the gate
- [Architecture](../../architecture.md) — evaluation and quality gates in the 8-component harness model
