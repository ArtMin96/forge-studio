---
name: progress-log
description: Append the current session's net outcomes to claude-progress.txt (durable, session-to-session log). Records completions, in-progress work, blockers, and next-step recommendations. Emits a ledger entry for unified audit.
when_to_use: Reach for this at session end, right before auto-compaction is about to fire, or whenever net-new commits land that the next session needs to pick up. Do NOT use for in-conversation tracking — that's `TaskCreate` / `TaskUpdate`; progress-log is the cross-session durable record.
disable-model-invocation: true
argument-hint: [topic]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# /progress-log — Append-Only Session Log

Append this session's outcomes to `claude-progress.txt` at the repo root. Durable, append-only, no regeneration. Paired with `init.sh` + `.claude/spec.md` + `.claude/features.json` per Anthropic's long-running agent pattern.

## Process

1. **Parse topic** from `$ARGUMENTS`. If empty, default to `session`.

2. **Gather net state**:
   ```bash
   git log --oneline --since="6 hours ago" | head -10
   git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only
   git status --short
   ```

3. **Compose entry**. Each entry is a dated block separated by a blank line, following this exact shape:

   ```
   === <UTC ISO8601> — <topic> ===
   Done:
     - <completed item> (<file:line or commit sha>)
   In progress:
     - <what's partial>
   Blockers:
     - <blocker or "None">
   Next:
     - <prioritized next step>
   ```

4. **Append to `claude-progress.txt`** at the repo root (not under `.claude/`). Create file if missing. Never edit existing entries — append-only by design.

5. **Emit ledger entry** to `.claude/lineage/ledger.jsonl` (same SEPL schema for unified audit):
   ```json
   {"ts":"<UTC>","operator":"progress-log","resource":"session/<short-git-hash>","version":"vN","prev":"vN-1","trigger":"/progress-log","evidence":"claude-progress.txt","actor":"long-session:/progress-log"}
   ```
   `vN` counts entries in the log; `prev` is `vN-1` (or `v0` on first write). `mkdir -p .claude/lineage` first.

6. **Report** — one line: `Progress logged (entry #N). /session-resume will surface it in the next session.`

## Constraints

- **Append-only.** Never rewrite previous entries. If a past entry is wrong, add a correction entry — do not edit history.
- **One entry per call.** No batching.
- **Keep it under 500 tokens per entry.** File paths and commit shas beat prose.
- **Never auto-commit the log.** That's the user's choice (see open question in plan).

## Integration

- `pre-compact-handoff.sh` (workflow plugin) nudges this skill before auto-compaction.
- `turn-gate.sh` (workflow plugin) nudges this at session end when commits were made.
- `surface-progress.sh` (SessionStart) reads the tail to prime the next session.
- `/session-resume` replays the log + spec + features into a briefing.
- `/rest-audit` Traceability axis checks log-coverage rate (sessions-with-log / total-sessions).

## Failure Modes

- `claude-progress.txt` is a directory → fail loudly; tell the user.
- Ledger append fails → entry still written to log (log is the source of truth; ledger is secondary metadata). Report the ledger failure.
- No git history available → still produces an entry using `status --short` only.

## Examples

### Example 1: feature landed mid-session

Input:
```
$ARGUMENTS: auth-rewrite
git log --since="6 hours ago": a1b2c3d feat(auth): swap session middleware
git diff --name-only HEAD~1 HEAD: app/Http/Middleware/Session.php, tests/Feature/AuthTest.php
```

Output (appended to `claude-progress.txt`):


```
=== 2026-04-28T14:32:00Z — auth-rewrite ===
Done:
  - Replaced legacy session middleware with token-based variant (a1b2c3d)
  - Added regression test for cookie-less request path (tests/Feature/AuthTest.php:42)
In progress:
  - Token rotation hook (app/Http/Middleware/Session.php:78 — TODO marker)
Blockers:
  - None
Next:
  - Wire rotation hook to scheduled task; backfill rate-limit on /login
```

### Example 2: session ended on a blocker

Input:
```
$ARGUMENTS: (empty → defaults to "session")
git status --short: M docs/architecture.md (no commits this session)
```

Output:
```
=== 2026-04-28T18:01:11Z — session ===
Done:
  - None (investigation only)
In progress:
  - Editing docs/architecture.md to reconcile hook-count drift
Blockers:
  - Need confirmation on whether `35-no-code-narration.txt` counts as a behavioral rule for the README header
Next:
  - Confirm with user, then commit the architecture update + version-bump
```
