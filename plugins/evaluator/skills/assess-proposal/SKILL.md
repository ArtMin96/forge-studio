---
name: assess-proposal
description: Adversarial review of a self-evolution proposal artifact. Emits a pass/fail verdict against four criteria. Pure read — never mutates harness files.
disable-model-invocation: true
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
