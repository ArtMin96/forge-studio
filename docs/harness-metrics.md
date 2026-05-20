# Harness Metrics

Forge Studio's `/harness-metrics` skill computes six quality dimensions defined in arXiv:2605.18747 §5.2.1 and renders them as a Markdown table. This doc explains what each dimension means, how to read the scorecard, what numbers are realistic at different maturity levels, and how to drive the numbers up.

---

## What This Measures

Six dimensions, each derived from artifacts already on disk. No inference; no fabricated values.

### trajectory_efficiency

Formula: `accepted manifest entries / total tool calls`

Source: `.claude/traces/*.jsonl` (tool-call log) and `.claude/evolution/change_manifest.jsonl` (accepted entries).

A high ratio means Claude reached a recorded, accepted outcome in fewer tool calls — less thrashing. A low ratio can mean exploratory work (acceptable) or repeated retries without convergence (worth investigating). Requires traces to be enabled (`FORGE_TRACES_ENABLED != 0`); shows `n/a` otherwise.

### verification_strength

Formula: `% manifest entries where evidence_bundle.checks_run is a non-empty list`

Source: `.claude/evolution/change_manifest.jsonl`

Entries are *unverified* when `evidence_bundle` is absent, `null`, `{}`, or has `checks_run` absent / `null` / `[]`. All four shapes count toward the denominator and not the numerator. A score of 0% means every entry shipped with no documented checks — any claimed quality is unverified. A score of 100% means every manifest entry declared at least one check that ran.

### recovery_ability

Formula: `% verify-failure events followed by a passing verify in the same session`

Source: `.claude/state/hook-blocks.jsonl` (if present)

Measures how reliably the harness self-corrects after a gate failure. `n/a` means no failure history was recorded — either nothing failed or the hook log is absent. High recovery ability indicates the verify loop is closing, not just surfacing failures.

### state_consistency

Formula: `1 − (drift count / Edit calls)`

Source: `.claude/state/belief.jsonl`

Each Edit call produces a `pre` and `post` sha256 snapshot via the belief-snapshot hook. A drift event is a pre/post pair where the sha256 is identical — the edit was a no-op or recorded against stale state. High consistency (near 100%) means Claude's belief about disk matched disk. Shows `n/a` if no belief log exists.

See also: [Belief Audit](belief-audit.md) for the full drift-detection workflow.

### safety_compliance

Formula: `% PreToolUse block events honored (no override)`

Source: `.claude/state/hook-blocks.jsonl`

Counts how often hook-emitted blocks were respected rather than bypassed. An override appears as `"override": true` in the block log. In normal operation this is 100% — blocks should always be honored unless the user explicitly cleared them via `/safe-mode off`. Shows `n/a` when no block log exists.

### replayability

Formula: `% manifest entries with a non-empty rollback_handle field`

Source: `.claude/evolution/change_manifest.jsonl`

A non-empty `rollback_handle` (e.g., `"git revert HEAD"`) means the change can be mechanically reversed. Low replayability means regressions require manual archaeology to undo. The field is part of the v2 manifest schema introduced with the transactional manifest update.

---

## How to Read the Scorecard

Running `/harness-metrics` produces a table like this:

```
| Dimension              | Score  | Notes                              |
|------------------------|--------|------------------------------------|
| trajectory_efficiency  | 42%    | 21 accepted / 50 tool calls        |
| verification_strength  | 60%    | 12 / 20 entries verified           |
| recovery_ability       | 80%    | 4 recoveries / 5 failures          |
| state_consistency      | 97%    | 1 drift in 40 edits                |
| safety_compliance      | 100%   | 8 / 8 blocks honored               |
| replayability          | 75%    | 15 / 20 entries have rollback_handle |
```

Reading this example:

- `trajectory_efficiency: 42%` — 50 tool calls for 21 manifest entries. Acceptable for exploratory work; investigate if this is a straightforward task.
- `verification_strength: 60%` — 8 of 20 entries have no documented checks. Actionable: add `evidence_bundle.checks_run` to those entries.
- `recovery_ability: 80%` — 4 of 5 failures recovered. One unresolved failure worth tracing.
- `state_consistency: 97%` — near-perfect. One stale-belief write in 40 edits.
- `safety_compliance: 100%` — all blocks honored.
- `replayability: 75%` — 5 entries have no rollback_handle. Those changes cannot be mechanically reversed.

