---
name: prediction-audit
description: Join SEPL proposal predictions against post-commit trace observations and report per-resource prediction error. Pure read — never mutates harness files or the ledger.
when_to_use: Reach for this monthly, after several SEPL commits have landed, to check whether `/assess-proposal` impact estimates hold up. Run after `/trace-evolve` so the trace summaries are fresh. Do NOT use to evaluate a single un-committed proposal — that's `/assess-proposal`; this skill audits predictions across already-committed proposals.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
---

# /prediction-audit — SEPL Prediction-Outcome Joiner

Reads `## Predicted Impact (structured)` sections from `.claude/lineage/proposals/*.md`, joins them against `~/.claude/traces/*.jsonl` event counts, and reports per-resource prediction error. This is the post-commit half of the paired-prediction observability mechanism described in *Agentic Harness Engineering* (arXiv:2604.25850).

## When to Use

- Monthly cadence after several SEPL commits have landed
- After `/trace-evolve` so trace summaries are fresh
- Before claiming the SEPL loop is "calibrated" — without prediction audit, every proposal's impact estimate is unfalsifiable

## When NOT to Use

- For a single un-committed proposal — use `/assess-proposal`
- Before any SEPL commit has happened — there is nothing to audit
- For non-SEPL changes — git history is the right tool

## Inputs

The skill walks two directories (no arguments):

- `.claude/lineage/proposals/*.md` — proposals authored by `/evolve`, `/router-tune`, `/remember`
- `~/.claude/traces/*.jsonl` — bash, file-edit, failure, session-summary entries collected by the `traces` plugin

For each proposal that has been committed (per the ledger), the helper script extracts the structured prediction fields, computes an observed delta over the post-commit trace window, and joins them.

## Process

Run the helper script:

```bash
python3 plugins/evaluator/skills/prediction-audit/scripts/audit.py
```

It returns a markdown report (stdout). Pipe to a file if you want to keep it. The report has one row per committed proposal where a `## Predicted Impact (structured)` section is present.

## Output Format

```markdown
## Prediction Audit
Window: <date-range>
Committed proposals scanned: N
Proposals with structured prediction: M

### Per-resource prediction error

| Resource | Predicted Δtokens | Observed Δtokens | Error % | Clusters predicted | Clusters observed | Verdict |
|---|---|---|---|---|---|---|
| rules.d/<rule>.txt | +132 | +118 | -10.6% | none | none | accurate |

### Calibration summary
Mean signed error: <pct>
Mean absolute error: <pct>
Proposals with no structured prediction (skipped): K
```

## Limitations

- Observed Δtokens is heuristic — the helper estimates per-session token deltas from trace volume, not from actual model API counters (which the plugins don't have access to). The metric is comparative across proposals, not absolute.
- Cluster-resolved verification compares the predicted cluster ids against post-commit trace failure clusters. If the same cluster signature reappears, it counts as "not resolved" even when frequency dropped meaningfully.
- The audit is read-only. Never appends ledger entries. Misses in calibration become inputs to the next `/evolve` cycle.

## Execution Checklist

- [ ] Confirmed `.claude/lineage/proposals/` exists and has at least one committed proposal
- [ ] Confirmed `~/.claude/traces/` has JSONL files spanning the post-commit window
- [ ] Ran `python3 plugins/evaluator/skills/prediction-audit/scripts/audit.py`
- [ ] Reviewed the per-resource table for outliers (>50% error)
- [ ] Captured the calibration summary; flagged any commit where prediction was off by >2× as a candidate for `/trace-evolve` follow-up

## Examples

### Example 1: a proposal with accurate prediction

Input: a committed proposal under `.claude/lineage/proposals/` containing
```
## Predicted Impact (structured)
predicted_token_delta_per_session: 132
predicted_failure_clusters_resolved: none
predicted_negative_effects: none
```

Output row:
```
| rules.d/<rule>.txt | +132 | +118 | -10.6% | none | none | accurate |
```

### Example 2: a proposal with no structured section

Input: a legacy proposal without `## Predicted Impact (structured)`.

Output: appears under `Proposals with no structured prediction (skipped)` count, no row in the per-resource table.

## Known Failure Modes

- **No traces in window** — when `~/.claude/traces/` is empty for the post-commit window, observed delta is 0 and every prediction looks like a 100% over-estimate. The script labels this as `insufficient-data` rather than `inaccurate`.
- **Self-test fixture drift** — `--self-test` runs against an inline fixture; if the helper's parsing changes, the test should be updated alongside.
