---
name: postmortem
description: Structured bug autopsy after fixing a bug. Analyzes root cause, classifies the bug, and recommends prevention.
when_to_use: After any non-trivial bug fix.
disable-model-invocation: true
effort: xhigh
argument-hint: [description of the bug]
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Postmortem: Bug Autopsy

Run this after fixing a bug. Don't just fix and move on — every bug is a potential guardrail.

## Process

### 1. What Happened
Describe the bug behavior in one sentence. What did the user see? What was expected?

### 2. Root Cause
Explain WHY it happened — not just what you changed to fix it. Trace the chain:
- What was the immediate cause?
- What allowed that cause to exist?
- Was there a deeper design issue?

### 3. Category
Classify the bug. Pick one:
- **State management** — stale state, race condition, missing sync
- **Type mismatch** — wrong type, missing null check at system boundary
- **Boundary error** — off-by-one, empty input, overflow
- **Logic error** — wrong conditional, missing branch, inverted check
- **Integration** — API contract changed, schema mismatch, version drift
- **Configuration** — wrong env var, missing config, path issue
- **Concurrency** — deadlock, race condition, ordering assumption

### 4. Could It Have Been Caught Earlier?
- Was there a missing test? Write it now.
- Was there a missing type? Add it.
- Was there a missing validation at a system boundary? Add it.
- Would a linter rule have caught it? Note which one.

### 5. Prevention
One concrete recommendation. Not vague ("be more careful") — specific:
- "Add integration test for X endpoint with empty payload"
- "Add runtime type guard at API boundary for field Y"
- "Enable ESLint rule no-floating-promises"

## Output Format

```
POSTMORTEM
==========
Bug:         [One-sentence description]
Root Cause:  [Why it happened]
Category:    [From list above]
Missed By:   [What should have caught it]
Prevention:  [Specific action]
```

Keep it short. This is a quick post-fix analysis, not a 500-word essay.
