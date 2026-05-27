# Caveman

`/caveman` switches the prose compression level Claude uses for the rest of the session. It controls three intensity settings — `lite`, `full`, and `ultra` — each of which removes a different layer of verbal overhead from responses. Code blocks, error messages, and tool output are never affected; caveman governs prose only. It belongs to the `caveman` plugin, which installs a `UserPromptSubmit` hook that re-injects the chosen compression rules on every turn so the setting persists across the session.

---

## Install

```bash
/plugin install caveman@forge-studio
```

```text
/caveman <lite|full|ultra>
```

The argument selects the compression level. The session default when the plugin is installed is `full`.

## Why you need it

Claude's default prose is complete-sentence, article-and-conjunction, pleasantry-inclusive text. That style is appropriate when precision and readability matter equally. In a fast-moving debugging session or a long context window where every token counts, it is overhead: preambles, hedges, filler words, and articles that carry no information but occupy space and attention. `/caveman` removes that overhead on demand without touching any other behavior.

The three levels are calibrated to different situations. `full` — the default when the plugin is installed — drops articles and allows fragments, which removes the bulk of filler without making responses hard to parse. `ultra` goes further: abbreviations, arrow notation for causality, single-word answers when one word is sufficient. `lite` trims only the most egregious filler (hedging, pleasantries) while preserving full sentences — useful when the output will be read by someone unfamiliar with the abbreviated style.

The hook mechanism matters: without re-injection on every `UserPromptSubmit`, the compression setting would decay after a compaction or a long gap. The hook keeps it persistent for the session.

## When to use it

- When a debugging session is moving fast and you want direct, fragment-style responses with no preamble.
- When context is tight and you need to conserve tokens on prose without changing how code and errors are formatted.
- When switching from a compressed session back toward readable output for a specific output — such as a commit message or documentation draft — use `/caveman lite` or tell Claude "normal mode" to revert.

Do not use it to compress code-block contents — caveman applies to prose only; code, errors, and tool output remain verbatim regardless of the intensity level. Do not use it to reduce session token overhead — use [`/token-audit`](../token-efficiency/token-audit.md) instead, which identifies and addresses the actual sources of session cost such as duplicate reads and MCP overhead. Caveman changes output style; it does not affect how many tokens are spent on tool calls or injected context.

## Best practices

- **Use `ultra` only for exploratory back-and-forth.** Telegraphic responses at `ultra` level are fast and efficient for quick questions, but they can be ambiguous in multi-step sequences where fragment order matters. The skill's auto-clarity rule drops caveman automatically for security warnings and irreversible action confirmations — but explicit multi-step instructions benefit from `full` or `lite` to avoid misread order.
- **Switch levels, do not fight the setting.** If a response at `full` is still too verbose, try `ultra`. If a response at `full` is too clipped for something you need to share, try `lite`. The levels are cheap to switch; there is no cost to changing mid-session.
- **Remember the boundary: prose only.** Caveman does not touch commits, pull requests, documentation files, or code. If you ask Claude to write a commit message or a README section while caveman is active, those outputs are written in normal prose regardless of the compression level.
- **"Normal mode" or "stop caveman" reverts the setting.** These phrases are recognized and revert Claude to standard output style without requiring a skill invocation.

## How it improves your workflow

`/caveman` makes the density of responses configurable to the task at hand. A debugging session where you are firing quick questions benefits from `ultra`; a code-review session where you want full reasoning benefits from `lite` or default prose. By persisting the setting through the hook re-injection mechanism rather than relying on per-turn instruction, it eliminates the need to include compression instructions in every prompt. The result is that response verbosity matches what the task needs rather than defaulting to the same style regardless of context.

## Related

- [`../token-efficiency/token-audit.md`](../token-efficiency/token-audit.md) — measures actual session token overhead from reads, churn, and MCP servers; the right tool when cost is the concern rather than prose density
- [Architecture](../../architecture.md) — behavioral steering in the 8-component harness model
