# Trace Review

`/trace-review` reads the five most recent JSONL execution traces and produces a structured report covering recurring command failures, frequently modified files, and session health trends across that window. It belongs to the `traces` plugin, which collects and analyzes execution telemetry to give you a factual record of how agentic sessions actually behave over time.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/trace-review
```

No arguments required. The skill locates the five most recent trace files under `~/.claude/traces/` automatically.

## Why you need it

A single session tells you what happened once. `/trace-review` tells you what keeps happening. The difference matters because the most expensive problems in agentic workflows are not one-off failures — they are patterns: the same `npm test` assertion failing week after week, the same middleware file being edited eleven times across sessions without a covering test, the same grep queries running six times a session and returning nothing. These patterns are invisible if you only look at the current session; they become obvious when five sessions are read side by side.

The skill produces actionable, pattern-level findings rather than raw data. It names the recurring failure, states how many times it appeared across how many sessions, and tells you what to do about it.

## When to use it

- After `/trace-compile` has built structured views, when you want to understand what patterns emerged over the past week.
- When investigating a session with a high error rate and wanting to know whether it is a one-off or the continuation of a trend.
- When looking for recurring patterns that have not yet been turned into harness improvement proposals.

Do not use it for compiling raw traces — run `/trace-compile` first to build the summary and error views that `/trace-review` reads. Do not use it for proposing harness fixes — that is `/trace-evolve`, which takes the patterns `/trace-review` surfaces and converts them into concrete rule, hook, or skill proposals.

## Best practices

- **Run `/trace-compile` first.** If compiled views do not yet exist for recent sessions, the review reads raw JSONL which is less efficient and may miss patterns that structured views surface clearly.
- **Pay attention to the session health trend line.** A "degrading" trend — rising error rates across consecutive sessions — is often more significant than a single high-error session. Act on the trend, not just the peak.
- **Treat file hotspots as test coverage signals.** A file modified more than three times in a session, or appearing as a hotspot across multiple sessions, is a strong indicator that a targeted test is missing. The recommendation section of the report usually names this directly.
- **Cross-reference with `/trace-clarification`.** If the recurring failure involves unclear task scope or the model going off in the wrong direction, `/trace-clarification` can tell you how far into those sessions work was already done before the course correction arrived.

## How it improves your workflow

`/trace-review` closes the feedback loop between what you observe in a single session and what the harness actually does repeatedly. By surfacing patterns across five sessions in one report, it turns anecdotal frustration ("the tests keep failing on this file") into evidence ("this command failed 23 times across 4 sessions, always on the same assertion"). That evidence is what makes `/trace-evolve` proposals credible — they are grounded in measured recurrence, not in a single bad day. Running `/trace-review` weekly keeps the cost of harness improvement low by catching patterns early, before they accumulate into significant workflow drag.

## Related

- [`trace-compile.md`](trace-compile.md) — builds the structured views this skill reads; run it first
- [`trace-evolve.md`](trace-evolve.md) — takes the patterns from this report and proposes harness rule / hook / skill changes
- [`trace-stats.md`](trace-stats.md) — the lightweight numeric alternative when you only need counts, not patterns
- [`trace-clarification.md`](trace-clarification.md) — the timing lens; useful when review surfaces wasted-turn patterns
- [Architecture](../../architecture.md) — where execution traces fit in the 8-component harness model
