---
name: recall
description: Search and retrieve stored memories. Load topic files on demand.
when_to_use: When you need context from previous sessions, or before starting work on a topic that may have been explored before.
disable-model-invocation: true
---

# /recall — Retrieve from Memory

## Retrieval Process

### Step 1: Read the index

Read `.claude/memory/index.md` to see all stored pointers. This is Tier 1 — always small.

### Step 2: Load relevant topics

For each pointer that matches the current need, read the full topic file from `.claude/memory/topics/<slug>.md`. This is Tier 2 — loaded on demand.

### Step 3: Search transcripts (rare)

If Tier 1 and Tier 2 don't have what you need, search session transcripts with grep:
```
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

```
Previously noted (<date>):
- <memory content>
- <memory content>

⚠ Verify before acting — memory may be stale.
```
