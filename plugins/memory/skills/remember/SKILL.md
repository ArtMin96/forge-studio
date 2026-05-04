---
name: remember
description: Use whenever the user shares (or you discover) something that should survive session boundaries — architectural decisions, recurring user preferences, non-obvious constraints, "always do it this way" rules. Writes a tier-2 topic file in `.claude/memory/topics/`, adds a tier-1 pointer to the index, and snapshots any prior version to the lineage ledger.
when_to_use: Reach for this when the user says "remember that...", when a hard-won insight emerges from debugging, or when a constraint is too subtle to live only in CLAUDE.md. Do NOT use to retrieve a memory — that's `/recall`; do NOT use for ephemeral session notes — those belong in TaskCreate or progress-log.
disable-model-invocation: true
logical: new topic file written under .claude/memory/topics/<slug>.md and pointer added to .claude/memory/index.md
---

# /remember — Store to Memory

## Three-Tier Memory Architecture

| Tier | Location | Loaded | Purpose |
|------|----------|--------|---------|
| 1 | `.claude/memory/index.md` | Always | One-line pointers — tiny, fast |
| 2 | `.claude/memory/topics/*.md` | On demand | Detailed topic files |
| 3 | Session transcripts | Never whole | Raw history, searchable via grep |

## How to Store

### Step 1: Write the topic file

Create `.claude/memory/topics/<slug>.md`:

```markdown
# <Topic Title>

Last verified: YYYY-MM-DD
Version: v1
Previous: (none)

<Content: decisions, patterns, context, rationale>
```

Keep it scannable. Use bullet points. Include **why**, not just **what**.

**If the topic already exists** (update, not create):

1. Read the current file. Record its `Version:` value as `prev` (e.g. `v2`).
2. Snapshot it: copy the current contents to `.claude/lineage/versions/memory/topics/<slug>/v<prev>` (create parent directories as needed).
3. Write the new contents with `Version: v<prev+1>` and `Previous: v<prev>`.
4. Append to `.claude/lineage/ledger.jsonl`:

   ```json
   {"ts":"<UTC>","operator":"commit","resource":"memory/topics/<slug>","version":"v<prev+1>","prev":"v<prev>","trigger":"remember","evidence":".claude/memory/topics/<slug>.md","actor":"memory:/remember"}
   ```

New topics (Version: v1, no prior snapshot) do not write a ledger entry — there is nothing to reverse. Versioning begins at the first update.

### Step 2: Add pointer to index

Append one line to `.claude/memory/index.md`:

```markdown
- [<Topic Title>](topics/<slug>.md) — <one-line hook, under 120 chars>
```

## Rules

- Check if a related topic already exists before creating a new one — update instead
- Include `Last verified:` date so future sessions know staleness
- Don't store things derivable from code or git history
- Don't store ephemeral task details — those belong in tasks, not memory
- Frame stored knowledge as "Previously noted (may be outdated)" when recalled
- Max 50 lines per topic file. If it's longer, split into subtopics.

## What to Store

Good candidates:
- Architectural decisions and their rationale
- User preferences that affect how you work
- Non-obvious project constraints (deadlines, compliance requirements)
- Patterns that took multiple attempts to discover
- External resource locations (dashboards, issue trackers, docs)

Bad candidates:
- Code structure (read the code)
- Git history (use git log)
- Current task progress (use tasks)
- Debugging solutions (the fix is in the code)
