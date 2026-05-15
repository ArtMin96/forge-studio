---
name: auto-tune-skill
description: Outer-loop proposer that iterates on a single SKILL.md body, scores each candidate via /run-evals-bench, computes a Pareto frontier on (pass_rate, token_cost), and writes the Pareto-best revision to .claude/proposals/<plugin>-<skill>-<timestamp>.md for human review. Never modifies the original SKILL.md; the user applies the proposal manually.
when_to_use: Reach for this when a skill's eval pass rate is below target, the `when_to_use` guidance keeps misfiring, or you want a data-driven rewrite of the skill body without touching frontmatter. Give it a `plugin:skill-id` pair (e.g. `diagnostics:entropy-scan`) — the matching `evals/evals.json` must exist. Do NOT use for frontmatter edits or new-skill authoring — write or edit the SKILL.md directly instead.
argument-hint: <plugin>:<skill-id>
scheduling: a skill's eval pass rate is below target, or repeated misfires suggest the when_to_use guidance needs tightening
structural:
  - Validate args and confirm SKILL.md + evals/evals.json exist; invoke run-iteration.sh to create workspace
  - For each iteration 1..N, dispatch K=FORGE_AUTO_TUNE_K context:fork subagents — each proposes one mutated SKILL.md body
  - Score each candidate via score-candidate.sh (bench.py swap-restore); collect JSON {candidate_id, pass_rate, token_cost}
  - Invoke pareto-best.py over cumulative non-dominated candidates to find the lex-best (max pass_rate, tie-break min token_cost)
  - If pareto_best.pass_rate >= 1.0 or last iteration reached, break; otherwise feed Pareto-best body as next iteration baseline
  - Write final Pareto-best body to .claude/proposals/<plugin>-<skill>-<timestamp>.md
logical: .claude/proposals/<plugin>-<skill>-<timestamp>.md exists, contains the Pareto-best candidate body (frontmatter unchanged), and the original SKILL.md is bit-for-bit identical to before the run
---

# /auto-tune-skill — Outer-Loop Skill Proposer

> Candidate selection: before running this skill on an unfamiliar SKILL.md, use `bash plugins/forge-meta/skills/skill-staleness-audit/scripts/score.sh --format=json | jq '.skills | map(select(.score < 0.5)) | .[].path'` to surface the skills with the lowest staleness scores. They are the highest-leverage targets.

Iterates on a single SKILL.md body using the outer-loop algorithm from Meta-Harness 2603.28052 Algorithm 1 (p.5). Each iteration spawns `context: fork` subagents to propose body mutations, scores each via `/run-evals-bench`, and maintains a Pareto frontier by (pass_rate, token_cost). The Pareto-best candidate is written as a proposal file for human review.

The original SKILL.md is never modified. The proposal is a standalone file the user inspects, diffs against the original, and applies manually.

## Scope Constraint

This skill mutates the SKILL.md body only. Frontmatter fields (`name`, `description`, `when_to_use`, argument-hint, SSL overlay fields) are immutable across all iterations. The loop writes candidates and proposals to `.claude/proposals/` which is not a protected path — the `pre-edit-guard.sh` hook does not interfere.

## Smoke-test Mode

Set `FORGE_AUTO_TUNE_MOCK=1` to pass `--mock` to bench.py. Mock mode skips real `claude -p` API calls and returns synthetic scores so the loop can be exercised without burning eval budget. Candidates are still written and Pareto selection still runs — only the scoring uses placeholder values (pass_rate=0.5, token_cost=1000).

## Orchestration Recipe

Execute the following steps when invoked as `/auto-tune-skill <plugin>:<skill-id>`:

### Step 1 — Validate and create workspace

```bash
WORKSPACE=$(bash plugins/forge-meta/skills/auto-tune-skill/scripts/run-iteration.sh <plugin>:<skill-id>)
```

This validates that `plugins/<plugin>/skills/<skill-id>/SKILL.md` and `plugins/<plugin>/skills/<skill-id>/evals/evals.json` both exist, creates the workspace at `.claude/proposals/<plugin>-<skill-id>-<timestamp>/iter-1/`, logs iteration metadata to `.claude/evolution/auto-tune-runs.jsonl`, and prints the workspace path on stdout.

If `run-iteration.sh` exits nonzero, stop and report the error.

### Step 2 — Outer loop (iterations 1..N)

N = `${FORGE_AUTO_TUNE_ITERS:-3}`. K = `${FORGE_AUTO_TUNE_K:-3}`.

For each iteration `i` from 1 to N:

#### 2a — Dispatch K mutation subagents

Dispatch K subagents in `context: fork` mode. Each receives the current best SKILL.md body (start of iteration 1: the original `plugins/<plugin>/skills/<skill-id>/SKILL.md`; subsequent iterations: the Pareto-best body from the previous iteration). Use this exact prompt template for each subagent:

```
You are a skill-body mutation agent. Your task is to propose ONE improved version of the following SKILL.md body. Rules:
- You may only modify the body text below the closing `---` of the YAML frontmatter.
- Do NOT change any frontmatter fields (name, description, when_to_use, argument-hint, SSL overlay fields).
- Your mutation should improve clarity, instruction specificity, or eval pass rate.
- Output ONLY the complete SKILL.md (frontmatter + mutated body), no commentary.

Current best SKILL.md body:
<insert full SKILL.md content here>
```

