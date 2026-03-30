---
name: implement
description: Phase 3 of the development workflow. Execute a plan step-by-step with verification. Checks for scope creep after each step. Use after /plan.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Implement: Execute the Plan

Phase 3 of the Explore → Plan → Implement → Verify workflow.

## Process

1. **Read the plan**: Check `.claude/plans/` for the most recent plan
2. **Validate before executing**: Before making changes:
   a. Confirm all target files from the plan exist (`ls` or `Glob`)
   b. If the plan involves destructive/batch changes, dry-run first where possible
   c. If a target file doesn't exist or has changed unexpectedly, stop and update the plan
3. **Execute step by step**: For each change listed in the plan:
   a. Make the change
   b. Quick sanity check: does the file still make sense?
   c. Scope check: did you change ONLY what the plan specified?
4. **Verify**: Run the verification method specified in the plan
5. **Report**: Show evidence of success

## Rules During Implementation

- Follow the plan. If the plan is wrong, update it first — don't silently deviate.
- One change at a time. Don't batch unrelated changes into a single edit.
- If you discover something unexpected: stop, report it, adjust the plan.
- After each step, mentally check: "Am I still within scope?"
- Don't add anything the plan doesn't specify. No bonus refactoring.

## After Implementation

Run the verification step from the plan. Show output.

```
IMPLEMENTATION COMPLETE
=======================
Plan: {plan name}
Steps completed: {X}/{Y}
Verification: {PASS/FAIL}
Evidence: {one-line summary of proof}
```

If verification fails: diagnose, fix, re-verify. Don't mark done until it passes.
If the plan was wrong: note what was different and why.
