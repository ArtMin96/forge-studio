---
name: recall
description: Use when the user references prior work, asks "what did we decide about X", or starts a topic that may have been explored before — loads `.claude/memory/index.md`, picks the matching tier-2 topic file, and brings the relevant facts into the current turn. Performs a tier-aware retrieval (pointer → topic → optional transcript) instead of dumping everything.
when_to_use: Reach for this at the start of a session that continues prior work, when a user phrase matches a known memory topic, or when grounding a decision against past context. Do NOT use to write or update memories — that's `/remember`; do NOT use to audit memory hygiene — that's `/memory-index`.
disable-model-invocation: true
logical: matched topic content surfaced with source path and last-verified date staleness label
---

# /recall — Retrieve from Memory

## Retrieval Process

### Step 1: Read the index

Read `.claude/memory/index.md` to see all stored pointers. This is Tier 1 — always small.

### Step 2: Load relevant topics

For each pointer that matches the current need, read the full topic file from `.claude/memory/topics/<slug>.md`. This is Tier 2 — loaded on demand.

### Step 3: Search transcripts (rare)

If Tier 1 and Tier 2 don't have what you need, search session transcripts with grep:
```bash
grep -r "keyword" ~/.claude/projects/*/
```
This is Tier 3 — never load whole files, only grep for specific terms.

## Staleness Protocol

Every topic file has a `Last verified:` date. When recalling:

- **< 7 days old**: Present as current knowledge
- **7-30 days old**: Present as "Previously noted (may be outdated)"
- **> 30 days old**: Present as "Noted on <date> — verify before acting on this"

Before recommending from memory:
- If the memory names a file path: check the file exists
- If the memory names a function or flag: grep for it
- If the user is about to act on your recommendation: verify first

"The memory says X exists" is not the same as "X exists now."

## Output Format

When presenting recalled memories:

```text
Previously noted (<date>):
- <memory content>
- <memory content>

⚠ Verify before acting — memory may be stale.
```
