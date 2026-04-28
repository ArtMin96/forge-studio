---
name: assess-proposal
description: Adversarial review of a self-evolution proposal artifact. Emits a pass/fail verdict against four criteria. Pure read — never mutates harness files.
when_to_use: Reach for this immediately after `/evolve` writes a proposal artifact, before any user approval or `/commit-proposal`. Do NOT use for general code review of un-versioned changes — that's `/challenge` or `/devils-advocate`; this skill is the SEPL `assess` operator gate against versioned harness resources.
disable-model-invocation: true
effort: xhigh
argument-hint: <proposal-path>
context: fork
agent: reviewer
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# /assess-proposal — SEPL `assess` Operator

Second of the three SEPL operators (propose → **assess** → commit). See `docs/lineage.md` for the full protocol.

Runs in a forked `reviewer` subagent so the assessor cannot "fix" the proposal by editing it — forcing an honest pass/fail call.

## Input

One argument: the path to a proposal artifact under `.claude/lineage/proposals/<slug>.md`. If no argument, read the most recent file in that directory.

A proposal artifact contains:

1. Target resource slug (`rules.d/...`, `skills/...`, `env/...`, etc.)
2. Current value or diff base
3. Proposed value or diff
4. Rationale + trigger source
5. Expected token / behavior impact

## The Four Criteria

Assess the proposal against each. All four must pass for verdict `pass`. Any fail → verdict `fail`. Mixed signal with a cleanup path → verdict `conditional` (document what needs to change).

### 1. Single-Variable Change

Does the proposal change **one** resource, **one** dimension? A rule tweak + a hook threshold shift + a skill rewrite in a single proposal hides the blast radius. Reject and tell the author to split.

### 2. Addresses Root Cause

Pattern-match against the trigger. If the trigger is "agent keeps editing before reading" and the proposal adds a nagging reminder, that's symptom patching. The right fix is a `research-gate` hook or an exploration gate. Reject if the proposed change rides past the underlying mechanism.

### 3. Honest Token / Behavior Impact

The proposal lists an impact estimate. Check it.
- `rules.d/` additions: ~30–50 chars × messages/session ≈ token cost per session. Proposals claiming "negligible" for a 200-char rule get flagged.
- Skill edits: compaction budget is 5,000 tokens/skill. New verbose sections push that ceiling.
- Hook additions: fires on every matched event — measure frequency.

If the estimate is missing, off by an order of magnitude, or suspiciously round ("~0 tokens"), fail the criterion.

### 4. No Regression of Existing Rules

Read the nearby resources:
- For `rules.d/` changes, read the other files in the same directory. Does the new rule contradict an existing one?
- For skill edits, check the skill's current callers (grep for the skill name across the repo).
- For `env/` changes, check defaults declared in the plugin's LIFECYCLE/README — does the new value violate assumptions documented there?

Any contradiction → fail the criterion with the conflicting file path cited.

## Output

Write a verdict JSON to `.claude/lineage/verdicts/<proposal-basename>.json`:

```json
{
  "proposal": ".claude/lineage/proposals/0420-brevity-v3.md",
  "verdict": "pass|fail|conditional",
  "criteria": {
    "single_variable": true,
    "root_cause": true,
    "honest_impact": true,
    "no_regression": true
  },
  "rationale": "<one-paragraph>",
  "blockers": ["<file:line or criterion name>"]
}
```

Then append a `assess` entry to `.claude/lineage/ledger.jsonl`:

```json
{"ts":"<UTC>","operator":"assess","resource":"<slug>","version":"<target>-assess","prev":"<current>","trigger":"proposal:<basename>","evidence":".claude/lineage/verdicts/<basename>.json","actor":"evaluator:/assess-proposal"}
```

## Do NOT

- Do not modify the proposal artifact. Return a verdict; the author edits.
- Do not apply the proposal, even partially. Commit is a separate operator owned by workflow.
- Do not lower the bar because a proposal came from another skill. `/trace-evolve` output gets the same scrutiny as user-drafted proposals.
- Do not emit a verdict without reading at least one neighboring resource — "no regression" cannot be asserted from the proposal alone.

## Examples

### Example 1: a clean pass

Input:
```
proposal: .claude/lineage/proposals/2026-04-28-context-pressure-bump.md
resource: env/FORGE_CONTEXT_PRESSURE_THRESHOLD
current:  0.65 (v2)
proposed: 0.70 (v3)
trigger:  trace-evolve cluster #4 — token-pipeline firing too eagerly on short sessions
impact:   ~+8% later trigger time; no compaction-budget change
neighbors: track-context-pressure.sh documents 0.65 as a tunable; no other resource references the variable.
```

Output:
```json
{
  "proposal": ".claude/lineage/proposals/2026-04-28-context-pressure-bump.md",
  "verdict": "pass",
  "criteria": {"single_variable": true, "root_cause": true, "honest_impact": true, "no_regression": true},
  "rationale": "Single env-var tweak, addresses the root false-positive trigger pattern observed in trace cluster #4, impact estimate matches the +7.7% delta, no neighbor depends on the prior value.",
  "blockers": []
}
```

### Example 2: a fail on root-cause

Input:
```
proposal: .claude/lineage/proposals/2026-04-28-no-edit-unread-reminder.md
resource: rules.d/85-do-not-edit-unread.txt
proposed: "Reminder: Read files before editing them. Always."
trigger:  research-gate denied 14 edits this week
impact:   ~30 chars × ~25 messages/session = ~750 chars/session
neighbors: research-gate/hooks/require-read-before-edit.sh already enforces this; adding a reminder rule is symptom patching since the hook already blocks.
```

Output:
```json
{
  "proposal": ".claude/lineage/proposals/2026-04-28-no-edit-unread-reminder.md",
  "verdict": "fail",
  "criteria": {"single_variable": true, "root_cause": false, "honest_impact": true, "no_regression": true},
  "rationale": "research-gate already enforces the constraint at the hook layer; an additional rule adds tokens without changing observable behavior. Root cause for the 14 denials is missing exploration before edit, which is the gate's job — not a rule's.",
  "blockers": ["root_cause: research-gate/hooks/require-read-before-edit.sh already covers this enforcement"]
}
```
