---
name: morning
description: Daily morning planning ritual. Use at the start of each workday to review yesterday's progress, check handoffs, and create a prioritized plan.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Morning Planning Ritual

Run these steps in order to build today's plan.

## Step 1: Yesterday's commits

Run:

```bash
git log --oneline --since="yesterday" --author="$(git config user.name)"
```

If there are no commits, note that explicitly. Do not skip this step.

## Step 2: Open handoffs

Check if `.claude/handoffs/` exists. If it does, read the latest 3 files (by modification time):

```bash
ls -t .claude/handoffs/ | head -3
```

Read each file found and extract the key context: what was in progress, what decisions were pending, and what needs attention.

If the directory does not exist or is empty, note "No open handoffs."

## Step 3: Uncommitted work

Run:

```bash
git status --short
```

If there are uncommitted changes, list them. Flag anything that looks like work-in-progress that was left overnight.

## Step 4: CI status

Check if `gh` is available:

```bash
command -v gh && gh run list --limit 3
```

If `gh` is not available or the command fails, skip this step silently.

## Step 5: Produce the daily plan

Based on the information gathered above, produce a prioritized plan in this format:

```
## Today's Plan — {YYYY-MM-DD}

### Priority 1 (must ship)
- [ ] ...

### Priority 2 (should do)
- [ ] ...

### Priority 3 (if time allows)
- [ ] ...

### Carry-over / Blockers
- ...
```

Populate priorities using:
- Handoff items and uncommitted work go to Priority 1.
- Follow-ups from yesterday's commits go to Priority 2.
- CI failures go to Priority 1 if broken, Priority 2 if flaky.

## Step 6: Close with focus

End your output with:

> **What's the ONE thing that makes today a win?**

Prompt the user to answer. Do not answer for them.
