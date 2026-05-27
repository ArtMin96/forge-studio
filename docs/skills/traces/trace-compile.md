# Trace Compile

`/trace-compile` reads the raw JSONL execution logs that the `traces` plugin's collector hooks write during every session and converts them into two structured markdown views — a chronological summary and a filtered error log — so the other trace-mining skills have something efficient to work with. It belongs to the `traces` plugin, which is responsible for collecting and analyzing execution telemetry across all Claude Code sessions.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/trace-compile
```

No arguments are required. The skill finds the most recent JSONL trace under `~/.claude/traces/` automatically, or you can supply a specific file path.

## Why you need it

Raw JSONL trace files are dense. Each line is a JSON object and the file for a busy session can hold hundreds of entries spanning bash commands, file edits, and session-end summaries. Reading these directly forces the analyzer — model or human — to parse JSON, discard noise, and navigate linearly, which is slow and expensive in context tokens. The two compiled views solve this: the summary view gives one timestamped line per event, and the error view collects each failure together with the command that preceded it so triage context is never missing. Downstream skills like `/trace-review` and `/trace-evolve` read these views rather than the raw JSONL, which cuts the token cost of analysis significantly and improves the quality of pattern detection.

## When to use it

- Before running `/trace-review` or `/trace-evolve` — those skills check for compiled views first and will ask you to run `/trace-compile` if none are found.
- After a session with a high error rate, when you want to inspect what went wrong before the trace details grow stale.
- Periodically as part of a weekly harness health review, so summaries from recent sessions are ready when you need them.

Do not use it for quick numeric summaries — use `/trace-stats` instead, which reads the raw JSONL's `session_end` entries directly without needing a compile step.

## Best practices

- **Run it before the other trace skills.** `/trace-review` and `/trace-evolve` are faster and more accurate when compiled views already exist. Compile once at the start of an analysis session rather than re-compiling repeatedly.
- **Check the error rate in the quick-stats report.** The report it emits at the end shows the percentage of commands that failed. A rate above roughly 20% is a signal worth investigating with `/trace-review`.
- **Look at the most-edited file field.** The quick-stats section surfaces the file that was touched most often in the session. High edit counts on a single file often indicate thrashing — the model making incremental, oscillating changes rather than one correct one.
- **Follow specific entries to the full JSONL when needed.** The summary view is for orientation; when a failure entry in the error view raises a question, go back to the source JSONL for the raw `output_preview` content.

## How it improves your workflow

`/trace-compile` is the first step in the traces plugin's analysis pipeline. By converting raw event streams into structured, skimmable views, it makes the rest of the trace-mining workflow tractable at scale. Without compiled views, analyzing a week of sessions would require loading gigabytes of raw JSON; with them, the same analysis reads a handful of tightly scoped markdown files. The result is that pattern detection in `/trace-review` runs faster, proposal generation in `/trace-evolve` starts from cleaner input, and the feedback loop between execution telemetry and harness improvement stays practical to run weekly.

## Related

- [`trace-review.md`](trace-review.md) — reads compiled views to surface recurring failure patterns and file hotspots
- [`trace-evolve.md`](trace-evolve.md) — takes the patterns from review and proposes concrete harness changes; requires compiled views
- [`trace-stats.md`](trace-stats.md) — the lightweight numeric alternative; no compile step required
- [`trace-clarification.md`](trace-clarification.md) — timing-specific analysis of how far into a session clarification arrives
- [Architecture](../../architecture.md) — where execution traces fit in the 8-component harness model
