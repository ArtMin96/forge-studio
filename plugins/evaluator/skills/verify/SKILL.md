---
name: verify
description: Use whenever a task is about to be marked done — runs the listed verification commands (tests, lint, type-check, behavioral spot-check), captures the actual output, and compares against `.claude/features.json` or the `/contract` criteria. Refuses to mark done unless every gate produced evidence; closes the trust-then-verify gap that produces "I think it works" claims.
when_to_use: Reach for this before committing, merging, or telling the user "fixed". Do NOT use for deep adversarial review — that's `/challenge` (fork-based critique); verify is the cheap, in-line evidence gate that runs first.
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

## Rebuttals

Common rationalizations for skipping verify, with rebuttals:

| Excuse | Rebuttal |
|---|---|
| "Tests pass locally — I just ran them." | Then quote the command + exit code in the report. Memory of a green run is not evidence; the artifact is. |
| "The diff is small." | Small diffs miss verification more often than large ones precisely because they feel safe. The Contract's success criteria don't shrink with diff size. |
| "User is in a hurry." | A wrong "done" costs more than a 30-second verify. If the gate is genuinely too slow, raise that as a separate concern — don't skip silently. |
| "I reviewed the change manually." | Manual review is not a recorded artifact. Without command output or a file:line reference, the claim cannot be audited later. |
| "This is a doc-only / formatting change." | If true, the verify gate for it is `git diff --stat` + a render check — still produce the artifact. The rule is "evidence", not "tests". |
