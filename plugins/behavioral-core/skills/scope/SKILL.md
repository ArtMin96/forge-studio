---
name: scope
description: Create a task scope with boundaries, acceptance criteria, and file limits to prevent scope creep.
when_to_use: Before any non-trivial task (3+ steps, multiple files, or unclear requirements).
disable-model-invocation: true
argument-hint: <task-description>
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
---

# Create Task Scope

Define a focused scope for: **$ARGUMENTS**

## Steps

1. Parse the task description from `$ARGUMENTS`.
2. Identify which files will need to change. Use `Glob` and `Grep` to find relevant files — keep the list tight.
3. Create the directory `.claude/scopes/` if it does not exist.
4. Generate a scope document at `.claude/scopes/{task-name}.md` where `{task-name}` is a slugified version of the task (lowercase, hyphens, no spaces).

## Scope Document Format

The document must be under 15 lines. Use this exact structure:

```
# {Task Name}

## Task
{One sentence: what exactly needs to change.}

## Files
{Explicit list of files that will be touched — one per line, prefixed with `-`.}

## Boundaries
{What does NOT change — explicit exclusions, one per line, prefixed with `-`.}

## Done When
{Testable acceptance criteria — one per line, prefixed with `-`.}

## Max Files
{Number — default 5. Adjust if the user specifies a different limit.}
```

## After Creating

Present the scope document to the user and ask: **"Does this scope look right? Confirm and I'll start."**

Do NOT proceed with implementation until the user confirms.
