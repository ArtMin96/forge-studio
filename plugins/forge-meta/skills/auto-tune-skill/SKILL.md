---
name: auto-tune-skill
description: STUB — produces a baseline proposal file for a target skill at `.claude/proposals/<skill>-<timestamp>.md`. The autonomous mutation/scoring/Pareto outer loop (Meta-Harness Algorithm 1) is documented in this skill body as future work; current iteration is a no-op that emits the original SKILL.md as a starting candidate. Never modifies the original SKILL.md.
when_to_use: Reach for this when a skill's eval pass rate is below target, the `when_to_use` guidance keeps misfiring, or you want a data-driven rewrite of the skill body without touching frontmatter. Give it a `plugin:skill-id` pair (e.g. `diagnostics:entropy-scan`) — the matching `evals/evals.json` must exist. Do NOT use for frontmatter edits or new-skill authoring — write or edit the SKILL.md directly instead.
argument-hint: <plugin>:<skill-id>
scheduling: a skill's eval pass rate is below target, or repeated misfires suggest the when_to_use guidance needs tightening
structural:
  - Parse the plugin:skill-id argument; validate SKILL.md and evals/evals.json exist
  - Run run-iteration.sh which writes a baseline proposal (stub mode — scoring + mutation subagent not yet shipped)
  - Each iteration would produce a candidate with mutations to the SKILL.md body only (frontmatter immutable); stub mode emits the original unchanged
  - Score each candidate by (pass-rate via /run-evals, token-cost); keep Pareto-best — NOT YET IMPLEMENTED
  - Write the proposal to .claude/proposals/<plugin>-<skill>-<iso-timestamp>.md
  - Log each iteration to .claude/evolution/auto-tune-runs.jsonl with mode="stub"
logical: .claude/proposals/<plugin>-<skill>-<timestamp>.md exists, contains the original frontmatter unchanged, and carries a footer explaining the next steps for the reviewer
---

# /auto-tune-skill — Outer-Loop Skill Proposer

Iterates on a single SKILL.md's body using the outer-loop algorithm from Meta-Harness 2603.28052 Algorithm 1 (p.5). Each iteration spawns a `context: fork` subagent to propose mutations, scores the result with `/run-evals`, and tracks the Pareto frontier by (pass-rate, token-cost). The Pareto-best candidate is written as a proposal file for human review.

The original SKILL.md is never modified. The proposal is a standalone file the user can inspect, diff against the original, and apply manually.

## Scope Constraint

This skill mutates the SKILL.md **body only**. Frontmatter fields (`name`, `description`, `when_to_use`, argument-hint, SSL overlay fields) are immutable across all iterations. The loop is barred from editing protected paths via the `pre-edit-guard.sh` hook (FORGE_META_EVOLVE=1 is set during iterations).

## Usage

```bash
/auto-tune-skill diagnostics:entropy-scan
/auto-tune-skill memory:recall
```

Or invoke `run-iteration.sh` directly with an optional iteration cap:

```bash
FORGE_AUTO_TUNE_ITERS=10 bash plugins/forge-meta/skills/auto-tune-skill/scripts/run-iteration.sh diagnostics:entropy-scan
```

## Algorithm (Meta-Harness §3, Algorithm 1)

The outer loop runs up to `FORGE_AUTO_TUNE_ITERS` iterations (default 5 for smoke-test; real tuning sets 20). Per iteration:

1. A `context: fork` subagent reads the current best candidate and proposes 2 body mutations.
2. Each mutation is scored by running the skill's `evals/evals.json` via `/run-evals`.
3. Score = `(pass_rate, -token_cost)` — higher pass rate wins; ties broken by lower token cost.
4. Pareto-best replaces the current candidate if it dominates on at least one axis without regressing the other.

Convergence: Meta-Harness p.5 baseline is ~20 iterations × 2 candidates ≈ 40 eval runs. The default smoke-test cap of 5 is intentionally low; raise `FORGE_AUTO_TUNE_ITERS` for real optimization.

## Stub Behaviour (Current Implementation)

The subagent dispatch for mutation generation requires `context: fork` semantics and an inter-process coordination protocol that a single shell script cannot safely drive. The current `run-iteration.sh` implements the harness shape:

- Validates paths and evals presence.
- Copies the current SKILL.md to `.claude/proposals/<plugin>-<skill>-<iso-timestamp>.md`.
- Prepends `proposal_status: unreviewed` outside the frontmatter block.
- Appends a reviewer footer block describing next steps.
- Logs each run to `.claude/evolution/auto-tune-runs.jsonl`.

The autonomous mutation generator (the `context: fork` subagent that proposes body rewrites) is the planned follow-up: once the inter-process protocol is stable, `run-iteration.sh` will dispatch it per iteration and collect scores from `/run-evals`.

## Proposal File Format

The output file at `.claude/proposals/<plugin>-<skill>-<iso-timestamp>.md` looks like:

```
proposal_status: unreviewed

---
name: entropy-scan
... (original frontmatter unchanged) ...
---

... (SKILL.md body, possibly mutated by future autonomous loop) ...

---
<!-- auto-tune proposal footer -->
...reviewer instructions...
```

## Examples

### Example 1: valid skill with evals

Input: `diagnostics:entropy-scan` (has `evals/evals.json`)

Output: `.claude/proposals/diagnostics-entropy-scan-20260513T090000Z.md` written; `.claude/evolution/auto-tune-runs.jsonl` gains one entry.

### Example 2: skill without evals

Input: `workflow:orchestrate` (no `evals/evals.json`)

Output: exit 1 with message "evals.json not found for workflow:orchestrate — add evals/evals.json before auto-tuning".

## Execution Checklist

- [ ] Identify the target skill: `<plugin>:<skill-id>`
- [ ] Confirm `plugins/<plugin>/skills/<skill>/evals/evals.json` exists (or create it first)
- [ ] Run: `/auto-tune-skill <plugin>:<skill-id>`
- [ ] Inspect the proposal file in `.claude/proposals/`
- [ ] Diff against original: `diff plugins/<plugin>/skills/<skill>/SKILL.md .claude/proposals/<plugin>-<skill>-<timestamp>.md`
- [ ] If satisfied, copy proposal body back into the original SKILL.md (frontmatter stays unchanged)
- [ ] Re-run `/run-evals <plugin>:<skill-id>` on the updated SKILL.md to confirm score improvement

## Known Failure Modes

- **No evals.json**: the script exits 1 with a clear message. Auto-tuning without evals is meaningless — add eval cases first.
- **Protected path blocked**: if `FORGE_META_EVOLVE=1` is set during an iteration and the loop tries to write to a protected path, `pre-edit-guard.sh` blocks the edit (exit 2). The proposal file is written to `.claude/proposals/` which is never a protected path.
- **Proposal directory missing**: `run-iteration.sh` creates `.claude/proposals/` with `mkdir -p` before writing.
