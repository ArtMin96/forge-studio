# Trace Clarification

`/trace-clarification` measures how far into a session the first mid-trajectory user clarification arrives and how much work was already done before it. It computes a waste ratio — the fraction of bash and file events that preceded the clarification — and surfaces this as a per-session markdown table. It belongs to the `traces` plugin, which collects and analyzes execution telemetry across Claude Code sessions.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/trace-clarification
```

No arguments required. The skill reads the most recent trace under `~/.claude/traces/` by default, or accepts a file path as an argument.

## Why you need it

The cost of a clarification depends entirely on when it arrives. A clarification at turn two is free — essentially no work has been done yet. The same clarification at turn eighteen means the session spent seventeen turns heading in the wrong direction. Intuition about this timing is unreliable; you tend to remember the frustrating cases vividly and forget the smooth ones. `/trace-clarification` gives you actual numbers: for each session where a mid-trajectory user turn was recorded, it tells you exactly what fraction of that session's actions had already occurred before the course correction.

A waste ratio above 0.5 means more than half the session's work happened before the model received the clarification it needed. When that pattern recurs, it is a strong signal that task framing or goal-setting should happen earlier — either by asking more precisely up front, or by tuning router prompts so the model solicits scope confirmation before committing to a long work trajectory.

## When to use it

- When reviewing whether agent sessions ask clarifying questions early enough, before making changes to router or prompt configuration.
- As input to `/trace-evolve` when the evolve session's failure categorization includes "context loss" or sessions that went off-track before redirecting.
- When comparing several sessions to identify a trend in clarification timing.

Do not use it for numeric summaries of command counts or error rates — that is `/trace-stats`, which is the right entry point for overall session health. `/trace-clarification` is a timing-specific lens: it answers "how far in does clarification arrive?" not "how many commands ran?"

## Best practices

- **Treat the output as a trend signal, not a per-session verdict.** The skill cannot distinguish "user clarified" from "user asked a follow-up question on a separate topic." False positives are expected. A single high-ratio session may not mean the session failed; a pattern of high ratios across multiple sessions is more meaningful.
- **Flag sessions with waste ratio above 0.5.** The skill does this automatically. When you see repeated flags at that threshold, the underlying issue is usually in task framing at session start, not in the model's execution ability.
- **Check trace coverage before drawing conclusions.** The `user_turn` collector only records events from when it was first deployed. Older trace files lack the `user_turn` markers and will report no data. The output flags this case explicitly.
- **Use findings to inform `/trace-evolve` proposals.** If high waste ratios are a recurring pattern, the appropriate proposal might be a new behavioral rule encouraging earlier goal confirmation, or a hook that surfaces scope ambiguity before the first file edit.

## How it improves your workflow

`/trace-clarification` makes the hidden cost of late clarification visible. Once you can see that a given session spent 43% of its actions before a course correction, you have a concrete signal to act on — either by changing how you frame tasks, or by proposing a harness change that catches ambiguous scope before work begins. Over time, sessions where clarification ratios drop consistently are sessions where the harness is doing its job: steering toward goal alignment early, when the cost of correction is still low.

## Related

- [`trace-compile.md`](trace-compile.md) — builds the summary views that provide context for clarification patterns
- [`trace-review.md`](trace-review.md) — the broader pattern-analysis step; useful when clarification timing is one of several failure modes
- [`trace-evolve.md`](trace-evolve.md) — proposes harness changes to address recurring patterns, including late-clarification patterns
- [`trace-stats.md`](trace-stats.md) — the numeric entry point for session health; use it before clarification if you need overall counts first
- [Architecture](../../architecture.md) — where execution traces fit in the 8-component harness model
