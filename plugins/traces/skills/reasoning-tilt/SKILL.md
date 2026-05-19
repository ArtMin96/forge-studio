---
name: reasoning-tilt
description: Use when you want to detect whether a session's command and output text is leaning toward forward-looking framing ("next", "let me try", "plan to") vs. history-following framing ("blocked", "failed", "can't"). Scores a JSONL trace file with a forward/history lexical ratio and flags sessions that have drifted into the cursed regime (ratio < 0.40).
when_to_use: Reach for this after a long or frustrating session to check whether the trace content has shifted toward repetitive failure language. Also useful when comparing several sessions to spot a downward trend. Do NOT use for numeric summaries — that's /trace-stats; or structural failure clustering — that's /trace-review.
disable-model-invocation: true
model: haiku
paths:
  - "~/.claude/traces/*.jsonl"
allowed-tools:
  - Bash
  - Read
logical: forward/history ratio emitted for the target trace; tilt classification printed as tilt:forward | tilt:balanced | tilt:history
scheduling: when a trace file exists and the user asks about session quality, reasoning drift, or failure-language accumulation
structural:
  - find the target trace file (most recent by default, or path from argument)
  - run bash scripts/score.sh [trace_file]
  - read the ratio output and surface the tilt classification
  - flag if ratio < 0.40 (absolute floor) or ≥ 0.10 below trailing-3-session average
---

# Reasoning Tilt

Scores JSONL trace files for forward-looking vs. history-following lexical bias — a signal for whether accumulated failure content is shifting the session's reasoning register.

## Metric Basis

This skill borrows the lexical-shift mechanism from Liu et al. 2026, "The Memory Curse" (arXiv:2605.08060v1 §D.2 + §E.1). In that paper, cooperative-word frequency collapses while defensive-word frequency stays flat as LLM history length grows — the mechanism behind cooperation degradation in multi-agent social-dilemma games.

The metric is **reused as a lexical signal only**. The cooperation-game framing (game payoffs, grudge-holder dynamics, multi-agent bargaining) does not transfer to single-user dev sessions and is explicitly disclaimed. What does transfer: the observation that accumulated negative content shifts LLM reasoning language in a measurable, lexically detectable direction.

Paper's cursed-regime threshold: forward-looking ratio ≈ 0.340 at history-length 80. This skill uses 0.40 as the absolute flag floor to provide earlier warning.

## Process

1. **Identify the trace file**: argument if provided, otherwise most recent under `~/.claude/traces/`.
2. **Run the scorer**: `bash scripts/score.sh [trace.jsonl]`
3. **Read the output** and surface the ratio and tilt line.
4. **Flag when**:
   - Ratio < 0.40 (absolute floor — close to paper's cursed-regime 0.340).
   - Current session ratio is ≥ 0.10 below the trailing-3-session average (trend flag).

## Output

```
Trace: ~/.claude/traces/2026-05-12-eb66bb3d.jsonl
Forward tokens: 84
History tokens: 36
Forward ratio: 84/120 = 0.70
tilt:forward
```

## Examples

Input: trace with many "let me try", "next step", "plan to" bash commands and output_preview lines.

Output:
```
Trace: ~/.claude/traces/2026-05-12-eb66bb3d.jsonl
Forward tokens: 84
History tokens: 36
Forward ratio: 84/120 = 0.70
tilt:forward
```

Input: trace with repeated "blocked again", "still failing", "can't" output_preview content.

Output:
```
Trace: ~/.claude/traces/2026-05-10-abcd1234.jsonl
Forward tokens: 18
History tokens: 47
Forward ratio: 18/65 = 0.28
tilt:history  [cursed-regime: paper threshold ≈ 0.340, flag at < 0.40]
```

## Threshold Guidance

| Ratio | Classification | Implication |
|-------|----------------|-------------|
| ≥ 0.60 | `tilt:forward` | Session is healthy; forward-planning language dominates |
| 0.40 – 0.59 | `tilt:balanced` | Normal mixed session; no flag |
| < 0.40 | `tilt:history` | Flag: approaching or in the cursed regime; consider `/forward-briefing` at next session start |

Paper's immune-model median: ~0.504. Paper's cursed-model floor: ~0.340. This skill's flag threshold (0.40) sits between them for early warning.

## Vocabulary

The lexical vocabulary lives in `scripts/vocab.tsv` (two-column TSV: `class<TAB>token`). Edit it directly to tune the signal without touching this file. The seed list is adapted from arXiv:2605.08060v1 §E.1 Pure Cooperation / Pure Paranoia word lists, with cooperation-game terms replaced by dev-reasoning equivalents.

## Known Failure Modes

- Traces only capture `command` and `output_preview` text — no raw model reasoning field exists in forge-studio JSONL. The metric is a proxy, not a direct reasoning read.
- Short traces (few bash events) produce low token counts; the scorer emits `n/a (insufficient signal)` when total matches are zero.
- Multi-word tokens (e.g., "still failing") are matched as substrings, not word-boundary-delimited, which can inflate counts in long output previews.
