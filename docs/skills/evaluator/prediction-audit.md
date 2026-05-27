# Prediction Audit

`/prediction-audit` closes the observability loop on SEPL (self-evolution protocol loop) commits. It reads the `## Predicted Impact (structured)` sections from committed proposals under `.claude/lineage/proposals/`, joins each prediction against post-commit trace observations in `~/.claude/traces/*.jsonl`, and produces a per-resource table showing whether each impact estimate was accurate, an over-estimate, or an under-estimate. It is purely read-only — it never modifies proposals, verdicts, or the ledger.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/prediction-audit
```

No arguments. The skill walks `.claude/lineage/proposals/` and `~/.claude/traces/` automatically. To use a different traces directory, set `FORGE_TRACES_DIR` before invoking.

## Why you need it

Every SEPL proposal that goes through `/assess-proposal` includes an impact estimate: how many tokens will this rule add per session, which failure clusters will this change resolve. Those estimates are the basis on which proposals are accepted or rejected. But without a feedback mechanism, they are unfalsifiable — the proposal lands, the estimate is forgotten, and the next proposal's estimate is made with no calibration from the last one.

`/prediction-audit` is that feedback mechanism. By joining each proposal's structured prediction fields against actual trace observations before and after the commit, it turns impact estimates into a measurable track record. A proposal that predicted `+132 tokens/session` and observed `+118` is accurate; one that predicted `-200` and observed `-428` under-estimated by more than 2×. That error is an input to the next `/evolve` cycle — the estimator needs to be recalibrated, not just accepted.

## When to use it

- Monthly, after several SEPL commits have landed and enough trace data has accumulated to compute pre/post deltas.
- After running `/trace-evolve`, so the trace summaries covering the post-commit period are fresh.
- Before claiming the SEPL loop is "calibrated" — without a prediction audit, every impact estimate is untested.

Do not use it for evaluating a single un-committed proposal — use `/assess-proposal` for that; this skill audits predictions across already-committed proposals.

## Best practices

- **Run `/trace-evolve` first.** The audit joins predictions against trace entries; stale or missing traces produce `insufficient-data` verdicts rather than real calibration signal. Fresh traces are the prerequisite.
- **Treat >2× error as an `/evolve` input.** The calibration summary flags proposals where prediction was off by more than a factor of two. Each such entry is a candidate for a follow-up `/trace-evolve` analysis to understand what the estimate missed.
- **Understand the units mismatch.** Predicted values are in tokens; observed values are in bytes of trace entries referencing the resource. The sign and magnitude are the signal — direct numerical comparison is not meaningful, but a predicted `+100` with an observed `-50` is a genuine calibration failure.
- **Don't audit before the first SEPL commit.** The skill requires at least one committed proposal with a structured prediction section. If no proposals have landed yet, there is nothing to join against.

## How it improves your workflow

Self-evolution without feedback is self-delusion. A harness that adjusts itself based on impact estimates it never validates will drift over time toward changes that felt correct but were not measured. `/prediction-audit` makes the SEPL loop empirically grounded: each commit's actual effect is on record, each estimate's accuracy is scored, and the next round of proposals is informed by a real calibration summary rather than a prior that was never tested.

## Related

- [`assess-proposal.md`](assess-proposal.md) — the pre-commit gate that scores proposals including their impact estimates; prediction-audit is its post-commit counterpart
- [`verify.md`](verify.md) — evidence gate for ordinary task completion; prediction-audit is the evidence gate for SEPL impact claims
- [Architecture](../../architecture.md) — where self-evolution and observability fit in the 8-component harness model
