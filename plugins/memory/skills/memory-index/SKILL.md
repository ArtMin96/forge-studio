---
name: memory-index
description: Use when the user wants to review, prune, or sanity-check stored memories — lists every topic file in `.claude/memory/`, flags entries older than 90 days, detects duplicates, and verifies a memory's claim against the current repo state when asked.
when_to_use: Reach for this for periodic memory hygiene, before relying on a recalled fact, or when the user says "what do you remember about X". Do NOT use to *retrieve* a specific memory for use in the current turn — that's `/recall`; do NOT use to *write* one — that's `/remember`.
disable-model-invocation: true
model: haiku
---

# /memory-index — Audit Memory

## Actions

### List all memories
Read `.claude/memory/index.md` and present as a table:

| Topic | Last Verified | Age | Status |
|-------|--------------|-----|--------|
| ... | ... | ... | fresh / aging / stale |

Age thresholds: fresh (< 7d), aging (7-30d), stale (> 30d).

### Audit for staleness
For each topic file in `.claude/memory/topics/`:
1. Read the `Last verified:` date
2. Flag entries older than 30 days
3. Check if referenced files/functions still exist
4. Report findings

### Clean up
For stale or invalid entries:
1. Remove the topic file from `.claude/memory/topics/`
2. Remove the corresponding line from `.claude/memory/index.md`
3. Report what was removed and why

### Verify a specific memory
1. Read the topic file
2. Check every factual claim against current state (file existence, function names, config values)
3. Update `Last verified:` date if still accurate
4. Flag or remove if outdated

## Rules

- Never delete without reporting what was removed
- Suggest consolidation when multiple topics overlap
- Keep `.claude/memory/index.md` under 50 entries
- Memory is hints, not ground truth — always verify before acting
