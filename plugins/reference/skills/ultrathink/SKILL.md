---
name: ultrathink
description: Guide on when and how to use Claude Code's thinking modes and effort levels.
when_to_use: When tackling complex problems that need deep reasoning, or to learn which effort level suits the task at hand.
disable-model-invocation: true
model: haiku
---

# Ultrathink: Master Claude's Reasoning Modes

## Effort Levels

Control how hard Claude thinks with `/effort` or the `CLAUDE_CODE_EFFORT_LEVEL` env var:

| Level | When to use | Token cost |
|-------|------------|-----------|
| **low** | Simple lookups, quick questions, high-volume tasks | Minimal |
| **medium** | Standard development, balanced speed/quality | Moderate |
| **high** | Complex reasoning, nuanced analysis, difficult bugs (DEFAULT) | Higher |
| **max** | Absolute hardest problems, multi-step deduction | Highest |

## Ultrathink Keyword

Include "ultrathink" anywhere in your prompt for a one-off max-effort response. No need to change global settings.

Example: "ultrathink: design the auth system for this app considering OAuth, JWT, and session-based approaches"

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

## Adaptive Thinking (Opus 4.6 / Sonnet 4.6)
Claude dynamically decides how much to think based on query complexity. Higher effort + harder query = more thinking. Easy queries get direct responses even at high effort — no token waste.

## Monitor Tool

Use the Monitor tool to stream events from background scripts in real time. Useful for watching long-running subagent output without polling.

## Toggle
- Shortcut: Alt+T (toggle thinking visibility)
- Command: `/effort` to change level
- Focus View: Ctrl+O (condensed view — shows prompts, tool summaries, responses only)
