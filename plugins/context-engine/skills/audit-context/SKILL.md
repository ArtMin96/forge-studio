---
name: audit-context
description: Use when sessions feel slow, CLAUDE.md has grown unwieldy, MCP server overhead is unclear, or you want to audit token overhead before a large task — measures CLAUDE.md size, system reminder weight, MCP server token cost, and per-skill description length, then ranks the top offenders.
when_to_use: Reach for this near the start of a long-running session, after the user complains about latency, or before a planned heavy task where every token matters. Do NOT use to track per-tool-call cost in real time — that's `/checkpoint` (drift detection) and `/token-audit` (after-the-fact session waste).
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Audit Context: Find and Fix Token Waste

Context tokens are currency. Everything loaded competes with your actual work. This audit identifies waste.

## Step 1: Measure CLAUDE.md Weight

Read all CLAUDE.md files that would load for this project:
- `~/.claude/CLAUDE.md` (global)
- `./CLAUDE.md` (project root)
- Any parent/child directory CLAUDE.md files

For each: count lines, estimate tokens (~1.3 tokens per word), flag if over 100 lines.

**Ceiling:** ~150-200 instructions max before compliance drops. Claude's system prompt uses ~50. That leaves 100-150 for you.

## Step 2: Check Installed Plugins

Run: `cat ~/.claude/plugins/installed_plugins.json` (or check settings.json enabledPlugins)

For each enabled plugin: is it relevant to this project? If not, it's loading skill descriptions into context for nothing.

## Step 3: Check MCP Servers

Look at `.mcp.json` files and settings for active MCP servers. Each loads tool names at minimum.

**Rule of thumb:** Under 10 MCP servers, under 30 tools total. More = context bloat.

## Step 4: Check Skills

List all skills that auto-load (those without `disable-model-invocation: true`). Each one costs description tokens every session.

## Output

```
CONTEXT AUDIT
=============
CLAUDE.md:    [X lines / ~Y tokens] — [OK / OVER BUDGET]
Plugins:      [X enabled] — [List any irrelevant to current project]
MCP Servers:  [X active / ~Y tools] — [OK / TOO MANY]
Auto-Skills:  [X loading descriptions] — [List any that should be disable-model-invocation]

TOTAL ESTIMATED OVERHEAD: ~[N] tokens per session
RECOMMENDATIONS:
- [Actionable item 1]
- [Actionable item 2]
```

## Key Insights
- A focused 30-line CLAUDE.md outperforms a 200-line one
- Skills with `disable-model-invocation: true` cost ZERO until invoked
- MCP tool schemas load on-demand by default (good — keep it that way)
- Plugins you don't use in this project should be disabled per-project
