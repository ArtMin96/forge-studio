---
name: status
description: On-demand snapshot of where the session stands — active plan, last progress-log entry, recent traces, context pressure. Composes existing plugins; no new persistence.
when_to_use: Anytime you want a quick situational report on session state without creating new artifacts.
disable-model-invocation: true
model: haiku
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# /status — Where Are We?

Produces a compact situation report in under ~200 tokens. Read-only. Pulls from artifacts already written by other plugins — does not create new state.

## Sections (in order)

### 1. Active plan

```bash
ls -t .claude/plans/*.md 2>/dev/null | head -1
```

If found: basename, age (days), count of `- [ ]` unchecked items, count of `- [x]` checked items.
If none: `No active plan.`

### 2. Last progress entry

```bash
ls -t claude-progress.txt 2>/dev/null | head -1
```

If found: file age + tail 1 entry. Suggest `/session-resume` if the user hasn't loaded it yet (check whether the session started today vs days ago).
If none: `No progress recorded.`

### 3. Recent execution traces

```bash
ls -t ~/.claude/traces/*.jsonl 2>/dev/null | head -1
```

If the traces plugin is active: last 5 events from the newest trace file, one per line, formatted as `{event} {summary}`. Use `tail -5` on the JSONL file and render each line's `event` field.
If no trace file: skip this section silently.

### 4. Context pressure

If `$CLAUDE_CONTEXT_WINDOW_USED_PCT` is set, report it with the stage label from `docs/architecture.md` §Progressive Context Management (Notice / Moderate / Elevated / High / Critical).
If unset, report the turn counter from `/tmp/claude-workflow-turn-<session>` if present, else `unknown`.

### 5. Router stats (if traces exist)

```bash
ls -t /tmp/claude-router-*/classifications.jsonl 2>/dev/null | head -1
```

If found: count of classifications by route (single-agent, pipeline, fan-out, tdd-loop, none). Gives a quick sense of what the session has actually been doing.

## Output Format

Six lines max. Example:

```
Plan:     refactor-billing.md (2d old, 3/7 done)
Progress: claude-progress.txt (2d ago) — /session-resume to load
Traces:   42 events, last: Bash grep "Subscription"
Pressure: 58% (Moderate) — consider /compact
Router:   pipeline:5 single-agent:3 tdd-loop:2
```

Silent on empty sections — no `None` spam.

## Do NOT

- Do not create any files
- Do not invoke other skills as side effects
- Do not summarize trace contents beyond event names; full trace mining belongs to `traces:/trace-compile`
