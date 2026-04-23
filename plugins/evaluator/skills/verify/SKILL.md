---
name: verify
description: Evidence-based completion check. Prevents the trust-then-verify gap.
when_to_use: Before committing, merging, or claiming any task is done.
disable-model-invocation: true
effort: xhigh
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
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
```
VERIFIED: [Yes/No]
METHOD: [tests/build/manual/type-check]
EVIDENCE: [One line summary of proof]
REMAINING RISK: [What could still go wrong, or "None identified"]
```

If you CANNOT verify the change:
```
UNVERIFIED: Cannot verify this change.
NEEDED: [What would be needed to verify — test command, expected output, etc.]
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
