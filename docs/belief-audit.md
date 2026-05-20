# Belief-State Audit

## What this is

Every time Claude edits a file, Forge Studio records a sha256 fingerprint of that file — before and after the edit — in `.claude/state/belief.jsonl`. The `/belief-audit` skill compares those stored fingerprints against the current state of the files on disk and reports any divergence.

The underlying concept comes from arXiv:2605.18747 §4.3 (SyncMind), which formalizes belief-state divergence as `|Bk − Sk|`: the gap between an agent's internal belief `Bk` about what a file contains and the actual system state `Sk`. The paper identifies this gap as a primary root cause of brittleness in long-running agent sessions — and it is cheapest to close at the moment of detection, before any further edits are made on stale assumptions.

## Why you care

Picture this: Opus session, 200+ turns. At turn 180, Claude edits `plugins/context-engine/hooks/track-edits.sh`. At turn 195, context compacts — the full edit is summarized down to a one-line mention. At turn 210, Claude references the "current state" of that file to decide what to change next. But the compaction summary was approximate; another hook that ran in the background also touched the file. Claude's internal model says line 22 reads `COUNT=0` — disk says that line was already changed by the background hook. The next edit writes from the stale assumption and introduces a silent bug.

Belief-audit catches this before it happens: invoke it after compaction, check the fingerprints, re-read any flagged file before editing.

## How it works

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Edit (PreToolUse)                                               │
│      └─► belief-snapshot.sh                                     │
│              └─► sha256(file)  ──► belief.jsonl  {op: "pre"}    │
│                                                                  │
│  Edit succeeds                                                   │
│      └─► Claude's internal belief = post-edit state             │
│                                                                  │
│  PostToolUse                                                     │
│      └─► belief-verify.sh                                       │
│              └─► sha256(file)  ──► belief.jsonl  {op: "post"}   │
│                                                                  │
│  /belief-audit (or PostCompact auto-run)                         │
│      └─► re-sha256 each tracked path on disk                    │
│              └─► diff vs latest stored signature                 │
│                      └─► drift report (exit 1 if any changed)   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

The `pre` snapshot captures what the file looked like when Claude decided to edit it. The `post` snapshot is the new baseline. `/belief-audit` always compares against the latest `post` snapshot (falling back to `pre` if no post exists yet for a path).

Both snapshot hooks are `async: true` — they write to disk in the background and do not add latency to the edit turn.

## When to use

**Manually:**
- After returning to a project after a long absence
- After a session compacts (context window was full and summarized)
- After handing off work to or from another agent
- Any time you suspect a file may have changed outside of Claude's awareness

**Automatically:**
- On every `PostCompact` event — `post-compact-belief-audit.sh` runs `audit.sh 5` and appends results to `.claude/state/belief-audit-post-compact.log`

To invoke manually:

```
/belief-audit        # check 5 most-recently-edited files (default)
/belief-audit 10     # check 10 files
```

## Cost

One `sha256sum` call per file per Edit. On a typical source file (a few hundred lines), this takes microseconds. The JSONL append is a single buffered write. The total overhead per edit is negligible — well under 1ms on any modern filesystem.

The audit scan (`/belief-audit`) reads the log file once and runs one `sha256sum` per tracked path. For the default of 5 files, the entire audit completes in under 10ms.

## Compared to /verify

`/verify` checks **runtime behavior** — it runs your tests, checks exit codes, confirms the program works as intended. Belief-audit checks **state representation** — it confirms Claude's model of what is in a file matches what is actually on disk.

They are complementary:

| Question | Tool |
|----------|------|
| Does this code do what I think it does? | `/verify` |
| Is the file I'm about to edit what I think it is? | `/belief-audit` |

Run belief-audit first (confirm you're editing the right version), then run `/verify` after (confirm the change has the right effect).

## Known limitations

- **Only tracked files**: only files Claude actually edited during the current or recent sessions are tracked. Files that changed outside of any Claude edit — e.g., a `git pull` that updated a dependency — are not in the log and will not be audited.
- **Symlinks not resolved**: the snapshot records the sha256 of the symlink target at the time of the edit. If the target file is replaced via a different symlink or path, the path recorded in belief.jsonl may no longer resolve correctly. The audit reports the original path as-is; if the path now points to a different inode, the sha256 will differ and drift will be reported (correct behavior, but the cause may be surprising).
- **Concurrent writers**: if two processes append to `belief.jsonl` simultaneously, lines may interleave. The audit deduplicates by path and takes the latest entry by timestamp, preferring `op: post` on ties. In practice this is rare (one Claude session at a time per repo), but worth knowing for worktree-team setups.
- **sha256sum must be available**: the scripts use `sha256sum` (GNU coreutils). On systems where it is absent, the snapshot exits 0 silently and the audit warns to stderr. Install coreutils to get coverage.
