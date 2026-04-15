---
name: trace-review
description: Analyze recent execution traces to find recurring patterns, failures, and optimization opportunities
disable-model-invocation: true
---

# Trace Review

Analyze execution traces stored in `~/.claude/traces/` to identify patterns across sessions.

## Process

1. **Read recent trace files**: `ls -t ~/.claude/traces/*.jsonl | head -5` to find the 5 most recent sessions
2. **Parse JSONL entries**: Each line is a JSON object with `type`, `timestamp`, and type-specific fields
3. **Analyze patterns**:
   - **Repeated failures**: Commands that fail (exit_code != 0) repeatedly across sessions
   - **File hotspots**: Files modified most frequently — candidates for refactoring or testing
   - **Wasted turns**: Commands that produce no useful output or always error
   - **Session health**: Error rate per session, trend over time
4. **Report findings**: Actionable insights, not raw data

## Entry Types

- `bash`: command, exit_code, output_preview, cwd
- `file`: tool (Write/Edit), file_path, cwd
- `session_end`: bash_commands, file_operations, errors, unique_files_modified

## Output Format

```
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
