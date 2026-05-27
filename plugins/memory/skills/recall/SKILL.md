---
name: recall
description: Use when the user references prior work, asks "what did we decide about X", or starts a topic that may have been explored before — loads `.claude/memory/index.md`, picks the matching tier-2 topic file, and brings the relevant facts into the current turn. Performs a tier-aware retrieval (pointer → topic → optional transcript) instead of dumping everything.
when_to_use: Reach for this at the start of a session that continues prior work, when a user phrase matches a known memory topic, or when grounding a decision against past context. Do NOT use for writing or updating memories — use `/remember` instead. Do NOT use for auditing memory hygiene — use `/memory-index` instead.
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
logical: matched topic content surfaced ranked by relevance × staleness × confidence, with conflicts resolved toward the higher-trust entry; source path and staleness label included
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

## Retrieval Ranking and Staleness Protocol

Every topic file has a `Last verified:` date and an optional `Confidence:` field (`high | medium | low`; omitted ⇒ `medium`). When multiple topics match a query, order them by:

```
composite_trust = relevance × staleness_weight × confidence_weight
```

Where the weights derive from what the topic file already carries:

| Age of `Last verified:` | staleness_weight |
|-------------------------|-----------------|
| < 7 days                | 1.0             |
| 7–30 days               | 0.7             |
| > 30 days               | 0.4             |

| `Confidence:` value     | confidence_weight |
|-------------------------|------------------|
| `high`                  | 1.0              |
| `medium` (or omitted)   | 0.7              |
| `low`                   | 0.4              |

This is a ranking convention for Claude to apply by reading the files, not a computed score. (§4.2, Table 1 — arXiv:2605.26112)

**Conflict resolution**: when two topic files address the same need, prefer the one with the higher composite_trust score and surface the other as superseded-but-recorded (e.g. "Older entry also found: <slug> — lower confidence/staleness weight, shown for completeness").

**Display labels** (human-facing presentation, unchanged):
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
