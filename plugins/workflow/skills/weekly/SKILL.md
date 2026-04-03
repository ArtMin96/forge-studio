---
name: weekly
description: Weekly retrospective. Review the past week's daily logs to identify patterns, wins, blockers, and accumulated tech debt.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Weekly Retrospective

Run these steps to produce a weekly summary from the past 7 days.

## Step 1: Gather daily logs

Check if `.claude/daily-logs/` exists and list files from the past 7 days:

```bash
find .claude/daily-logs/ -name "*.md" -mtime -7 -type f | sort
```

Read each file found. If no daily logs exist, note that and proceed with git history only.

## Step 2: Week's git history

Run:

```bash
git log --oneline --since="7 days ago"
```

This gives the full picture even if daily logs are incomplete.

## Step 3: Analyze patterns

From the daily logs and git history, identify:

**Patterns** — What themes kept coming up? Were you repeatedly touching the same files or areas? Were there recurring types of work (bugfixes, features, refactors, reviews)?

**Wins** — What shipped? What was resolved? What PRs were merged? Any milestones hit?

**Blockers** — What slowed you down? Waiting on reviews? Flaky tests? Unclear requirements? External dependencies?

**Tech Debt** — What was explicitly deferred? What shortcuts were taken? What "TODO" or "FIXME" items were added?

For tech debt, also run:

```bash
git diff --unified=0 HEAD~50 | grep "^\+" | grep -iE "TODO|FIXME|HACK|WORKAROUND" || true
```

Adjust the depth if needed.

## Step 4: Produce the weekly summary

Ensure the directory exists:

```bash
mkdir -p .claude/weekly-logs
```

Determine the current ISO week:

```bash
date +%Y-W%V
```

Create the file `.claude/weekly-logs/{YYYY-WNN}.md` using the Write tool with this structure:

```markdown
# Weekly Retrospective — {YYYY-WNN}

## Patterns
- ...

## Wins
- ...

## Blockers
- ...

## Tech Debt Accumulated
- ...

## Focus for Next Week
- ...
```

For the "Focus for Next Week" section: suggest priorities based on the blockers and tech debt identified. Ask the user to confirm or adjust.

## Step 5: Close

End with a summary line:

> **Week in one sentence:** {a single sentence capturing the week's theme}

Ask the user if the summary is accurate or if they want to add anything.
