---
name: trace-stats
description: Use when the user wants a fast numeric summary of recent sessions — command counts, error rates, files modified, average tokens per turn — without the cost of full pattern analysis. Runs against `.claude/traces/*.jsonl` and returns a one-screen table.
when_to_use: Reach for this for a 30-second sanity check, before deciding whether a deeper `/trace-review` is warranted, or when reporting overall harness usage. Do NOT use for failure clustering or proposal generation — that's `/trace-review` and `/trace-evolve`.
disable-model-invocation: true
model: haiku
paths:
  - ".claude/traces/*.jsonl"
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
