---
name: trace-stats
description: Quick statistics on recent session traces — command counts, error rates, files modified
disable-model-invocation: true
---

# Trace Stats

Quick overview of recent session activity from `~/.claude/traces/`.

## Process

1. **Find trace files**: `ls -t ~/.claude/traces/*.jsonl 2>/dev/null | head -10`
2. **For each file**, read the `session_end` entry (last line with `"type":"session_end"`)
3. **Aggregate**: total commands, total errors, total files, sessions count
4. **Show today's session** detail if available

## Output Format

```
## Session Traces (last N sessions)

| Date | Commands | Errors | Files Modified | Error Rate |
|------|----------|--------|----------------|------------|
| ... | ... | ... | ... | ...% |

Today: N commands, N errors, N files modified
Trace directory: ~/.claude/traces/ (N files, Nk total)
```

If no trace files exist, say so and suggest installing the traces plugin.