The JSON snapshot written to `.claude/metrics/<YYYY-MM-DD>.json` lets `/session-digest` compare today's values against the prior session's file and surface the delta.

---

## What Numbers to Expect

These are rough ranges based on how consistently Forge Studio's harness patterns are being applied, not hard thresholds.

| Maturity stage | verification_strength | replayability | state_consistency |
|---|---|---|---|
| Greenfield / first sprint | 0–30% | 0–20% | n/a |
| Developing (2–5 sprints) | 30–60% | 20–50% | 80–95% |
| Established (6+ sprints) | 60–80% | 50–80% | 95–100% |

`trajectory_efficiency` varies widely by task type. A single-file fix might reach 80%; a major refactor exploring 20 files first might sit at 20%. Neither is inherently bad.

`safety_compliance` should be 100% in all stages — anything below 100% warrants immediate inspection of the block log.

`recovery_ability` depends on how often verify gates are hit. Early in a project with few gates, `n/a` is expected. An established project running `/verify` regularly should see 70%+.

---

## Driving Metrics Up

### verification_strength

Every manifest entry should declare `evidence_bundle.checks_run` with at least one check that ran (e.g., `["json-parse", "hook-exit-code"]`). The `change-manifest` skill's Execution Checklist includes this step. For legacy entries with no evidence bundle, `/evolution-history` will flag them as suspect.

See: [Transactional Manifest](transactional-manifest.md) for the full evidence_bundle field reference.

### state_consistency

Enable the belief-snapshot hook (ships with the context-engine plugin). It records sha256 of each file before and after every Edit call. Run `/belief-audit` periodically — especially after long absences or sessions that included a compaction — to surface any paths where disk and Claude's belief diverged.

See: [Belief Audit](belief-audit.md).

### recovery_ability

Apply `/verify` consistently before declaring tasks done. The recovery metric only accumulates signal when failures are recorded and then resolved. Sprints that never run `/verify` keep recovery_ability at `n/a`, which is neither good nor bad — it just means the gate loop isn't being used.

See: [Convergence Criteria](convergence.md) for how `/verify` uses the declared convergence criterion to determine done-ness.

### replayability

Add `rollback_handle` to every manifest entry. The `manifest-writer.sh` hook reads `MANIFEST_ROLLBACK_HANDLE` from the environment when auto-writing entries. For manually written entries, include the field in the JSONL write.

### trajectory_efficiency

Reduce exploratory thrashing by applying the `/scope` skill before starting, and `/orchestrate` for multi-step tasks. Traces must be enabled for this dimension to compute.

### safety_compliance

This metric is defensive — it should already be 100%. If it isn't, inspect `.claude/state/hook-blocks.jsonl` for entries with `"override": true` and understand why the override happened.

---

## Limitations

**Sample size**: all dimensions are computed over the full manifest history by default. A manifest with 3 entries gives statistically noisy percentages. Interpret low-entry scores cautiously.

**Rolling window**: the script does not apply a time window — it reads all entries. A project that started well and recently degraded may show a healthy aggregate while current work is poor. For trend analysis, compare `.claude/metrics/<date>.json` files across sessions using the delta shown in `/session-digest`.

**`n/a` means missing artifact, not low score**: `trajectory_efficiency: n/a` does not mean efficiency is bad — it means traces are disabled or the traces directory is absent. `recovery_ability: n/a` means no failure history exists. Treat `n/a` as "not yet measured," not as "failing."

**Belief log scope**: `state_consistency` counts pre/post pairs where sha256 is identical (the edit recorded no change). It does not directly measure cases where Claude believed a file had content X but it actually had content Y at the time of reading — that requires running `/belief-audit` interactively.

**No auto-thresholding**: these metrics are observational. The harness does not refuse to proceed or block on low scores. Use `/verify` for behavioral gating; use `/harness-metrics` for trend awareness.
