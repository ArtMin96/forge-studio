---
name: verify
description: Use whenever a task is about to be marked done — runs the listed verification commands (tests, lint, type-check, behavioral spot-check), captures the actual output, and compares against `.claude/features.json` or the `/contract` criteria. Refuses to mark done unless every gate produced evidence; closes the trust-then-verify gap that produces "I think it works" claims.
when_to_use: Reach for this before committing, merging, or telling the user "fixed". Do NOT use for deep adversarial review — that's `/challenge` (fork-based critique); verify is the cheap, in-line evidence gate that runs first. Do NOT skip the convergence check just because tasks look complete — use /safe-mode if convergence is ambiguous.
effort: xhigh
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
counterexamples:
  - "Deep adversarial review — use /challenge for fork-based critique after verify passes."
  - "Routine compile check during active development with no contract to gate against."
  - "Change set is empty (clean tree with no recent commits or edits)."
  - "Marking a task done on a doc-only change without running git diff --stat first."
contract:
  required_outputs:
    - "Per-criterion evidence report with command output quoted."
    - ".claude/gate/features.json populated for features with verify_cmd."
  budget: "Per-criterion test timeout (command exit determines pass/fail)"
  permission_scope: "Read + Bash (test runners only; no Write outside gate path)"
  completion_conditions:
    - "Every Contract success criterion has an evidence line (command output or file:line reference)."
    - "Overall verdict is PASS only if all criteria show evidence; FAIL if any criterion lacks evidence."
  output_paths:
    - "stdout"
    - ".claude/gate/features.json"
scheduling: an active plan exists in `.claude/plans/` with verification commands declared in its Contract section, OR a generator has just stopped and contract-check.sh nudged
structural:
  - Read the plan's verification commands verbatim
  - Execute each command and capture exit code + truncated output
  - Cross-reference declared artifacts against the working tree
  - Emit a per-criterion pass/fail report with quoted evidence
logical: every Contract success criterion has an evidence line (command output or file:line reference); overall verdict is PASS only if all criteria show evidence
---

# Verify: Evidence Before Assertions

From Anthropic's best practices: "The single highest-leverage thing you can do is include tests, screenshots, or expected outputs so Claude can verify its own work."

Before marking this task complete, answer EVERY question:

## 1. What Changed?
- List every file modified and what changed in each (one line per file)
- Run `git diff --stat` to confirm

## 2. What's the Verification Method?
Pick one or more:
- **features.json (preferred)**: If `.claude/features.json` exists (long-session plugin), execute each `verify_cmd` for features matching the current work. Record results to `.claude/gate/features.json`. `done` status only counts if the verify_cmd actually passed.
- **Tests**: Run the test suite. Show output. All pass? Which tests cover this change?
- **Build**: Does it compile/build without errors? Run the build command.
- **Manual check**: Describe what to look at and what the expected behavior is.
- **Type check**: Run static analysis if available.

### features.json execution (long-session integration)

If `.claude/features.json` is present:
1. Read it; for each entry with `status ∈ {pending, in_progress}`, run its `verify_cmd` (skip `# manual` entries; report them as needing human check).
2. Capture stdout/stderr + exit code.
3. Write `.claude/gate/features.json` with `[{id, verify_cmd, exit_code, passed, tail}]`.
4. Flip `status: done` only for entries where `passed: true`. Never auto-flip on `# manual`.
5. Report pass/fail counts in the verdict.

This is the evidence the reviewer and /gate-report read.

### 2b. Convergence criterion check (if plan declares one)

If the active plan has a `## Convergence` section, run the criterion before claiming done:

```bash
bash plugins/workflow/skills/convergence-check/scripts/check.sh
```

Quote the full output verbatim. If `met: false`, the verdict is `VERIFIED: No` regardless of other gates — the sprint is not done until the declared criterion is satisfied.

If the plan has no `## Convergence` section (exit code 2 from check.sh), proceed with current verification behavior — implicit convergence is valid for one-shot edits.

## 3. Run the Verification
Actually run it. Show the output. Don't say "it should work" — show that it DOES work.

## 3b. Ground in Actual Output
Quote the actual output — don't paraphrase it. Copy-paste the real test output, build output, or command result. If you can't quote real output, you haven't verified.

