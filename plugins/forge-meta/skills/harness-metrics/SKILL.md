---
name: harness-metrics
description: Compute seven harness-level quality dimensions (arXiv:2605.18747 §5.2.1, arXiv:2605.26112 §4.2) from existing Forge Studio artifacts and render a Markdown scorecard. Use when you want a snapshot of how well the harness is performing across trajectory efficiency, verification strength, recovery ability, state consistency, safety compliance, replayability, and memory hygiene.
when_to_use: Reach for this after a multi-task sprint, at the end of a session, or any time you want to assess whether harness quality is improving. Reads `.claude/traces/`, `.claude/evolution/change_manifest.jsonl`, `.claude/state/belief.jsonl`, and hook logs — no data is fabricated. Do NOT use as a gate — metrics are observational. Use /verify for gating.
argument-hint: "[manifest-path]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
scheduling: user asks for harness quality assessment, or sprint just completed and progress is unclear
structural:
  - Run score.sh (optionally passing a manifest path for testing)
  - Read the emitted Markdown table from stdout
  - Read .claude/metrics/<today>.json for raw numbers if delta comparison is needed
  - If .claude/metrics/ has a prior-day file, compare for delta
logical: a 7-row Markdown table appears in the response with numeric values or "n/a" for each dimension; .claude/metrics/<YYYY-MM-DD>.json is written
---

# /harness-metrics — Harness Quality Scorecard

Computes seven harness-level dimensions derived from artifacts already on disk — no inference, no fabrication. Six core dimensions defined in arXiv:2605.18747 §5.2.1; memory_hygiene added from arXiv:2605.26112 §4.2 (trustworthy memory: staleness penalty).

## The Seven Dimensions

| Dimension | Formula | Source artifact |
|-----------|---------|----------------|
| **trajectory_efficiency** | accepted manifest entries / total tool calls | `.claude/traces/*.jsonl` + manifest |
| **verification_strength** | % manifest entries with a non-empty `evidence_bundle.checks_run` list | `.claude/evolution/change_manifest.jsonl` |
| **recovery_ability** | % verify-failure events followed by a passing verify in the same session | hook logs / traces |
| **state_consistency** | 1 − (drift count / Edit calls) — pre/post sha256 pairs that diverged | `.claude/state/belief.jsonl` |
| **safety_compliance** | % PreToolUse block events that were honored (no manual override) | hook logs |
| **replayability** | % manifest entries with a non-empty `rollback_handle` field | `.claude/evolution/change_manifest.jsonl` |
| **memory_hygiene** | % `.claude/memory/topics/*.md` files whose `Last verified:` date is within 30 days | `.claude/memory/topics/*.md` |

**Unverified** means the `evidence_bundle` key is absent, null, `{}`, or has `checks_run` absent / null / `[]`. All four shapes count toward the denominator and not the numerator of `verification_strength`.

## Usage

```bash
# Score against real artifacts
bash plugins/forge-meta/skills/harness-metrics/scripts/score.sh

# Score against a synthetic manifest (for testing)
bash plugins/forge-meta/skills/harness-metrics/scripts/score.sh /tmp/test.jsonl
```

Output goes to stdout (Markdown table) and `.claude/metrics/<YYYY-MM-DD>.json`.

## Examples

### Example 1: established project with partial evidence

Input: manifest with 20 entries (12 have non-empty `checks_run`, 15 have non-empty `rollback_handle`); belief log shows 1 drift in 40 Edit calls; no traces directory.

Output:

```
| Dimension              | Score  | Notes                                       |
|------------------------|--------|---------------------------------------------|
| trajectory_efficiency  | n/a    | no traces directory                         |
| verification_strength  | 60%    | 12 / 20 entries verified                    |
| recovery_ability       | n/a    | no verify-failure history                   |
| state_consistency      | 97%    | 1 drift in 40 edits                         |
| safety_compliance      | n/a    | no hook block log                           |
| replayability          | 75%    | 15 / 20 entries have rollback_handle        |
| memory_hygiene         | 80%    | 4 / 5 topics verified within 30 days        |
```

### Example 2: new project, all empty evidence bundles

Input: manifest with 4 entries, all having absent/null/empty `evidence_bundle`; no memory topics directory.

Output:

```
| Dimension              | Score  | Notes                                       |
|------------------------|--------|---------------------------------------------|
| trajectory_efficiency  | n/a    | no traces directory                         |
| verification_strength  | 0%     | 0 / 4 entries verified                      |
| recovery_ability       | n/a    | no verify-failure history                   |
| state_consistency      | n/a    | no belief log                               |
| safety_compliance      | n/a    | no hook block log                           |
| replayability          | 0%     | 0 / 4 entries have rollback_handle          |
| memory_hygiene         | n/a    | no memory topics directory                  |
```

## Execution Checklist

- [ ] Run `bash plugins/forge-meta/skills/harness-metrics/scripts/score.sh` (optionally with manifest path arg)
- [ ] Verify exit code is 0
- [ ] Present the Markdown table from stdout in your response
- [ ] If `.claude/metrics/` has a prior-day file, compute delta for each dimension and note direction (up/down/same)
- [ ] If any dimension shows 0% (not n/a), note which artifact to populate to improve it

## Known Failure Modes

- **No manifest file**: all manifest-derived dimensions show `n/a`. The script exits 0 — missing artifacts are not errors.
- **Manifest with only legacy entries** (pre-S8, no `evidence_bundle`): `verification_strength` correctly shows 0% because all entries are unverified by the amended predicate.
- **Write failure on `.claude/metrics/`**: the script uses an atomic write (temp file → rename). If the directory cannot be created, a warning is printed to stderr but stdout table and exit 0 are preserved.
- **No memory topics directory** (`.claude/memory/topics/` absent or empty): `memory_hygiene` shows `n/a`. This is expected for projects that do not use the memory plugin or have no tier-2 topic files yet. It is not an error.
- **Topic file missing `Last verified:` field**: that file counts as stale toward `memory_hygiene`. The formula is conservative — only files with a parseable `Last verified: YYYY-MM-DD` line within the window count as fresh.
