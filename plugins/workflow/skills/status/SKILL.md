---
name: status
description: On-demand snapshot of where the session stands — active plan, last progress-log entry, recent traces, context pressure. Composes existing plugins; no new persistence.
when_to_use: Reach for this anytime you want a quick situational report on session state without creating new artifacts — handy after returning from a break, before deciding what to work on next, or as a sanity check mid-session. Do NOT use for writing state — use `/progress-log` instead.
disable-model-invocation: true
model: haiku
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
logical: six-line situational report emitted (plan / progress / traces / pressure / router)
---

# /status — Where Are We?

Produces a compact situation report in under ~200 tokens. Read-only. Pulls from artifacts already written by other plugins — does not create new state.

## Sections (in order)

### 1. Active plan

```bash
bash plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh
```

If found: basename, age (days), count of `- [ ]` unchecked items, count of `- [x]` checked items.
If none: `No active plan.`

### 2. Last progress entry

```bash
stat -c '%Y %n' claude-progress.txt 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
```

If found: file age + tail 1 entry. Suggest `/session-resume` if the user hasn't loaded it yet (check whether the session started today vs days ago).
If none: `No progress recorded.`

### 3. Recent execution traces

```bash
stat -c '%Y %n' ~/.claude/traces/*.jsonl 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
```

If the traces plugin is active: last 5 events from the newest trace file, one per line, formatted as `{event} {summary}`. Use `tail -5` on the JSONL file and render each line's `event` field.
If no trace file: skip this section silently.

### 4. Context pressure

If `$CLAUDE_CONTEXT_WINDOW_USED_PCT` is set, report it with the stage label from `docs/architecture.md` §Progressive Context Management (Notice / Moderate / Elevated / High / Critical).
If unset, report the turn counter from `/tmp/claude-workflow-turn-<session>` if present, else `unknown`.

### 5. Router stats (if traces exist)

```bash
stat -c '%Y %n' /tmp/claude-router-*/classifications.jsonl 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
```

If found: count of classifications by route (single-agent, pipeline, fan-out, tdd-loop, none). Gives a quick sense of what the session has actually been doing.

## Output Format

Six lines max. Example:

```text
Plan:     refactor-billing.md (2d old, 3/7 done)
Progress: claude-progress.txt (2d ago) — /session-resume to load
Traces:   42 events, last: Bash grep "Subscription"
Pressure: 58% (Moderate) — consider /compact
Router:   pipeline:5 single-agent:3 tdd-loop:2
```

Silent on empty sections — no `None` spam.

## Examples

Input: active plan `refactor-billing.md` is 2 days old with 3/7 boxes checked; `claude-progress.txt` was last touched 2 days ago; newest trace JSONL has 42 events; `CLAUDE_CONTEXT_WINDOW_USED_PCT=58`; router log shows 5 pipeline, 3 single-agent, 2 tdd-loop classifications.

Output:
```text
Plan:     refactor-billing.md (2d old, 3/7 done)
Progress: claude-progress.txt (2d ago) — /session-resume to load
Traces:   42 events, last: Bash grep "Subscription"
Pressure: 58% (Moderate) — consider /compact
Router:   pipeline:5 single-agent:3 tdd-loop:2
```

Input: no active plan, no progress file, no traces, no env pressure var, no router log.

Output:
```text
No active plan.
No progress recorded.
Pressure: unknown
```

## Do NOT

- Do not create any files
- Do not invoke other skills as side effects
- Do not summarize trace contents beyond event names; full trace mining belongs to `traces:/trace-compile`
