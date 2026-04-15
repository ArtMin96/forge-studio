# Token Optimization Guide

Where tokens go and how to spend fewer of them.

This is a practical guide. The underlying research lives in [token-optimization-research.md](token-optimization-research.md). Read that for source citations and confidence levels. This doc is for people who want to act.

---

## Where Tokens Go Before You Type Anything

A Claude Code session with no input from you already costs ~20,000-30,000 tokens. This is your baseline.

| Component | Typical Tokens | Controllable? |
|---|---|---|
| System prompt | ~3,500 | No |
| CLAUDE.md | 3,000–18,000 | Yes — keep under 200 lines |
| MCP tool schemas | ~9,000 per server | Yes — limit servers, use deferred loading |
| Agent definitions | ~3,300 | Partially — disable unused agents |
| Skills metadata | ~2,600 | No (zero-cost until invoked) |
| Subagent baseline | ~50,000 each | Yes — see `/lean-agents` |

CLAUDE.md is the one you control most directly. A bloated CLAUDE.md (project instructions + conventions + every edge case you've ever encountered) can push baseline cost above 20K before the session starts. Move specialized content to skills — they load on-demand, not every session.

---

## The 3 Habits That Actually Matter

Most token waste isn't a settings problem. It's a workflow problem.

**1. `/clear` between unrelated tasks.**
Context from task A is noise during task B. File reads, error messages, design decisions — all of it accumulates and the model references it. A fresh session costs nothing extra. An accumulated session costs proportionally more with every exchange.

**2. `/compact` at 60-70% capacity, not 90%.**
Auto-compaction at ~95% produces low-quality summaries — there's too much to compress and Claude doesn't know what matters. At 70%, the summary is readable and your architectural decisions survive. At 90%, you get a lossy summary and you'll spend tokens re-establishing context. Use `/cost` or a status line to watch the gauge.

**3. Subagents for exploration — verbose reads stay in their context.**
When you need to understand an unfamiliar codebase, the worst approach is reading 20 files in the main conversation. Every file read stays in context for the rest of the session. Spawn a subagent with a specific question; it reads whatever it needs, summarizes the answer, and its context disappears. The parent session sees one clean response.

---

## Settings That Reduce Cost

```json
{
  "model": "sonnet",
  "env": {
    "MAX_THINKING_TOKENS": "10000",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  }
}
```

**`"model": "sonnet"`** — Opus costs ~5x Sonnet per token. Sonnet handles ~80% of real development work without quality loss: writing tests, simple edits, explaining code, reading logs. Reserve Opus for genuinely complex multi-file reasoning or architecture decisions.

**`MAX_THINKING_TOKENS: "10000"`** — Extended thinking defaults to 31,999 tokens per request, billed as output tokens (expensive). Capping at 10,000 cuts thinking cost by ~70%. For most tasks, 10K is more than enough internal deliberation.

**`CLAUDE_CODE_SUBAGENT_MODEL: "haiku"`** — Subagents inherit the parent model by default. A Haiku subagent exploring 30 files to find a function signature is doing mechanical search work — it doesn't need Opus. This setting runs all subagents on Haiku unless you override per-agent.

Combined, these three settings yield roughly 60% cost reduction versus always-on Opus with default thinking.

---

## What Breaks Prompt Cache

Prompt cache gives a 90% discount on input tokens. Without cache hits, every exchange in a long session sends the entire system prompt, all tool schemas, your CLAUDE.md, and all prior conversation — full price, every time. Breaking the cache is the single most expensive mistake you can make per session.

**These actions bust the cache:**

- **Adding or removing MCP servers mid-session.** Tool schemas are part of the cached prefix. Any change invalidates everything after it.
- **Modifying CLAUDE.md during a session.** CLAUDE.md is in the static pre-boundary section. Edit it between sessions, not during.
- **Switching models in the main conversation.** The cache is model-specific. Switching to Haiku to "save money" mid-session costs more than staying on Opus — you're rebuilding 100K+ tokens of cache.
- **5-minute inactivity.** The 5-minute TTL expires and the cache is gone. If you step away mid-session, the next exchange costs full input price.

The cache rebuilds from the next message. But if you're in message 40 of a complex session, rebuilding cache on a 50K-token context is expensive.

The safest model-switching pattern: use subagents for tasks that need a different model. The parent session's cache stays intact.

---

## Common Waste Patterns

**1. Duplicate file reads.**
Parent reads a file, spawns a subagent, subagent re-reads the same file. For small files (<100 lines), pass the content directly in the prompt — it's cheaper than a second read. For large files, the re-read is unavoidable and acceptable. Just don't do it reflexively for small files.

**2. Full file reads when you need one function.**
Reading a 900-line file to locate one method costs 8,000-12,000 tokens. Use `Grep` to find the line number, then `Read` with `offset` and `limit` to pull the relevant block. 200 tokens vs 10,000 tokens.

**3. Verbose tool output entering context.**
Test suites dumping 500 lines of output, build logs, MCP tools returning paginated API results — all of it enters context. A `PostToolUse` hook that filters test output to failures only can reduce a 5,000-token test run to 200 tokens. The Anthropic hooks docs include this pattern explicitly.

**4. Stale context from prior tasks.**
You finished feature A and moved to bug B. Feature A's files, error traces, and design discussion are still in context. The model may reference them. `/clear` costs zero — the only thing you lose is context you don't need.

**5. Over-exploration.**
An agent asked to "investigate the auth system" may read 20 files when 3 would answer the question. Scoped prompts get scoped reads. "Find where JWT tokens are validated" is better than "understand how auth works." Use `Glob` and `Grep` directly for targeted lookups instead of read-everything exploration.

---

## How Forge Studio Addresses Each Pattern

| Waste Pattern | Plugin | Mechanism |
|---|---|---|
| Output verbosity | `caveman` | ~65% output token reduction via compression hooks |
| Duplicate reads | `token-efficiency` | PreToolUse warning on repeated file reads |
| Large tool output | `token-efficiency` | PostToolUse warning when output exceeds threshold |
| Context pressure | `context-engine` | 5-stage progressive warnings (50% → 92%) |
| CLAUDE.md bloat | `context-engine` | `/lean-claude-md`, `/audit-context` skills |
| Subagent overhead | `agents` | `/lean-agents` skill with model and scope guidance |
| Behavioral drift in long sessions | `behavioral-core` | Hook re-injection every message prevents compounding waste from off-track behavior |
| Compaction loss | `context-engine` | Pre/PostCompact hooks preserve and restore critical state |

---

## Verified Sources

- [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs)
- [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks) — includes the output-filtering hook example
- [Prompt caching — Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Claude Code Cache Design — tonylee.im](https://tonylee.im/en/blog/claude-code-cache-design-90-percent-cost-cut) — cache boundary analysis
- [Claude Code Sub-Agents token analysis — DEV Community](https://dev.to/onlineeric/claude-code-sub-agents-burn-out-your-tokens-4cd8)
- GitHub issues: [#42647](https://github.com/anthropics/claude-code/issues/42647) (compaction loops), [#40524](https://github.com/anthropics/claude-code/issues/40524) (cache regression), [#9579](https://github.com/anthropics/claude-code/issues/9579) (auto-compact loop)
