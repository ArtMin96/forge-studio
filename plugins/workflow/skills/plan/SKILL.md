---
name: plan
description: Phase 2 of the development workflow. Create an implementation plan based on exploration. Lists exact files, changes, risks, and verification method. Use after /explore.
disable-model-invocation: true
argument-hint: <task-description>
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
---

# Plan: Design Before Coding

Phase 2 of the Explore → Plan → Implement → Verify workflow.
From Anthropic: "Planning is most useful for uncertain approach, changes across many files, or unfamiliar code."

## Process

Based on the exploration (or direct knowledge), create a plan:

1. **Problem Statement**: One sentence. What are we solving?
2. **Approach**: How will we solve it? (Brief — 2-3 sentences max)
3. **Changes**: Exact list of files to modify and what changes in each
4. **Order**: Which changes come first? Dependencies between steps?
5. **Risks**: What could go wrong? Where might we need to adjust?
6. **Verification**: How do we prove this works? (tests, build, manual check)

## Output

Write the plan to `.claude/plans/{task-name}.md`:

```markdown
# Plan: {task-name}

## Problem
{one sentence}

## Approach
{2-3 sentences}

## Changes
1. `path/to/file.ext` — {what changes}
2. `path/to/other.ext` — {what changes}

## Risks
- {risk 1}
- {risk 2}

## Verification
{how to verify — specific command or check}
```

After writing the plan:
- Tell the user they can edit it with Ctrl+G
- Ask: "Ready to implement, or want to adjust the plan?"

Skip planning for tasks where you can describe the diff in one sentence.
