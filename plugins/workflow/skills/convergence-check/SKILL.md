---
name: convergence-check
description: Internal helper — parses a plan file's `## Convergence` section and evaluates its `criterion` shell command against current state. Returns a structured report with `met`, `evidence`, and `gap` fields. Called by /verify and /status; not for direct user invocation.
when_to_use: Reach for this when /verify or /status needs to evaluate whether a declared convergence criterion is satisfied before claiming a sprint is done. Do NOT use for ad-hoc edits without a plan — convergence only applies when a plan declares it. Use /verify directly for plan-less work.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
scheduling: an active plan declares a `## Convergence` section with a `criterion` field, and /verify or /status needs to evaluate it
structural:
  - Locate the plan file (argument or active plan resolved via `find-active-plan.sh`)
  - Parse the `## Convergence` section for `type`, `criterion`, and `max_iterations`
  - Execute the criterion command with a 10-second timeout
  - Report exit code, stdout evidence, and gap description
logical: stdout contains a structured report with `plan_path`, `convergence_type`, `criterion`, `criterion_exit_code`, `met`, and `evidence_lines`; exit 0 when criterion is met, 1 when unmet, 2 when no convergence block, 3 when plan not found
---

# convergence-check — Evaluate a Plan's Convergence Criterion

Internal helper skill. Called by `/verify` (to gate "done" claims) and `/status` (to show progress vs criterion). The user rarely invokes this directly — it surfaces through the callers.

## What it evaluates

A plan's `## Convergence` section declares a machine-checkable predicate:

```
## Convergence
```yaml
convergence:
  type: test-gated
  criterion: "bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh . | grep '^19 plugins'"
  max_iterations: 5
```

The `criterion` value is a shell command. This skill runs it with a 10-second timeout and checks the exit code: 0 = criterion met, non-zero = criterion unmet.

Trust model: the user wrote the plan file. Commands in `criterion` run with the same privilege as any other shell command the user authorizes. The user accepts this when they write the plan.

## Execution Checklist

- [ ] Locate the plan file — use the argument if given; otherwise resolve via `plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh` (single source of truth for the active plan)
- [ ] Verify the plan file exists — exit 3 if not found
- [ ] Parse the `## Convergence` section for `type`, `criterion`, and `max_iterations` — exit 2 if no convergence block
- [ ] Execute `criterion` in a subshell with `timeout 10` — capture stdout, stderr, and exit code
- [ ] Emit a structured report to stdout: `plan_path`, `convergence_type`, `criterion`, `criterion_exit_code`, `met` (true/false), `evidence_lines`
- [ ] Exit 0 if criterion met, 1 if unmet, 2 if no convergence block, 3 if plan not found

## Script

```bash
bash plugins/workflow/skills/convergence-check/scripts/check.sh [plan-path]
```

Optional `plan-path` argument: absolute or repo-relative path to a plan file. If omitted, the script resolves the active plan via `plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh` (the canonical resolver — same one used by `/orchestrate`, `/contract`, and the after-subagent hook). If the resolved plan has no `## Convergence` section, exit 2 (skip gracefully — implicit convergence is valid for one-shot edits).

## Input / Output Examples

### Example 1 — criterion passes

Input: `.claude/plans/s5-billing.md` contains:
```
## Convergence
```yaml
convergence:
  type: test-gated
  criterion: "test -f README.md"
  max_iterations: 3
```
```

Running:
```
bash plugins/workflow/skills/convergence-check/scripts/check.sh .claude/plans/s5-billing.md
```

Output (stdout):
```
plan_path: .claude/plans/s5-billing.md
convergence_type: test-gated
criterion: test -f README.md
criterion_exit_code: 0
met: true
evidence_lines: (no stdout — exit 0 is the evidence)
```

Exit code: `0`

### Example 2 — criterion fails

Input: `.claude/plans/s6-auth.md` contains:
```
## Convergence
```yaml
convergence:
  type: hybrid
  criterion: "python3 -c \"import json; json.load(open('.claude-plugin/marketplace.json'))\" && bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh . | grep '^20 plugins'"
  max_iterations: 5
```
```

Running:
```
bash plugins/workflow/skills/convergence-check/scripts/check.sh .claude/plans/s6-auth.md
```

Output (stdout):
```
plan_path: .claude/plans/s6-auth.md
convergence_type: hybrid
criterion: python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" && bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh . | grep '^20 plugins'
criterion_exit_code: 1
met: false
evidence_lines: 19 plugins. 78 skills. 72 hooks. 4 agents. 14 behavioral rules.
gap: criterion exited 1 — expected 20 plugins, count.sh reports 19
```

Exit code: `1`
