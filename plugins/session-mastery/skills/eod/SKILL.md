---
name: eod
description: End-of-day summary ritual. Review today's work, capture progress in a daily log, and trigger handoff if work is in progress.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# End-of-Day Summary Ritual

Run these steps in order to capture today's progress.

## Step 1: Today's commits

Run:

```bash
git log --oneline --since="midnight"
```

Capture the full list. If there are no commits, note "No commits today."

## Step 2: Files changed today

Run:

```bash
git diff --name-only HEAD~10
```

This is an approximation. If the command fails (e.g., fewer than 10 commits), fall back to:

```bash
git diff --name-only HEAD~3
```

Or use whatever depth is available.

## Step 3: Check for uncommitted work

Run:

```bash
git status --short
```

Note any staged or unstaged changes.

## Step 4: Create the daily log

Ensure the directory exists:

```bash
mkdir -p .claude/daily-logs
```

Get today's date:

```bash
date +%Y-%m-%d
```

Create (or overwrite) the file `.claude/daily-logs/{YYYY-MM-DD}.md` using the Write tool with this structure:

```markdown
# Daily Log — {YYYY-MM-DD}

## Commits
{list each commit from Step 1, one per line}

## Files Touched
{list each file from Step 2, one per line}

## Key Decisions
{ask the user what key decisions were made today — list any that are apparent from commit messages or file changes}

## Unfinished Items
{list uncommitted changes from Step 3, plus anything that looks incomplete}
```

For the "Key Decisions" section: infer what you can from commit messages and changed files, then ask the user if there's anything else to add.

For the "Unfinished Items" section: list uncommitted changes and ask the user if there are other open threads.

## Step 5: Handoff suggestion

If Step 3 found uncommitted changes or the user mentioned work in progress, end with:

> You have uncommitted work. Consider running `/handoff` to capture context for your next session.

If everything is clean, end with:

> Clean state. Nice work today.