Bad: "Tests pass successfully."
Good: "Output: `Tests: 42 passed, 0 failed (0.83s)`"

## 4. Edge Cases
- What's the most likely way this breaks?
- Did you handle null/empty/boundary inputs?
- What happens if this runs twice?

## 5. Verdict
```text
VERIFIED: [Yes/No]
METHOD: [tests/build/manual/type-check]
EVIDENCE: [One line summary of proof]
REMAINING RISK: [What could still go wrong, or "None identified"]
```

If you CANNOT verify the change:
```text
UNVERIFIED: Cannot verify this change.
NEEDED: [What would be needed to verify — test command, expected output, etc.]
```

### 5a. Per-Criterion Structured Gradient (on FAIL only)

When one or more criteria fail, emit one structured triple per failed criterion immediately after the verdict block. The `plugins/evaluator/hooks/auto-verify.sh` hook (SubagentStop) already emits this same schema automatically — the /verify skill's output should match it so downstream readers see one consistent signal.

```text
- Dimension: <criterion-id from Contract or features.json entry id>
- Direction: FAIL  (or MIXED for partial-evidence cases)
- Magnitude: <one-line remediation suggestion>
```

**Field sourcing rules** — Dimension and Direction come from deterministic sources: test runner exit code, file existence check, or `features.json` `verify_cmd` result. Magnitude is the only LLM-inferred field; everything else is a quoted artifact.

**Example — FAIL path:**

```text
VERIFIED: No
METHOD: features.json + tests
EVIDENCE: 2 of 4 criteria failed (see gradient below)
REMAINING RISK: gate/features.json shows exit_code=1 for auto-verify entry

- Dimension: contract-criterion-3
- Direction: FAIL
- Magnitude: run-evals.sh exits 1 — expected output schema changed; update evals.json assertions to match new format

- Dimension: contract-criterion-4
- Direction: FAIL
- Magnitude: plugins/evaluator/hooks/auto-verify.sh not executable; run chmod +x to fix
```

**Example — PASS path (no gradient emitted):**

```text
VERIFIED: Yes
METHOD: tests
EVIDENCE: all 42 tests pass (exit 0)
REMAINING RISK: None identified
```

## 6. Clear the Evaluation Gate (if applicable)

If VERIFIED=Yes and an active plan exists in `.claude/plans/`:
```bash
# Write the plan name to the gate flag file
echo "{plan-name}" > ~/.claude/evaluation-gate.flag
```
This clears the pre-commit evaluation gate for the current plan, allowing `git commit` to proceed without a warning.

If UNVERIFIED, do NOT clear the gate — the warning serves its purpose.

Never claim work is done without evidence. Evidence, not assertions.

## Execution Checklist

- [ ] Step 1 — list every modified file with `git diff --stat` and a one-line description of each
- [ ] Step 2 — pick the verification method(s): features.json (preferred), tests, build, manual, type-check
- [ ] features.json path — for each `pending`/`in_progress` entry: run its `verify_cmd`, capture exit code + tail, write `.claude/gate/features.json` with `[{id, verify_cmd, exit_code, passed, tail}]`, flip `status: done` only on `passed: true` (skip `# manual`)
- [ ] Step 2b — Convergence criterion verified (if plan declares one): run `bash plugins/workflow/skills/convergence-check/scripts/check.sh` and quote the criterion + result verbatim; refuse "done" if `met: false`
- [ ] Step 3/3b — actually run the verification; quote the literal output, never paraphrase
- [ ] Step 4 — name the most likely failure mode, null/empty/boundary handling, and double-run behavior
- [ ] Step 5 — emit the verdict block (VERIFIED / METHOD / EVIDENCE / REMAINING RISK) or the UNVERIFIED + NEEDED block
- [ ] Step 5a — on FAIL, emit one Dimension/Direction/Magnitude triple per failed criterion immediately after the verdict
- [ ] Step 6 — if VERIFIED=Yes and an active plan exists, `echo "{plan-name}" > ~/.claude/evaluation-gate.flag` to clear the commit gate
- [ ] When verdict is `VERIFIED: No` and the gap exceeds the agent's autonomy, emit the Escalation Brief in the CONTEXT / TRIGGER / OPTIONS / RECOMMENDATION shape

