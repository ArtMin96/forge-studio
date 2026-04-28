---
name: trace-compile
description: Compile raw JSONL traces from `.claude/traces/` into structured summary and error views.
when_to_use: Reach for this when analyzing a session's execution log, triaging recent failures, or as the prep step before `/trace-review` or `/trace-evolve`. Do NOT use for quick numeric summaries (`/trace-stats`) or for pattern review across sessions (`/trace-review`); compile is the structured-view-builder that the other trace-* skills consume.
disable-model-invocation: true
paths:
  - ".claude/traces/*.jsonl"
---

# Trace Compile

Compiles raw JSONL execution traces into structured views for efficient analysis.

## Why

Raw JSONL traces force the analyzer to parse JSON, filter noise, and navigate linearly. Structured views cut token consumption and improve analysis quality. Three views — summary, errors, and raw — serve different analysis needs.

## Process

### Step 1: Find Traces

```bash
ls -t ~/.claude/traces/*.jsonl | head -5
```

Pick the target session file (or use the most recent).

### Step 2: Build Summary View

Read the JSONL file. For each entry, emit one line:

```
[HH:MM:SS] {type} {target} → {outcome}
```

Examples:
```
[14:02:15] bash  git status → exit:0
[14:02:18] file  Edit src/auth.php → ok
[14:02:20] bash  ./vendor/bin/pest → exit:1 (3 failures)
[14:02:45] file  Edit src/auth.php → ok
[14:02:48] bash  ./vendor/bin/pest → exit:0
```

Write to `~/.claude/traces/{source-name}-summary.md`.

### Step 3: Build Error View

Filter to only entries where:
- `exit_code != "0"`
- `output_preview` contains: `Error`, `Exception`, `FATAL`, `failed`, `denied`, `BLOCKED`

For each error, include the full entry plus the preceding entry (context).

Write to `~/.claude/traces/{source-name}-errors.md`.

### Step 4: Report

```markdown
## Trace Compilation

**Source:** {filename}
**Entries:** {total} ({errors} errors, {error_rate}% error rate)
**Views generated:**
- Summary: {summary_path} ({line_count} lines)
- Errors: {errors_path} ({error_count} entries)
- Full: {source_path} (original)

### Quick Stats
- Commands run: {N}
- Files modified: {N}
- Error rate: {N}%
- Most edited file: {path} ({N} edits)
```

## Usage Pattern

1. Run `/trace-compile` to generate views
2. Read the summary view for session orientation
3. Read the error view for failure patterns
4. Follow specific entries back to the full JSONL for details
5. Use findings with `/trace-evolve` to propose harness improvements
