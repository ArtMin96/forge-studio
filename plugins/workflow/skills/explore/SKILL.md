---
name: explore
description: Phase 1 of the development workflow. Explore the codebase using subagents WITHOUT making changes. Produces an exploration report. Use before planning complex changes.
disable-model-invocation: true
argument-hint: <what-to-explore>
context: fork
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Explore: Understand Before Changing

Phase 1 of the Explore → Plan → Implement → Verify workflow.
Runs in a fork context so exploration doesn't pollute the main session.

## Process

Given the task in $ARGUMENTS:

1. **Find relevant code**: Use Glob/Grep to locate files related to the task
2. **Read key files**: Understand the current implementation
3. **Trace dependencies**: What calls what? What depends on this?
4. **Identify patterns**: How does the codebase handle similar things?
5. **Check tests**: Do tests exist for this area? What do they cover?

## Output: Exploration Report

```
EXPLORATION REPORT
==================
Task: [what was explored]

Relevant Files:
- path/to/file.ext — [what it does, why it matters]
- path/to/other.ext — [what it does, why it matters]

Current Behavior:
[How the code currently works, in 2-3 sentences]

Existing Patterns:
[How the codebase handles similar things — naming, structure, approach]

Dependencies:
[What other code depends on this, or what this depends on]

Test Coverage:
[Do tests exist? What do they cover? What's missing?]

Gotchas:
[Anything surprising, non-obvious, or risky discovered during exploration]
```

Keep the report under 300 tokens. The main session needs the signal, not the noise.
Do NOT make any changes. Read only.
