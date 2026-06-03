---
name: ultrathink
description: Use when the user asks about "thinking modes", "effort levels", "how hard should Claude think", or wants to pick between low/medium/high/xhigh/max for a task — explains the cost/quality tradeoff per level and recommends one based on the work shape.
when_to_use: Reach for this when picking an `effort:` value for a new skill or `/effort` for the current turn, or when teaching the reasoning modes. Do NOT use for changing the effort level — use the `/effort` command instead; ultrathink is the explanation, not the switch.
disable-model-invocation: true
model: haiku
allowed-tools: []
logical: explanation of effort levels emitted with cost/quality tradeoff per level
---

# Ultrathink: Master Claude's Reasoning Modes

## Effort Levels

Control how hard Claude thinks with `/effort` or the `CLAUDE_CODE_EFFORT_LEVEL` env var:

| Level | When to use | Token cost |
|-------|------------|-----------|
| **low** | Simple lookups, quick questions, high-volume tasks | Minimal |
| **medium** | Standard development, balanced speed/quality | Moderate |
| **high** | Complex reasoning, nuanced analysis, difficult bugs (default) | Higher |
| **xhigh** | Hardest tasks needing deeper reasoning; persists in settings | High |
| **max** | Deepest reasoning, session-only (set per-turn or via env) | Highest |

## Ultrathink Keyword

Include "ultrathink" anywhere in your prompt to request deeper reasoning on that turn. Claude Code recognizes the keyword and adds an in-context instruction to think harder — your session effort level is unchanged. No need to change global settings.

Example: "ultrathink: design the auth system for this app considering OAuth, JWT, and session-based approaches"

## Ultracode Keyword (a different mechanism)

`ultracode` is a separate keyword. `ultrathink` adds an in-context "think harder" instruction for one turn; `ultracode` (or `/effort ultracode`) tells Claude Code to plan a native dynamic workflow — a background script that orchestrates many subagents with verification built in — for the task. It pairs `xhigh` effort with automatic workflow orchestration, lasts the session, and uses more tokens per task. Reach for `ultrathink` to reason harder in place; reach for `ultracode` to fan a large task out to a verified multi-agent workflow. It appears in the `/effort` menu only on Claude Code builds that support dynamic workflows — if you don't see it there, the feature isn't available.

## When Deep Thinking Helps
- Complex architectural decisions
- Multi-step debugging with non-obvious root causes
- Code that has security implications
- Algorithm design and optimization
- Evaluating trade-offs between approaches

## When Deep Thinking Wastes Tokens
- Simple file reads or searches
- Straightforward bug fixes with clear cause
- Formatting or renaming
- Standard CRUD operations

## Adaptive Thinking (current Opus and Sonnet)
Claude dynamically decides how much to think based on query complexity. Higher effort + harder query = more thinking. Easy queries get direct responses even at high effort — no token waste.

## Monitor Tool

Use the Monitor tool to stream events from background scripts in real time. Useful for watching long-running subagent output without polling.

## Toggle
- Shortcut: Alt+T (toggle thinking visibility)
- Command: `/effort` to change level
- Focus View: Ctrl+O (condensed view — shows prompts, tool summaries, responses only)
