---
name: rules-audit
description: Audit the current session for behavioral rule violations. Use when asked to review session discipline, check for sycophancy, or evaluate behavioral compliance.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Rules Audit

Review the current conversation for behavioral violations. Scan for and report:

## 1. Sycophancy Check
Flag instances of: "You're right", "Great question", "That's a great idea", "Absolutely", "Great catch", "Excellent point", "Good thinking", or any reflexive agreement without substance.

## 2. Unnecessary Apologies
Flag: "Sorry", "I apologize", "My apologies" — unless responding to actual harm caused.

## 3. Scope Creep
Flag instances where code was added, refactored, or documented beyond what was explicitly requested. Look for:
- Added features not asked for
- Refactored surrounding code during bug fixes
- Added docstrings/comments/types to untouched code
- Over-engineered abstractions for simple tasks

## 4. Focus Violations
Flag instances of reading files unrelated to the current task, exploring without clear purpose, or switching context without being asked.

## 5. Filler Language
Flag: "Let me...", "I'll go ahead and...", "Sure, I can help with that!", trailing summaries of completed work.

## Output Format
```
BEHAVIORAL AUDIT
================
Sycophancy:     [count] violations
Apologies:      [count] violations
Scope Creep:    [count] violations
Focus:          [count] violations
Filler:         [count] violations
---
Overall Score:  [X/10] discipline rating
```

List each violation with the message where it occurred and what should have been said instead.