Write each subagent's output to `$WORKSPACE/iter-<i>/candidate-<k>.md` (where k = 1..K).

#### 2b — Score each candidate

For each candidate file at `$WORKSPACE/iter-<i>/candidate-<k>.md`:

```bash
RESULT=$(bash plugins/forge-meta/skills/auto-tune-skill/scripts/score-candidate.sh \
  "$WORKSPACE/iter-<i>/candidate-<k>.md" \
  "<plugin>:<skill-id>" \
  [--mock if FORGE_AUTO_TUNE_MOCK=1])
```

`score-candidate.sh` temporarily swaps the candidate into `plugins/<plugin>/skills/<skill-id>/SKILL.md`, runs `bench.py --skill <skill-id> --iterations 1`, parses the result, and restores the original. It outputs JSON on stdout:

```json
{"candidate_id": "candidate-<k>.md", "pass_rate": 0.87, "token_cost": 1420}
```

Write the result JSON to `$WORKSPACE/iter-<i>/candidate-<k>.json`.

#### 2c — Compute Pareto-best

After all K candidates in iteration `i` are scored, collect all JSON result files from all iterations 1..i:

```bash
python3 plugins/forge-meta/skills/auto-tune-skill/scripts/pareto-best.py \
  $WORKSPACE/iter-*/candidate-*.json
```

`pareto-best.py` computes the non-dominated set (a dominates b iff a.pass_rate >= b.pass_rate AND a.token_cost <= b.token_cost, with at least one strict inequality) and emits the lex-best winner (max pass_rate, tie-break min token_cost) as JSON on stdout.

#### 2d — Termination check

- If `pareto_best.pass_rate >= 1.0`, the loop has converged — break.
- If iteration `i` equals N, break.
- Otherwise: the Pareto-best body (read from `$WORKSPACE/iter-<i>/candidate-<winner-k>.md`) becomes the baseline for iteration i+1. Create `$WORKSPACE/iter-<i+1>/` and proceed.

### Step 3 — Write proposal

Copy the Pareto-best candidate body to the final proposal file:

```bash
cp "$WORKSPACE/iter-<best-i>/candidate-<best-k>.md" \
   ".claude/proposals/<plugin>-<skill-id>-<timestamp>.md"
```

Prepend the status line:

```
proposal_status: unreviewed
iteration_count: <N>
pareto_pass_rate: <float>
pareto_token_cost: <int>

```

### Step 4 — Confirm to user

Report:
- The proposal file path.
- The Pareto-best score: `pass_rate=<X>, token_cost=<Y>`.
- The original SKILL.md is unchanged (verify with `md5sum` or `diff`).
- How to apply: `cp .claude/proposals/<...>.md plugins/<plugin>/skills/<skill-id>/SKILL.md` then run `/run-evals <plugin>:<skill-id>`.

## Execution Checklist

- [ ] Identify the target: `<plugin>:<skill-id>`
- [ ] Confirm `plugins/<plugin>/skills/<skill>/evals/evals.json` exists (create it first if not)
- [ ] (Optional) set `FORGE_AUTO_TUNE_MOCK=1` for a smoke test without burning eval budget
- [ ] Run: `/auto-tune-skill <plugin>:<skill-id>`
- [ ] Run-iteration.sh creates workspace and logs — confirm workspace path printed
- [ ] Dispatch K mutation subagents per iteration
- [ ] Score each candidate with score-candidate.sh
- [ ] Run pareto-best.py to select winner
- [ ] Write proposal file to `.claude/proposals/`
- [ ] Diff against original: `diff plugins/<plugin>/skills/<skill>/SKILL.md .claude/proposals/<plugin>-<skill>-<timestamp>.md`
- [ ] If satisfied: `cp .claude/proposals/<...>.md plugins/<plugin>/skills/<skill>/SKILL.md`
- [ ] Re-run `/run-evals <plugin>:<skill-id>` on the updated SKILL.md to confirm score improvement

## Input / Output Examples

### Example 1: successful tune

Input: `/auto-tune-skill memory:recall` (has evals/evals.json, pass_rate currently 0.6)

Output: `.claude/proposals/memory-recall-20260514T090000Z.md` — body rewritten to improve scoring guidance; Pareto-best candidate shows pass_rate=0.9, token_cost=1200. Original `plugins/memory/skills/recall/SKILL.md` unchanged.

### Example 2: skill without evals

Input: `/auto-tune-skill workflow:orchestrate` — wait, this skill has evals.json. Bad example: `/auto-tune-skill workflow:plan-session`

Output: exit 1, "evals.json not found for workflow:plan-session — add evals/evals.json before auto-tuning".

## Known Failure Modes

- **No evals.json**: run-iteration.sh exits 1 with a clear message. Auto-tuning without evals is meaningless — add eval cases first.
- **score-candidate.sh fails to restore**: the EXIT trap handles this; a `*.autotune-bak.<pid>` orphan may remain in the skill directory if the process is kill -9'd, but normal exits always restore. Clean up with `find plugins -name '*.autotune-bak.*' -delete`.
- **flock unavailable**: score-candidate.sh uses `flock`; on macOS the syntax differs. On Linux (this project's target platform) `flock -x <fd>` is standard.
- **All candidates dominate each other** (identical scores): pareto-best.py still returns the first candidate alphabetically by candidate_id as the lex-best — the proposal is written and the run completes normally.
