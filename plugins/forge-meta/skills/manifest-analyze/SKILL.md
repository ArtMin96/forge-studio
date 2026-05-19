---
name: manifest-analyze
description: Use when you want a structured report on what the change manifest contains — frequency of failure patterns, risk task distribution, constraint-level split, and top "why this component" clusters. Reads `.claude/evolution/change_manifest.jsonl` and emits a 5-section Markdown report to stdout.
when_to_use: Reach for this after a sprint or extended tuning run to understand which failure patterns dominate the manifest, which risk tasks recur most, and whether soft vs. hard constraints are balanced. Pass `--include-archive` to fold in rotated archive files when the live manifest has been rotated. Do NOT use for browsing individual entries chronologically — use `/evolution-history` instead.
argument-hint: "[--include-archive]"
allowed-tools:
  - Bash
  - Read
---

## What this produces

Running `bash plugins/forge-meta/skills/manifest-analyze/scripts/analyze.sh` emits a Markdown report with five sections:

1. **Volume** — total entry count, oldest and newest ISO timestamps, number of distinct sessions covered.
2. **Failure-pattern frequency** — top-10 `failure_pattern` values ranked by occurrence count.
3. **Risk-task frequency** — all values from `risk_tasks` fields (comma-separated strings treated as a list), ranked by frequency.
4. **Constraint-level distribution** — entry count per `constraint_level` value (e.g. `soft`, `hard`, unset).
5. **Why-this-component clusters** — distinct `why_this_component` strings ranked by frequency; reveals which components attract the most evolution pressure.

When the manifest is empty or absent the script prints:

```
# Manifest Analysis

_No entries._
```

and exits 0.

## Usage

```bash
# Current manifest only:
bash plugins/forge-meta/skills/manifest-analyze/scripts/analyze.sh

# Include rotated archive files (after ledger rotation ships):
bash plugins/forge-meta/skills/manifest-analyze/scripts/analyze.sh --include-archive
```

## Determinism

The script is deterministic: for a given manifest file the output is identical across invocations. Frequency ties are broken alphabetically so the ranking never shifts between runs.

## Execution Checklist

- [ ] Confirm `.claude/evolution/change_manifest.jsonl` exists and has entries worth analyzing
- [ ] Run without flag for a quick summary of the live manifest
- [ ] Run with `--include-archive` if ledger rotation has moved older entries to `.claude/evolution/archive/`
- [ ] Pipe through `head -40` for a quick preview of the top sections

## Examples

Input: `.claude/evolution/change_manifest.jsonl` is empty or missing.

Output:
```
# Manifest Analysis

_No entries._
```

Input: `.claude/evolution/change_manifest.jsonl` contains 12 entries, 8 with `failure_pattern: premature-edit`, 4 with `failure_pattern: stale-import`, all `constraint_level: soft`, across 3 sessions.

Output:
```
# Manifest Analysis

## Volume

| Metric | Value |
|--------|-------|
| Total entries | 12 |
| Oldest | 2026-05-10T09:01:14Z |
| Newest | 2026-05-19T08:22:03Z |
| Distinct sessions | 3 |

## Failure-Pattern Frequency

| Rank | Failure pattern | Count |
|------|----------------|-------|
| 1 | premature-edit | 8 |
| 2 | stale-import | 4 |

## Risk-Task Frequency

_No `risk_tasks` values recorded._

## Constraint-Level Distribution

| Constraint level | Count |
|-----------------|-------|
| soft | 12 |

## Why-This-Component Clusters

_No `why_this_component` values recorded._
```

## Known Failure Modes

- If all entries lack `failure_pattern`, that section shows an empty table rather than an error.
- `risk_tasks` stored as a JSON array (e.g. `["risk-A","risk-B"]`) and as a comma-separated string (e.g. `"risk-A,risk-B"`) are both handled; mixed usage within the same manifest is tolerated.
