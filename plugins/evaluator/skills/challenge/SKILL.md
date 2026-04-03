---
name: challenge
description: Challenge your own work before presenting it. Run before marking any non-trivial task complete. Forces self-critical evaluation of implementation quality.
disable-model-invocation: true
context: fork
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Challenge: Critique Your Own Work

Anthropic's evaluator-optimizer pattern applied to self-review. Run this in a fork context so the critique doesn't pollute the main session.

Review the code you just wrote or the task you just completed. Answer honestly:

## 1. Could This Be Simpler?
- Is there a shorter, cleaner way to achieve the same result?
- Did you add any abstraction that's used only once?
- Are there any "just in case" additions that aren't needed?
- Count the lines changed. Could you achieve it in half?

## 2. What Breaks?
- What happens with null/empty/unexpected input?
- What happens under concurrent access?
- What if this runs twice? Is it idempotent?
- What's the failure mode — silent corruption or loud error?

## 3. What's the Weakest Part?
- Which section of the code are you least confident about?
- Where did you make assumptions without verifying?
- Is there any part where you're hoping it works rather than knowing it works?

## 4. Does This Match the Request?
- Re-read the original task. Did you do ONLY what was asked?
- Did you add anything beyond scope? Remove it.
- Did you change anything you weren't asked to change? Revert it.

## 5. Would a Staff Engineer Approve This?
- Is the code readable without comments?
- Does it follow existing patterns in the codebase?
- Would it survive a code review without changes?

## Output
```
CHALLENGE REPORT
================
Simplification:  [Can/Cannot be simplified. If can: how]
Risk:            [Highest risk area and why]
Weakest Part:    [What and why]
Scope Match:     [Yes/No. If no: what was added beyond scope]
Staff Approval:  [Yes/Likely/No. If no: what needs to change]
```

Be ruthlessly honest. The point is to catch issues BEFORE the user does.
