# Trace Evolve

`/trace-evolve` reads the compiled execution trace views from recent sessions, clusters their failure patterns, and writes a structured proposal artifact suggesting specific harness changes — new behavioral rules, hook conditions, or skill enhancements — to address what the data shows. It belongs to the `traces` plugin, which powers Forge Studio's execution telemetry and analysis pipeline.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/trace-evolve
```

No arguments required. The skill checks for compiled summary and error views under `~/.claude/traces/` and will ask you to run `/trace-compile` first if none are found.

## Why you need it

Without a feedback loop, a harness accumulates workarounds for failures that happen repeatedly without ever being addressed structurally. The session ends, the frustration fades, and three weeks later the same failure pattern recurs. `/trace-evolve` breaks that cycle by treating the trace record as a formal input to harness improvement. It identifies clusters of failures that have appeared at least three times across at least two sessions — the minimum threshold for a pattern worth acting on — and generates a single-variable proposal for each: one rule, one hook condition, or one checklist addition. Single-variable changes are important because they keep regression attribution tractable; if a new rule causes a different problem, you know exactly what to revert.

The skill produces a proposal artifact written to `.claude/lineage/proposals/`, not changes to harness files. Applying changes is the job of `/evolve` → `/assess-proposal` → `/commit-proposal`.

## When to use it

- On a weekly cadence, as part of a harness health review after running `/trace-compile` and `/trace-review`.
- When failures feel "the same as last time" — the trace record either confirms the pattern or rules it out.
- When you want data-driven improvement proposals rather than guesses about what to fix.

Do not use it for applying changes — run `/evolve` → `/assess-proposal` → `/commit-proposal` to move from proposals to committed harness edits. `/trace-evolve` only proposes; it never modifies harness files.

## Best practices

- **Compile first.** The skill loads summary and error views to avoid drowning in raw JSONL. Running `/trace-compile` before `/trace-evolve` makes the analysis faster and the proposals more precise.
- **Trust the three-occurrence threshold.** One failure is noise; two might be coincidence; three across two or more sessions is a pattern. Resist the urge to propose a change for a single bad session.
- **Read the token impact estimates.** Every new `rules.d/` entry costs tokens on every message. The proposal report includes a token impact estimate for each suggestion; factor this in before accepting rules that add overhead without clear behavioral benefit.
- **Use the proposal as a starting point, not a final answer.** `/trace-evolve` proposes one change per cluster based on what the traces show. A human reviewer may see a better fix; the proposal is a structured recommendation, not a mandate.
- **Don't propose removing existing rules or hooks.** The skill follows this discipline itself: additions only. Removals require separate analysis of what the existing rule was protecting against.

## How it improves your workflow

`/trace-evolve` closes the loop between execution telemetry and harness improvement. Every recurring failure that gets clustered and proposed is a failure that stops recurring once the right rule or hook is in place. Over weeks, this process converts anecdotal frustration into a progressively better-tuned harness — one that catches the real patterns that emerge from real usage, rather than patterns someone guessed at up front. Running it weekly keeps the improvement cadence regular and the individual proposals small and reviewable.

## Related

- [`trace-compile.md`](trace-compile.md) — builds the structured views this skill requires; run it first
- [`trace-review.md`](trace-review.md) — the pattern-identification step; run between compile and evolve
- [`trace-stats.md`](trace-stats.md) — the entry-point numeric check before deciding whether evolve is warranted
- [`failure-attribute.md`](failure-attribute.md) — locates the specific manifest entry that introduced a regression; complements evolve when a single causal change is suspected
- [Architecture](../../architecture.md) — where harness evolution fits in the 8-component model
