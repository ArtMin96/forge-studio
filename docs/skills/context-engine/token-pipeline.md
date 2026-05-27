# Token Pipeline

`/token-pipeline` runs a structured five-stage analysis of the current session's context load — Collection, Ranking, Compression, Budgeting, and Assembly — and emits a single boxed next-action recommendation when it finishes. Rather than leaving you with a vague sense that "context feels heavy," it produces a concrete decision: run `/compact`, apply `/lean-md`, write a `/progress-log` and open a fresh session, or continue as-is. It belongs to the `context-engine` plugin, which provides context measurement, pressure management, and belief-state safety for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install context-engine@forge-studio
```

```text
/token-pipeline
```

No arguments. The skill inventories CLAUDE.md files, the MCP instruction log, the memory index, active plan and spec files, features.json, and the progress tail, then scores each source and works through the five stages to a recommendation.

## Why you need it

Context pressure mid-session is qualitatively different from the pre-session overhead that [`/audit-context`](audit-context.md) measures. Before the session starts, overhead is static and predictable. During a long session, it compounds: plan files grow, progress logs accumulate entries, memory pointers multiply, and the conversation itself fills. At some point the aggregate crosses a threshold where compaction becomes necessary — but "at some point" is not a useful decision criterion.

The Token Transformation Pipeline (TRAE §5.2.2) gives that decision a structure. Each stage answers a specific question: what is loaded (Collection), what matters most right now (Ranking), what can be compressed or dropped (Compression), what the per-category budget should be (Budgeting), and what the single highest-payoff action is (Assembly). The five-stage structure converts a judgment call into a reproducible analysis, and the boxed recommendation at the end converts that analysis into an action you can take immediately.

## When to use it

The `track-context-pressure.sh` hook fires this skill automatically at roughly 65% context pressure or after approximately 15 exchanges. You can also invoke it manually any time the session feels heavy or auto-compact looks imminent:

- When the status line shows context usage approaching 65% and you want a structured decision rather than guessing.
- After a long debugging detour where many files were read and tools were called, to assess what the detour cost.
- When the session has accumulated plan updates, spec changes, and memory entries and you want to know which ones are now the dominant load.
- When a previous `/token-pipeline` recommendation was "continue" and you want to re-check after more work has been done.

Do not use it for a holistic context audit before work starts — that is [`/audit-context`](audit-context.md), which measures the static overhead of plugins, MCP servers, and CLAUDE.md files at session start. `/token-pipeline` is the in-flight pressure-relief decision for a session already underway.

## Best practices

- **Act on the Assembly recommendation, not the individual stage outputs.** The five stages exist to produce the final recommendation with confidence. Reading the Ranking table and deciding to act on a low-scoring entry yourself — rather than following the Assembly output — bypasses the purpose of the structured analysis. Trust the Assembly stage.
- **Do not auto-execute the recommended skill.** The skill explicitly does not run `/compact` or `/lean-md` on your behalf. The recommendation is advisory; you choose whether and when to act. This matters because compaction is irreversible and `/lean-md` rewrites a file — both deserve a conscious decision.
- **Do not print file contents.** The skill inventories files by size and heading, not by content. If you find yourself about to include CLAUDE.md or a plan's full text in the analysis, stop — that defeats the purpose of measuring the load.
- **Check `jq` availability before relying on features.json stage.** If `jq` is not installed, the skill skips the features.json entry count and notes the gap in output. Install `jq` to get complete coverage on projects that use `.claude/features.json`.
- **Pair with `/progress-log` before acting on a "fresh session" recommendation.** When Assembly recommends starting a fresh session, the correct sequence is `/progress-log` first (to preserve session state) and then `/clear`. Skipping the log loses the continuity that the next session needs.

## How it improves your workflow

`/token-pipeline` converts the most common mid-session anxiety — "should I compact now?" — from a judgment call into a five-stage analysis with a single concrete output. The Ranking stage surfaces which sources are low-relevance and high-size (Lost in the Middle candidates); the Budgeting stage gives every category a named cap so future sessions can be planned against it; and the Assembly stage ensures the recommendation is the one with the highest expected payoff, not just the most obvious one. The automatic trigger at 65% pressure means you rarely need to remember to invoke it — but the manual invocation gives you access to the same analysis on demand, at any point in the session.

## Related

- [`/audit-context`](audit-context.md) — pre-session overhead measurement; use before the session starts rather than during
- [`/checkpoint`](checkpoint.md) — fast mid-session task-alignment check; lighter than token-pipeline, focused on drift rather than pressure
- [`/lean-md`](lean-md.md) — the skill token-pipeline recommends when CLAUDE.md is the dominant load
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — the skill token-pipeline recommends before a fresh-session restart
- [`../token-efficiency/token-audit.md`](../token-efficiency/token-audit.md) — after-the-fact session waste analysis; reads the same sources token-pipeline inventories, from a post-session perspective
- [`../memory/recall.md`](../memory/recall.md) — memory index referenced in token-pipeline's Collection stage; `/memory-index` audit is one of its compression recommendations
- [Architecture](../../architecture.md) — where context management fits in the 8-component harness model
