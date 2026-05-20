# Convergence Criteria

When does a sprint end? Without a declared criterion, the answer is "when the user says so" — implicit, unauditable, and easy to get wrong after a long session. Convergence criteria make the exit condition machine-checkable.

Paper reference: arXiv:2605.18747 §4.3.2 enumerates six convergence types for multi-step agent work.

---

## Why declare convergence

A sprint contract without a convergence criterion relies on the user as oracle. That's fine for quick one-shot edits. For a multi-day refactor touching 15 files, it creates three risks:

1. **Intent drift** — what "done" means at the start of a sprint may shift as the implementation reveals constraints. A written criterion anchors the definition.
2. **Invisible gaps** — without a machine check, it's easy to ship a sprint where 11 of 12 contract items pass and the 12th was forgotten.
3. **Non-reproducible acceptance** — "I reviewed the diff and it looked right" cannot be re-run by a reviewer, a future agent, or a CI pipeline.

Declaring `convergence:` in a plan file converts sprint termination from a vibes decision into a quoted artifact.

---

## Six types with one-line examples

Based on arXiv:2605.18747 §4.3.2:

| Type | What passes | One-line example |
|---|---|---|
| **test-gated** | All designated tests exit 0 | `criterion: "./vendor/bin/pest --filter=BillingUpgrade"` |
| **security-gated** | No policy violations detected | `criterion: "bash plugins/policy-gateway/hooks/secrets-scan.sh ."` |
| **performance-gated** | Metric stays within a bound | `criterion: "bash scripts/bench.sh \| awk '/p99/{exit($2>200)}'"` |
| **score-based** | Aggregate rubric score ≥ threshold | `criterion: "bash plugins/evaluator/skills/score-rubric/scripts/score.sh \| grep 'PASS'"` |
| **consensus** | Multiple reviewers all pass | `criterion: "test -f .claude/gate/reviewer-1.pass -a -f .claude/gate/reviewer-2.pass"` |
| **hybrid** | Combination of the above | `criterion: "bash run-tests.sh && python3 -c \"import json; json.load(open('.claude-plugin/marketplace.json'))\""` |
| **implicit** | User judgment (no criterion declared) | *(no `## Convergence` section in plan)* |

Implicit is valid — see below for when it's appropriate.

---

## Syntax

Add a `## Convergence` section to the plan file (`.claude/plans/<slug>.md`), after `## Why this sprint exists`:

```
## Convergence
```yaml
convergence:
  type: hybrid
  criterion: "<shell command — exits 0 when done, non-zero when not>"
  max_iterations: 5
```
```

Fields:

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | One of: `test-gated`, `security-gated`, `performance-gated`, `score-based`, `consensus`, `hybrid`, `implicit` |
| `criterion` | yes | Shell command evaluated with `bash -c`. Exit 0 = met. Runs with 10s timeout. |
| `max_iterations` | no | Advisory cap on agent loops — recorded but not enforced this release. |

Trust model: the criterion runs with the same privilege as any other shell command you authorize. You wrote the plan, you accept the commands in it.

---

## How /verify uses it

When `/verify` runs and the active plan declares a convergence block, it calls:

```bash
bash plugins/workflow/skills/convergence-check/scripts/check.sh
```

The refusal flow when criterion is unmet:

```
User: "/verify"
  │
  ▼
/verify reads active plan
  │
  ├─ ## Convergence found?
  │     │
  │    yes ─▶ run check.sh
  │                 │
  │            met: true ─▶ continue normal verify steps
  │                 │
  │            met: false ─▶ VERIFIED: No
  │                          quote criterion verbatim
  │                          quote check.sh output verbatim
  │                          do NOT clear evaluation-gate.flag
  │
  └─ no ## Convergence ─▶ continue with current verify behavior (implicit)
```

Example refusal output when criterion is unmet:

```text
VERIFIED: No
METHOD: convergence-check + features.json
EVIDENCE: convergence criterion not met

Convergence check output:
  plan_path: .claude/plans/s8-refactor.md
  convergence_type: test-gated
  criterion: ./vendor/bin/pest --filter=BillingUpgrade
  criterion_exit_code: 1
  met: false
  evidence_lines: FAILED Tests\Feature\BillingUpgradeTest::test_returns_200 (0.21s)
  gap: criterion exited 1 — review evidence_lines above

REMAINING RISK: sprint is not done — fix the failing test before claiming done
```

---

## When implicit is fine

- One-shot edits (fix a typo, rename a variable, update a single doc).
- Exploratory sessions where the goal is to understand a codebase, not produce a specific artifact.
- Any task where "done" is self-evidently binary and the user is present to judge.

For these, skip the `## Convergence` section entirely. `/verify` will use its normal evidence-gate logic without a convergence check.

---

## When implicit is dangerous

- Multi-day sprints touching 5+ files across multiple sessions. Context compaction between sessions means the model's memory of "what done looks like" may drift from the original intent.
- Sprints where acceptance depends on a metric (performance, test coverage, rubric score) that is easy to mis-remember.
- Any sprint handed off between agents or sessions — the next session starts fresh; it cannot recover the original intent without a machine-checkable criterion on disk.

In these cases, a criterion is the difference between a reproducible handoff and a vibes-based restart.
