---
name: lean-agents
description: Reduce subagent token overhead from ~50K to ~5K per turn. Covers 4-layer isolation, CLAUDE_CODE_SIMPLE mode, and agent dispatch guidelines.
disable-model-invocation: true
---

# /lean-agents — Subagent Token Optimization

## The Problem

Each subagent loads ~50K tokens before doing any work:

| Source | Tokens |
|---|---|
| CLAUDE.md | ~10-18K |
| MCP tools | ~9K |
| Agent definitions | ~3.3K |
| Skills | ~2.6K |
| System prompt | ~3.5K |

Key insight: when a parent reads a file, the child gets zero benefit — it re-reads everything in its own context. Every unnecessary token the child loads is wasted.

Source: DEV Community token trace analysis, Anthropic subagent docs.

## The 4-Layer Isolation Technique

### Layer 1: Tool restriction
Use `allowed-tools` in agent definitions to limit which tools load. Fewer tools = fewer tool schemas in context. A grep-only agent doesn't need `Write`, `Edit`, or `Bash`.

### Layer 2: Prompt minimization
Write short, specific agent prompts. Include file paths, line numbers, and exact instructions. Don't repeat background the agent doesn't need. Project history belongs in the parent, not the child.

### Layer 3: Result compression
Tell agents explicitly: "report in under 200 words" or "return only file paths and line numbers." Verbose results waste the parent's context window too.

### Layer 4: CLAUDE_CODE_SIMPLE=1
For mechanical subagents (bulk grep, file listing, simple reads), this env var reduces the system prompt from ~60K to ~50 tokens. Trade-off: loses all behavioral steering — no CLAUDE.md, no hooks, no skills.

## When to Use Each Level

| Subagent Task | Isolation Level | Expected Overhead |
|---|---|---|
| Code exploration / research | Tool restriction + prompt minimization | ~15-20K |
| Batch file operations | Tool restriction + result compression | ~10-15K |
| Simple grep/read tasks | CLAUDE_CODE_SIMPLE=1 | ~5K |
| Quality review / complex analysis | Full context (no isolation) | ~50K |

## Guidelines

- Prefer Glob/Grep directly over spawning explore agents for simple lookups
- Pass file content in the prompt when < 50 lines — avoids the agent re-reading it
- Ask agents for summaries, not raw data
- Use `run_in_background` for research agents — don't block on exploration
- Fan-out sweet spot: 3-5 parallel agents. More creates review overhead.