## Rebuttals

Common rationalizations for skipping verify, with rebuttals:

| Excuse | Rebuttal |
|---|---|
| "Tests pass locally — I just ran them." | Then quote the command + exit code in the report. Memory of a green run is not evidence; the artifact is. |
| "The diff is small." | Small diffs miss verification more often than large ones precisely because they feel safe. The Contract's success criteria don't shrink with diff size. |
| "User is in a hurry." | A wrong "done" costs more than a 30-second verify. If the gate is genuinely too slow, raise that as a separate concern — don't skip silently. |
| "I reviewed the change manually." | Manual review is not a recorded artifact. Without command output or a file:line reference, the claim cannot be audited later. |
| "This is a doc-only / formatting change." | If true, the verify gate for it is `git diff --stat` + a render check — still produce the artifact. The rule is "evidence", not "tests". |

## Escalation Brief

When the verdict is `VERIFIED: No` and the gap is not a fix the agent can make alone — ambiguous criteria, missing test fixtures, conflicting Contract bullets, low confidence in the correct next step — emit a structured brief in this exact shape after the verdict block (or in place of it). The labels are part of the contract so a downstream parser/grep can detect a brief.

```text
CONTEXT: <one line — what feature/criterion was being verified>
TRIGGER: <one line — what made the gate fail or stall: ambiguous criterion, missing evidence, conflicting plan-vs-HEAD, low-confidence on the fix>
OPTIONS:
1. <option, agent can do this without help>
2. <option, requires your action>
3. <option, requires your action>
RECOMMENDATION: <option #N>. <one-line reason>

Waiting for instruction. <thing the agent is paused on> is not blocked yet.
```

The brief sits alongside the per-criterion gradient block from `## 5a` — gradient is the per-criterion machine-readable signal; the brief is the human-decision pitch when the gradient alone is not enough.

Input: `/verify` runs against a plan whose Contract bullet 3 has no `verify_cmd` and contradicts the README behavior the change preserves.
Output:
```text
VERIFIED: No
METHOD: features.json + manual reading
EVIDENCE: 2 of 3 criteria gated; criterion 3 has no executable verify_cmd
REMAINING RISK: criterion 3 conflicts with the documented behavior in README.md:42

CONTEXT: Verify the rename of `feature-list-nudged` marker after Task A landed.
TRIGGER: Contract criterion 3 has no verify_cmd and contradicts README.md:42 ("marker file persists across sessions").
OPTIONS:
1. Treat criterion 3 as manual and gate only on 1 and 2 — record that in the gate report.
2. Pause for you to resolve the contradiction with README.md:42 before the gate continues.
3. Edit the Contract to add an executable verify_cmd for criterion 3 (requires your sign-off on the new check).
RECOMMENDATION: Option 2. The contradiction is in the spec, not the code — fixing the code without resolving the spec ships a verified-but-wrong outcome.

Waiting for instruction. The remaining gate steps are not blocked yet — `.claude/gate/features.json` already records the partial result.
```

Input: `/verify` runs and the test suite is green but the agent's confidence in the diff is low (touched a file it has not seen before, no test covers the changed line directly).
Output:
```text
VERIFIED: Yes
METHOD: tests
EVIDENCE: all 138 tests pass (exit 0)
REMAINING RISK: low-confidence — the changed line in plugins/foo/scripts/migrate.sh:88 has no direct test coverage and I am unfamiliar with the file

CONTEXT: Bump the retry-loop ceiling in migrate.sh:88 as requested.
TRIGGER: Low confidence — unfamiliar file, no test covers line 88 directly, the change passed only the broader suite.
OPTIONS:
1. Add a focused unit test against migrate.sh:88 before marking done.
2. Pause for you to spot-check the diff against your mental model of migrate.sh.
3. Ship as verified-with-caveat; the suite is green and the change is small.
RECOMMENDATION: Option 1. A focused test converts the low confidence into evidence — cheaper than reverting later if the broad suite missed something.

Waiting for instruction. The commit is not blocked yet — the gate flag is unset and `git status` is clean.
```
