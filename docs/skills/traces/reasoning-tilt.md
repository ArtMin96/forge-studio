# Reasoning Tilt

`/reasoning-tilt` scores a JSONL trace file for forward-looking versus history-following lexical bias and classifies the session as `tilt:forward`, `tilt:balanced`, or `tilt:history`. A ratio below 0.40 triggers a flag indicating the session has accumulated enough failure-language content to approach the "cursed regime" documented in research on memory-length effects in LLM reasoning. It belongs to the `traces` plugin, which collects and analyzes execution telemetry across Claude Code sessions.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/reasoning-tilt [trace-file]
```

The optional argument is a path to a specific JSONL trace. Without it, the skill uses the most recent file under `~/.claude/traces/`.

## Why you need it

Long or frustrating sessions accumulate a particular kind of content in the trace record: repeated failure messages, "still failing", "blocked again", "can't do this". Research on LLM context effects (Liu et al. 2026, arXiv:2605.08060) shows that accumulated negative history shifts reasoning language in a measurable lexical direction — the frequency of forward-planning words drops while defensive and retrospective language persists. This shift is detectable before it becomes severe, which makes early flagging worthwhile.

`/reasoning-tilt` applies this detection mechanically. It scores the `command` and `output_preview` fields in the trace against two vocabulary lists — forward-leaning tokens like "next", "plan to", "let me try" and history-following tokens like "blocked", "failed", "can't" — and computes the ratio. A healthy session sits above 0.60. A session approaching the cursed regime falls below 0.40, at which point the skill flags it and suggests running `/forward-briefing` at the start of the next session to reset the reasoning register.

## When to use it

- After a long or frustrating session to check whether the trace content has shifted toward repetitive failure language before starting the next session.
- When comparing several sessions to spot a downward trend in forward-planning language across consecutive days.

Do not use it for numeric summaries of command counts or error rates — that is `/trace-stats`. Do not use it for structural failure clustering across sessions — that is `/trace-review`. `/reasoning-tilt` is the session-quality lens specifically for reasoning register drift.

## Best practices

- **Check both the absolute ratio and the trend flag.** The skill flags when the ratio drops below 0.40 (absolute floor) and also when it is 0.10 or more below the trailing three-session average. The trend flag catches drift that has not yet crossed the absolute threshold.
- **Use the vocabulary file to tune the signal.** The lexical vocabulary lives in `scripts/vocab.tsv` (a two-column TSV of `class` and `token`). If your codebase uses specific terminology that the seed vocabulary misses, add those tokens directly without touching the SKILL.md.
- **Short traces produce low-confidence scores.** When a session has very few bash events, the total token count in the vocabulary match is small. The scorer emits `n/a (insufficient signal)` in that case rather than a misleading ratio.
- **The metric is a proxy, not a direct reasoning read.** Traces capture command text and output previews, not the model's internal reasoning. The tilt classification is a useful early-warning signal, not a definitive judgment about reasoning quality.

## How it improves your workflow

`/reasoning-tilt` gives you a session-level quality signal that is otherwise invisible. Without it, the only way to know whether a session's failure accumulation is affecting subsequent reasoning is to notice it subjectively — which typically happens too late, after several turns have already been spent in a degraded mode. With it, you get an objective ratio and a classification at the end of each session, and a concrete recommendation (run `/forward-briefing` next time) when the signal crosses the flag threshold. The result is earlier intervention and shorter recovery time from sessions that went sideways.

## Related

- [`trace-stats.md`](trace-stats.md) — numeric session summary; use before reasoning-tilt for a count-level orientation
- [`trace-review.md`](trace-review.md) — structural failure clustering across sessions; the pattern-level complement to reasoning-tilt's lexical signal
- [`../long-session/forward-briefing.md`](../long-session/forward-briefing.md) — the recovery skill to run at next session start when tilt:history is flagged
- [Architecture](../../architecture.md) — where execution traces fit in the 8-component harness model
