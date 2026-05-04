---
name: prediction-audit
description: Join SEPL proposal predictions against post-commit trace observations and report per-resource prediction error. Pure read — never mutates harness files or the ledger.
when_to_use: Reach for this monthly, after several SEPL commits have landed, to check whether `/assess-proposal` impact estimates hold up. Run after `/trace-evolve` so the trace summaries are fresh. Do NOT use to evaluate a single un-committed proposal — that's `/assess-proposal`; this skill audits predictions across already-committed proposals.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
logical: per-resource verdict table emitted (accurate / over-estimate / under-estimate / insufficient-data)
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
- `~/.claude/traces/*.jsonl` (or `$FORGE_TRACES_DIR/*.jsonl` if set) — bash, file-edit, failure, session-summary entries collected by the `traces` plugin

For each proposal that has been committed (per the ledger), the helper script extracts the structured prediction fields, attributes trace entries to the resource by matching the slug or its basename in `file_path` (file events) and `command` / `output_preview` (bash events), splits matching entries on the commit timestamp into pre and post buckets, normalizes by distinct trace files (≈ sessions), and reports the resulting Δbytes/session as the observed value.

Override the traces directory for project-local or test runs:

```bash
FORGE_TRACES_DIR=/path/to/traces python3 plugins/evaluator/skills/prediction-audit/scripts/audit.py
```

## Process

Run the helper script:

```bash
python3 plugins/evaluator/skills/prediction-audit/scripts/audit.py
```

It returns a markdown report (stdout). Pipe to a file if you want to keep it. The report has one row per committed proposal where a `## Predicted Impact (structured)` section is present.

## Output Format

```markdown
## Prediction Audit

Committed proposals scanned: N
Proposals with structured prediction: M

### Per-resource prediction error

| Resource | Predicted Δtokens/session | Observed Δbytes/session (post − pre) | Pre/Post sessions | Verdict |
|---|---|---|---|---|
| rules.d/<rule>.txt | +132 | +118 | 3/4 | accurate |

### Calibration summary
Mean signed error: <int>
Mean absolute error: <int>
Proposals with no structured prediction (skipped): K
```

Predicted is in *predicted* tokens; observed is in *bytes* of trace entries that reference the resource — the units differ but the sign and magnitude are the audit signal. A proposal that predicted `+100` and got `+107` is accurate; one that predicted `-200` and got `-428` under-estimated the magnitude. The `Pre/Post sessions` column is the count of distinct trace files (≈ sessions) before/after the commit timestamp; a `0/N` post-only count drops the row to `insufficient-data`.

## Limitations

- Observed Δbytes is a proxy for impact, not a token counter — the plugin has no access to model API counters, so it measures how often the resource appears in tool traces. Comparable across proposals on the same resource; not directly comparable to `predicted_token_delta_per_session` in absolute terms.
- Cluster-resolved verification is not implemented. The structured field is parsed and reported but not joined against trace failure clusters; that join lives in `/trace-evolve`.
- Sessions ≈ distinct trace files. A trace file rolls per day per cwd, so a long single session that crosses midnight will inflate the session count. Acceptable noise at the audit's monthly cadence.
- Read-only. Never appends ledger entries. Misses in calibration become inputs to the next `/evolve` cycle.

## Execution Checklist

- [ ] Confirmed `.claude/lineage/proposals/` exists and has at least one committed proposal
- [ ] Confirmed `~/.claude/traces/` (or `$FORGE_TRACES_DIR`) has JSONL files spanning the pre- and post-commit windows
- [ ] Ran `python3 plugins/evaluator/skills/prediction-audit/scripts/audit.py`
- [ ] Reviewed the per-resource table for outliers (>50% error)
- [ ] Captured the calibration summary; flagged any commit where prediction was off by >2× as a candidate for `/trace-evolve` follow-up

## Examples

### Example 1: a proposal with accurate prediction

Input: a committed proposal under `.claude/lineage/proposals/` containing
```markdown
## Predicted Impact (structured)
predicted_token_delta_per_session: 132
predicted_failure_clusters_resolved: none
predicted_negative_effects: none
```

Output row:
```text
| rules.d/<rule>.txt | +132 | +118 | 3/4 | accurate |
```

### Example 2: a proposal with no structured section

Input: a legacy proposal without `## Predicted Impact (structured)`.

Output: appears under `Proposals with no structured prediction (skipped)` count, no row in the per-resource table.

## Known Failure Modes

- **No post-commit sessions** — when no trace file exists with a timestamp ≥ the resource's commit ts, the script labels the row `insufficient-data` rather than fabricating a verdict.
- **Slug-substring matching** — attribution uses `slug in haystack or basename in haystack`. Two resources with identical basenames in different directories will collide; rename one to disambiguate.
- **Self-test fixture drift** — `--self-test` runs an inline fixture for the parser; trace-attribution is exercised by integration tests, not by `--self-test`. If parsing changes, update the fixture.
