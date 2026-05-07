# memory

Three-tier persistent memory: a pointer index, on-demand topic files, and searchable transcripts. Version-aware writes snapshot prior content so the lineage ledger keeps a full history.

## What it does

A flat memory file balloons fast. This plugin tiers it. Tier 1 is an index of pointers (always loaded, ~50 lines). Tier 2 is the topic files behind each pointer (loaded on demand). Tier 3 is the transcript archive (searchable but never auto-loaded). Every write is versioned and snapshotted.

## When to use

- Architectural decisions or recurring user preferences need to survive session boundaries
- "Always do it this way" rules that aren't yet in CLAUDE.md
- Non-obvious constraints from past incidents that should inform future work

Skip for ephemeral state — task progress goes in `long-session`, code goes in the codebase.

## How it works

```text
 /remember <topic> ──► writes .claude/memory/topics/<topic>.md
                       adds a one-line pointer to .claude/memory/index.md
                       snapshots prior topic content to lineage ledger
 /recall <query>   ──► reads index.md, picks matching topic, brings facts into context
 /lineage-audit    ──► walks the ledger, reports protocol violations
```

Tier 1 (`index.md`) is the only file loaded automatically. Tier 2 files load when `/recall` matches them. Tier 3 transcripts only load when explicitly searched.

## Skills

| Skill | Purpose |
|---|---|
| `/remember` | Write a tier-2 topic + tier-1 pointer + ledger snapshot |
| `/recall` | Tier-aware retrieval — pointer → topic → optional transcript |
| `/memory-index` | Review, prune, sanity-check stored memories. Flag entries older than 90 days; verify a memory's claim against the current repo |
| `/lineage-audit` | Audit the ledger for invariant violations (operator order, registry slugs, snapshot presence, append-only) |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `PreCompact` (`manual\|auto`) | precompact-snapshot | Snapshot the last 10 user corrections (no/stop/don't/actually/wait/...) to `~/.claude/projects/<slug>/memory/.precompact-feedback.txt` so behavioral feedback survives compaction. `long-session/surface-progress.sh` tails the file on next `SessionStart` |

Project root for the `<slug>` resolves via `CLAUDE_PROJECT_DIR` → `git rev-parse --git-common-dir` parent → `pwd`, so worktrees write to the same memory dir as the main checkout.

## Disable

`/plugin disable memory@forge-studio`. The memory files stay on disk under `.claude/memory/` — re-enabling restores access.
