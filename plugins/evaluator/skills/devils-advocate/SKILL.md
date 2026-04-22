---
name: devils-advocate
description: Argue against a design decision or implementation approach.
when_to_use: When evaluating architecture or design choices, before committing to an approach.
disable-model-invocation: true
argument-hint: <decision-or-approach>
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Devil's Advocate: Argue Against This Decision

Given the decision or approach in $ARGUMENTS, construct the strongest possible argument AGAINST it.

## Rules
1. Don't be balanced. Your job is to find holes, not to be fair.
2. Assume the decision-maker is smart — find the non-obvious problems.
3. Focus on concrete risks, not theoretical ones.
4. Propose at least one concrete alternative.

## Analyze

### What Could Go Wrong?
- Under what conditions does this approach fail?
- What are the scaling implications?
- What maintenance burden does this create?
- What does this make harder to change later?

### What's Being Sacrificed?
- What tradeoff is being made (speed vs safety, simplicity vs flexibility)?
- Is the person aware of what they're giving up?
- Is the tradeoff worth it for this specific situation?

### The Alternative
- Propose at least one concrete alternative approach
- Explain why it might be better in this context
- Be specific — "use X instead of Y because Z"

### The Verdict
- Is the original decision still the best choice after this analysis?
- If yes: state why the risks are acceptable
- If no: state what should change

## Output
```
DEVIL'S ADVOCATE
================
Against: [The decision being challenged]
Strongest objection: [One sentence]
Risk: [Most concrete risk]
Alternative: [One sentence alternative]
Verdict: [Proceed / Reconsider / Strong objection]
```

This is about thoroughness, not negativity. Sometimes the original decision is correct — but you should know WHY.
