# Trace Stats

`/trace-stats` gives you a one-screen numeric summary of recent session activity — command counts, error counts, files modified, and per-session error rates — by reading the `session_end` entry from each of the ten most recent JSONL trace files. It belongs to the `traces` plugin, which collects and analyzes execution telemetry across all Claude Code sessions.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/trace-stats
```

No arguments required. The skill reads the ten most recent traces under `~/.claude/traces/` and renders a table.

## Why you need it

Before deciding whether to invest twenty minutes in a full `/trace-review` pass, you want to know whether the data is worth it. A glance at error rates across the last ten sessions answers that question instantly: if the rates are low and stable, nothing urgent is brewing; if one session shows 30% errors and the trend is rising, you have a concrete reason to dig in. `/trace-stats` provides that 30-second check without requiring compiled views, model invocation, or any analysis overhead. It reads only the `session_end` summary line from each trace file, making it extremely cheap to run.

## When to use it

- As a morning sanity check on yesterday's sessions before starting new work.
- Before deciding whether `/trace-review` is warranted — a clean stats table says no; elevated or trending error rates say yes.
- When reporting overall harness usage — the table shows cumulative session activity at a glance.

Do not use it for failure clustering or proposal generation — that requires `/trace-review` for pattern analysis and `/trace-evolve` for proposals. `/trace-stats` gives counts; the other skills give meaning.

## Best practices

- **Watch the trend, not the peak.** A single high-error session is often noise. An error rate climbing across three or four consecutive sessions is a signal worth routing to `/trace-review`.
- **Check the "Today" line.** The skill surfaces the current day's session detail separately at the bottom of the table. This is the fastest way to confirm that the traces plugin's collectors are active and writing data.
- **If no trace files exist, install the plugin first.** The skill detects the empty case and tells you what to do; if `~/.claude/traces/` is missing or empty, the collectors have not run yet and the table will have nothing to show.

## How it improves your workflow

`/trace-stats` is the entry point to the traces analysis pipeline — fast enough to run habitually, cheap enough that you never skip it. By giving you error rates and command volumes at a glance, it calibrates how much attention to give the session data before you commit to a deeper analysis. The ten-session window is wide enough to reveal trends but narrow enough to remain immediately readable. Used as a daily habit, it prevents patterns from accumulating unnoticed for weeks.

## Related

- [`trace-review.md`](trace-review.md) — the full pattern-analysis step when stats reveal elevated error rates
- [`trace-compile.md`](trace-compile.md) — builds structured views that make review faster; not required by trace-stats itself
- [`trace-evolve.md`](trace-evolve.md) — proposes harness changes based on the patterns review surfaces
- [Architecture](../../architecture.md) — where execution traces fit in the 8-component harness model
