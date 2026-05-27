# Token Audit

`/token-audit` scans the current session for token waste — duplicate file reads, high edit-churn files, active MCP server count, and CLAUDE.md size — and returns a compact findings table plus the top three optimization recommendations based on what it actually finds. It belongs to the `token-efficiency` plugin, which measures and reduces runtime token overhead in Claude Code sessions.

---

## Install

```bash
/plugin install token-efficiency@forge-studio
```

```text
/token-audit
```

No arguments. The skill runs four checks against the current session and the active configuration, then emits the findings table and recommendations.

## Why you need it

Token overhead in a Claude Code session accumulates from several independent sources, and none of them announce themselves: a file gets read multiple times because context compacted between two edits; a hot file gets edited and re-edited until the churn count climbs; three MCP servers each inject their instruction blocks into every request; a CLAUDE.md that grew past 200 lines now rides along with every turn at full cost. Each source is individually small, but together they can double the effective session cost and introduce noticeable latency.

`/token-audit` makes these sources visible. It does not estimate overhead theoretically — it checks the actual session data (the reads log, the edits log, the `mcp list` count, the CLAUDE.md line count) and reports what it finds. Recommendations name specific files or servers when relevant, so the output is actionable rather than generic.

## When to use it

- Near the end of an expensive session, when you want to understand where the overhead came from before the session closes.
- After a noticeable latency spike, to check whether the spike correlates with a specific waste source.
- Whenever the session feels sluggish and you suspect overhead is climbing but are not sure which component is responsible.

Do not use it for pre-task configuration overhead — that is [`/audit-context`](../context-engine/audit-context.md), which measures CLAUDE.md size, MCP server load, and loaded skills before a session gets expensive. `/token-audit` measures runtime waste during an ongoing session; `/audit-context` measures startup overhead before it accumulates.

## Best practices

- **Run it before closing a long session.** The findings inform which patterns to change for the next session — if duplicate reads are the top finding, the fix is context discipline (read once, stay organized); if CLAUDE.md is over 200 lines, the fix is to trim it before the next session starts.
- **Act on the named recommendations.** The skill names the specific file or server in each recommendation when the data supports it. "Trim `CLAUDE.md` from 240 to under 200 lines" is more actionable than "reduce CLAUDE.md size" — treat the named output as the actual task, not a hint.
- **Pair with `/audit-context` for a full picture.** `/token-audit` sees runtime waste; `/audit-context` sees configuration overhead. Running both gives a complete view of where tokens go.
- **Do not confuse style compression with overhead reduction.** `/caveman` changes prose density and can make responses shorter, but it does not reduce the token cost of tool calls, injected context, or file reads. If the audit finds overhead, fix the overhead source — not the response style.

## How it improves your workflow

`/token-audit` makes session overhead legible. Without it, a session that cost twice what it should is just an expensive session — you leave not knowing what to change. With it, the top three sources are named, ranked by impact, and tied to concrete fixes. Over several sessions the patterns become clear — which habits generate duplicate reads, which configurations inject too much context — and the overhead trend reverses without requiring discipline around every individual operation.

## Related

- [`../context-engine/audit-context.md`](../context-engine/audit-context.md) — pre-session configuration audit; covers CLAUDE.md size, MCP overhead, and loaded skills before runtime waste accumulates
- [`../caveman/caveman.md`](../caveman/caveman.md) — prose compression; changes output style, not session token overhead
- [Architecture](../../architecture.md) — context management in the 8-component harness model
