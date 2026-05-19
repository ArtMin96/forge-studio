---
name: trace-clarification
description: Use when the user wants to know how often clarification arrives mid-trajectory and how much pre-clarification work gets wasted. Computes the pre-clarification action ratio per session from JSONL traces — the fraction of bash and file events that occurred before the first follow-up user turn.
when_to_use: Reach for this when reviewing whether agent sessions ask early enough, before tuning router prompts, or as input to `/trace-evolve`. It answers "how far into the session does clarification arrive, and how much work was already done?" Do NOT use for numeric summaries — that's `/trace-stats`; trace-clarification is the timing-specific lens.
disable-model-invocation: true
paths:
  - ".claude/traces/*.jsonl"
allowed-tools:
  - Bash
  - Read
logical: per-session waste ratio (pre-clarification-actions / total-actions) emitted as a markdown table
scheduling: when trace files exist under ~/.claude/traces/ and the user questions timing or wasted effort in past sessions
structural:
  - find the target trace file (most recent by default, or path from argument)
  - walk events linearly; count bash/file actions between user_turn boundaries
  - compute waste ratio for each clarification boundary found
  - emit a per-session markdown table
---

# Trace Clarification

Analyzes JSONL trace files to surface how much work happened before the first mid-session user clarification.

## Heuristic

Every `user_turn` entry after the first one in a session is treated as a clarification candidate. This is a V1 simplification — false positives are expected and documented in Known Failure Modes. The metric is useful as a trend signal even when individual rows carry noise.

For each candidate, the helper counts `bash` and `file` entries between the previous boundary and that user_turn. That count, divided by total bash+file events in the session, is the waste ratio.

## Process

1. **Identify the trace file**: argument if provided, else most recent under `~/.claude/traces/`.
2. **Run the helper**: `bash scripts/compute-waste.sh [path]`
3. **Read the table output** and surface it inline.
4. **Flag sessions with high ratios** (>0.5) as candidates for earlier goal clarification.

## Execution Checklist

- [ ] Identify the trace file (argument or most recent under `~/.claude/traces/`)
- [ ] Run `bash scripts/compute-waste.sh [path]`
- [ ] Surface the helper's per-session table inline
- [ ] Flag any session with waste_ratio > 0.5 as a candidate for earlier goal clarification

## Output Format

```markdown
| session | first_clarify_at_action | actions_before_first_clarify | total_actions | waste_ratio |
|---------|------------------------|------------------------------|---------------|-------------|
| 2026-05-10-a1b2c3d4 | 7 | 6 | 14 | 0.43 |
```

## Examples

**Input**: trace file with 3 bash events, then a user_turn, then 4 more bash events.

**Output**:
```
| session | first_clarify_at_action | actions_before_first_clarify | total_actions | waste_ratio |
|---------|------------------------|------------------------------|---------------|-------------|
| 2026-05-10-abcd1234 | 4 | 3 | 7 | 0.43 |
```

**Input**: trace file with only a single user_turn (session start, no follow-up).

**Output**:
```
| session | first_clarify_at_action | actions_before_first_clarify | total_actions | waste_ratio |
|---------|------------------------|------------------------------|---------------|-------------|
| 2026-05-10-abcd1234 | — | 0 | 5 | 0.00 |
```

## Known Failure Modes

- Prompt content is not stored, so the analyzer cannot distinguish "user clarified" from "user asked a fresh follow-up question". False positives expected; treat output as a trend signal, not a precise per-session verdict.
- The user_turn collector only existed from the date this hook was first committed forward. Older trace files lack the `user_turn` markers and will report `No user_turn events found`.
- If a session never received a second user prompt, ratio is `0 / total = 0.00` and the row is informational (no waste to report, not an error).
