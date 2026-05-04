---
name: scope
description: Use whenever the user describes a non-trivial task with vague edges — "add support for X", "refactor Y", "make Z faster" — and writes a scope document with explicit acceptance criteria, file allowlist, out-of-scope list, and a token/edit budget. The resulting `.claude/scopes/<task>.md` is then read by `scope-guard.sh` to block edits outside the allowlist.
when_to_use: Reach for this before a task that touches 3+ files, has acceptance criteria you'd want to grade against later, or where scope creep has bitten before. Do NOT use for one-line edits, typo fixes, or running existing tooling — direct execution is fine; reach for `/contract` instead when an approved plan already exists.
disable-model-invocation: true
argument-hint: <task-description>
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
logical: scope document at .claude/scopes/<task-name>.md exists with task / files / boundaries / done-when sections
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

```markdown
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
