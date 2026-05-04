---
name: session-resume
description: Resume work from the long-session artifacts (claude-progress.txt + spec.md + features.json). Reads the append-only log, the living spec, and the testable-requirements list, then briefs the current session.
when_to_use: Reach for this at the start of a new session to pick up where the previous one left off, or after a `/compact` when context state has been lost. Do NOT use to *write* the resume artifacts — that's `/progress-log` (writes), `/feature-list` (writes); session-resume is the read-side briefer.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
logical: briefing surfaces last 3 progress entries, spec tail, and features.json status
---

# /session-resume — Brief the Current Session

Reads the long-session artifacts; outputs a briefing so work continues without re-exploration.

## Process

1. **Check init.sh.** If `init.sh` exists at repo root and is executable, remind the user:
   `init.sh is present. If the dev env isn't up, run: bash init.sh`

2. **Read claude-progress.txt tail.** Entries are blank-line-separated blocks (shape defined by `/progress-log`). Show the last 3 entries verbatim.

3. **Read .claude/spec.md.** If present, show the tail (last 20 lines or the last delta block, whichever is smaller).

4. **Read .claude/features.json.** Summarize: `N pending, M in_progress, K done`. List any `in_progress` items by id + description.

5. **Git state.**
   ```bash
   git status --short
   git log --oneline -5
   ```

6. **Detect test command.**
   - `package.json` scripts.test
   - `composer.json` scripts.test
   - `Makefile` test target
   - `pytest` / `cargo test` / `go test`
   Note it; do NOT auto-run.

7. **Emit briefing** in this exact shape:

   ```
   ## Session Briefing

   **Last progress entry:** <date> — <topic>
   <last entry tail>

   **Features:** N pending · M in_progress · K done
   In progress: F3 <desc>, F5 <desc>

   **Spec tail:**
   <last spec delta>

   **Git:** <N commits today>, <M uncommitted files>
   **Tests:** <command detected, or "no command detected">

   Ready. What's next?
   ```

## Integration

- Reads produced by `/progress-log`, `/living-spec`, `/feature-list`, `/init-sh`.
- Complements `surface-progress.sh` (SessionStart) — that hook previews; this skill produces the full briefing on demand.
- No ledger writes (this skill is read-only).

## Failure Modes

- None of the artifacts exist → report `No long-session artifacts found. Start with Plan mode + /feature-list + /living-spec.`
- `.claude/features.json` malformed → report parse error; skip that section but continue.
