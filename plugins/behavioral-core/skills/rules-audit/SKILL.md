---
name: rules-audit
description: Use when the user asks to "audit my session", "check for sycophancy", "review behavioral compliance", or otherwise wants a self-discipline pass — scans the current transcript for sycophancy, unnecessary apologies, scope creep, focus drift, and filler language, then reports violations against the rules in `behavioral-core/hooks/rules.d/`.
when_to_use: Reach for this near the end of a long session, after a noticeable stretch of low-discipline turns, or when assessing whether the behavioral-anchor hooks are actually shaping output. Do NOT use for real-time rule enforcement — use `/safe-mode` instead; rules-audit only inspects after the fact.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
logical: report includes counts for sycophancy, apologies, scope-creep, focus, and filler with an overall discipline rating
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

## 6. Formatting Defaults
Flag prose that was force-fit into bullet points, numbered lists, or bold headers when plain sentences would do — list scaffolding on a one- or two-item answer, headers on a short reply.

## 7. Question Restatement & Padding
Flag turns that repeat or paraphrase the user's question before answering, or pad after the point is made — answer length disproportionate to a simple question.

## 8. Hedged Non-Answers
Flag "which is better, A or B?" turns answered with a symmetric pros/cons list and no pick — the rule requires committing to one and defending it.

## Output Format
```text
BEHAVIORAL AUDIT
================
Sycophancy:     [count] violations
Apologies:      [count] violations
Scope Creep:    [count] violations
Focus:          [count] violations
Filler:         [count] violations
Formatting:     [count] violations
Restate/Pad:    [count] violations
Hedged Answer:  [count] violations
---
Overall Score:  [X/10] discipline rating
```

List each violation with the message where it occurred and what should have been said instead.
