---
name: rules-audit
description: Use when the user asks to "audit my session", "check for sycophancy", "review behavioral compliance", or otherwise wants a self-discipline pass — scans the current transcript for sycophancy, unnecessary apologies, scope creep, focus drift, and filler language, then reports violations against the rules in `behavioral-core/hooks/rules.d/`.
when_to_use: Reach for this near the end of a long session, after a noticeable stretch of low-discipline turns, or when assessing whether the behavioral-anchor hooks are actually shaping output. Do NOT use to enforce rules in real time — that is the job of the `behavioral-anchor.sh` hook; this skill is the after-the-fact audit.
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
