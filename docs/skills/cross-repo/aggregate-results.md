# Aggregate Results

`/aggregate-results` collects the per-repo `result.json` files produced by a `/federated-fan-out` run, de-duplicates identical summaries by content hash, and emits a per-repo verdict matrix alongside an `aggregated.json` summary in the run workspace. It belongs to the `cross-repo` plugin, which provides cross-repository coordination and discovery skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install cross-repo@forge-studio
```

```bash
python3 plugins/cross-repo/skills/aggregate-results/scripts/aggregate.py --run-id <id>
```

`--run-id` must match the run-id used in the corresponding `/federated-fan-out` invocation.

## Why you need it

After a fan-out run completes, the results exist as individual `result.json` files scattered across per-repo subdirectories. Reading them one by one is tedious and makes it easy to miss a failure or miscount the verdict distribution. More importantly, fan-out runs on large batches frequently produce identical outputs for most repos — the same patch applied cleanly, the same "already canonical" result — and displaying each duplicate separately obscures the signal.

`/aggregate-results` solves both problems. The content-hash de-duplication collapses identical summaries into a cluster with a count, so you see "PASS ×4 (same output)" rather than four identical lines. The verdict matrix formats PASS, FAIL, and SKIPPED in a scannable table. The `aggregated.json` output is machine-readable, making it straightforward to pipe into downstream reporting or a CI gate.

## When to use it

- Immediately after a `/federated-fan-out` run finishes, to get the full verdict matrix and `aggregated.json`.
- When a fan-out run partially completed (some repos failed) and you want a unified view of what succeeded and what did not before deciding whether to retry.

Do not use it for dispatching work to multiple repos — use [`/federated-fan-out`](federated-fan-out.md) instead. Do not use it for scoring a single run against a rubric — use `/score-rubric` for that.

## Best practices

- **Match the run-id exactly.** The skill resolves `~/.forge-cross-repo/<run-id>/` and exits with an error if the workspace does not exist. A typo in the run-id surfaces as a clear "workspace does not exist" message, not a silent empty result.
- **Treat SKIPPED repos as a warning.** A repo subdir that exists but has no `result.json` appears as SKIPPED in the matrix. This means the subagent for that repo either never started or wrote no output — worth investigating before treating the run as complete.
- **Check cluster sizes for unexpected divergence.** Two repos in the same batch should rarely produce different summaries if the operation was uniform. A cluster size of 1 on a PASS row when most others are clustered together signals that something unexpected happened in that repo.
- **Read `aggregated.json` before re-running.** The JSON includes the per-repo verdict and `summary_cluster_id`. Comparing two runs' `aggregated.json` files is the fastest way to see whether a retry changed anything.

## How it improves your workflow

`/aggregate-results` closes the loop on a fan-out batch. Without it, the end state of a cross-repo operation is a collection of files requiring manual inspection. With it, the state is a single table and a machine-readable JSON that captures verdicts, summaries, and cluster membership in one artifact. That artifact is what makes fan-out operations auditable, repeatable, and comparable across runs rather than one-shot.

## Related

- [`federated-fan-out.md`](federated-fan-out.md) — the dispatch step that produces the per-repo result.json files this skill collects
- [`sync-discovery.md`](sync-discovery.md) — pattern comparison across two repos; use before fan-out to confirm where divergence exists
- [`../evaluator/score-rubric.md`](../evaluator/score-rubric.md) — grades a single run against a rubric; complements aggregate-results for quality assessment
- [Architecture](../../architecture.md) — multi-agent decomposition in the 8-component harness model
