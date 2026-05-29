---
name: trace-review
description: Analyze recent execution traces to find recurring patterns, failures, and optimization opportunities.
when_to_use: Reach for this after `/trace-compile`, when investigating a session with a high error rate, or when looking for recurring patterns that haven't yet been turned into SEPL proposals. Do NOT use for compiling raw traces — use `/trace-compile` instead. Do NOT use for proposing fixes — use `/trace-evolve` instead.
disable-model-invocation: true
paths:
  - ".claude/traces/*.jsonl"
allowed-tools:
  - Read
  - Bash
  - Glob
logical: report enumerates recurring failures, file hotspots, and session-health trend with recommendations
---

# Trace Review

Analyze execution traces stored in `~/.claude/traces/` to identify patterns across sessions.

## Process

1. **Read recent trace files**: `stat -c '%Y %n' ~/.claude/traces/*.jsonl 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-` to find the 5 most recent sessions
2. **Parse JSONL entries**: Each line is a JSON object with `type`, `timestamp`, and type-specific fields
3. **Analyze patterns**:
   - **Repeated failures**: Commands that fail (exit_code != 0) repeatedly across sessions
   - **File hotspots**: Files modified most frequently — candidates for refactoring or testing
   - **Wasted turns**: Commands that produce no useful output or always error
   - **Session health**: Error rate per session, trend over time
4. **Report findings**: Actionable insights, not raw data

## Execution Checklist

- [ ] List the 5 most-recent JSONL trace files under `~/.claude/traces/`
- [ ] Parse each entry's `type`, `timestamp`, and type-specific fields
- [ ] Aggregate recurring failures (exit_code != 0), file hotspots, wasted turns, per-session error rate
- [ ] Emit the four-section markdown report (Recurring Failures, File Hotspots, Session Health Trend, Recommendations)

## Entry Types

- `bash`: command, exit_code, output_preview, cwd
- `file`: tool (Write/Edit), file_path, cwd
- `session_end`: bash_commands, file_operations, errors, unique_files_modified

## Output Format

```markdown
## Trace Review (last N sessions)

### Recurring Failures
- [pattern]: happened N times across M sessions

### File Hotspots
- [file]: modified N times (consider: tests? refactor? stability?)

### Session Health Trend
- Avg error rate: N%
- Avg commands/session: N
- Trend: improving/stable/degrading

### Recommendations
- [actionable suggestion based on patterns]
```

## Examples

Input: 5 most-recent JSONL files in `~/.claude/traces/` containing 23 bash entries with `exit_code != 0` for `npm test` and 11 file entries touching `src/auth/middleware.ts`.

Output:
```markdown
## Trace Review (last 5 sessions)

### Recurring Failures
- `npm test` exit 1: 23 occurrences across 4 sessions — same assertion failure in auth.test.ts

### File Hotspots
- src/auth/middleware.ts: modified 11 times (consider: missing test for session-timeout branch)

### Session Health Trend
- Avg error rate: 18%
- Avg commands/session: 47
- Trend: degrading

### Recommendations
- Add an assertion-level test for the session-timeout branch before further edits to middleware.ts
```

Input: traces show low error rate but `rg` and `grep` commands repeated 6+ times per session against the same paths with empty output.

Output:
```markdown
## Trace Review (last 5 sessions)

### Recurring Failures
- (none above threshold)

### File Hotspots
- (no file modified ≥3 times)

### Session Health Trend
- Avg error rate: 3%
- Avg commands/session: 62
- Trend: stable

### Recommendations
- Wasted-turn pattern: 6+ near-duplicate rg/grep queries per session. Vary search terms or consult `codegraph_search` first.
```
