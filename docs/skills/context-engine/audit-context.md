# Audit Context

`/audit-context` measures the overhead that loads into your context window before any real work begins. It checks CLAUDE.md file sizes, enumerates enabled plugins and auto-loading skills, surveys active MCP servers, and produces a ranked list of the top token offenders with concrete recommendations. It belongs to the `context-engine` plugin, which provides context measurement, pressure management, and belief-state safety for Forge Studio's harness.

---

## Install

```bash
/plugin install context-engine@forge-studio
```

```text
/audit-context
```

No arguments needed. The skill inspects the global `~/.claude/CLAUDE.md`, the project-root `./CLAUDE.md`, and any parent or child directory CLAUDE.md files it can locate, then builds the full overhead picture from there.

## Why you need it

Every token loaded into the context window before your first message is a token that competes with your actual work. CLAUDE.md files grow incrementally over months, plugins accumulate skill descriptions that load on every session, and MCP servers can multiply tool schemas in ways that are easy to lose track of. None of this overhead shows up in any obvious place — it just quietly narrows your working budget. By the time you notice the session feels sluggish or answers start getting less precise, the bloat may already be substantial.

`/audit-context` makes the invisible visible. It gives you a concrete token estimate for each overhead source and flags which ones exceed recommended ceilings, so you can take targeted action rather than guessing at what to cut.

## When to use it

Reach for `/audit-context` near the start of a long-running session, immediately after someone has complained about latency or reduced quality, or before a planned heavy task where every token in the budget matters:

- Before starting a multi-task sprint or `/orchestrate` pipeline run where you want maximum working space.
- After adding new plugins or MCP servers to a project, to see the actual cost of what you added.
- When compliance with CLAUDE.md rules feels like it has dropped — a file over ~150 instructions is often the root cause.
- When you inherit or share a project and want to understand its context footprint before contributing.

Do not use it for real-time per-turn cost tracking during an active session — use [`/checkpoint`](checkpoint.md) for mid-session drift detection or [`/token-pipeline`](token-pipeline.md) for in-flight pressure relief when context is already filling up.

## Best practices

- **Act on the top two recommendations.** The audit produces a ranked list of offenders; the first two almost always account for the majority of recoverable overhead. Fixing further down the list yields diminishing returns.
- **Apply the 150-instruction ceiling.** The skill flags CLAUDE.md files that exceed roughly 150 lines. That ceiling is not arbitrary — compliance degrades meaningfully above it because the model's attention is finite. Pair the audit output with [`/lean-md`](lean-md.md) to trim the file down.
- **Disable irrelevant plugins per project.** A plugin you installed for a different codebase still loads its skill descriptions into this session. The audit will surface these; use Claude Code's per-project plugin settings to disable them.
- **Prefer `disable-model-invocation: true` for rarely-used skills.** Skills without this flag load their descriptions every session. The audit reports how many auto-loading skills are active; any skill you invoke fewer than once per few sessions is a candidate for this flag.
- **Check MCP server counts.** The audit applies a rule of thumb of under ten active MCP servers and under thirty total tools. If you are over those numbers, weigh each server against how often it is actually used.

## How it improves your workflow

Running `/audit-context` at the start of a heavy session converts a vague sense of "things feel slow" into a numbered overhead budget. Each category — CLAUDE.md weight, plugin descriptions, MCP tools, auto-loading skills — gets its own token estimate, and the final output names exactly which ones to cut and how. That specificity means you spend five minutes trimming real waste instead of thirty minutes wondering why the session is underperforming. It pairs naturally with [`/lean-md`](lean-md.md) for CLAUDE.md reduction and [`/token-pipeline`](token-pipeline.md) for in-session pressure management, forming the measurement layer of the context-engine plugin's broader context-control loop.

## Related

- [`/lean-md`](lean-md.md) — trims an oversized CLAUDE.md file once the audit identifies it as a top offender
- [`/token-pipeline`](token-pipeline.md) — runs the 5-stage pressure-relief pipeline when context is already filling during a session
- [`/checkpoint`](checkpoint.md) — fast mid-session drift check; use instead of audit-context once a session is underway
- [`../token-efficiency/token-audit.md`](../token-efficiency/token-audit.md) — after-the-fact session waste analysis; complements the pre-session measurement this skill provides
- [Architecture](../../architecture.md) — where context management fits in the 8-component harness model
