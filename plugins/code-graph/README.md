# code-graph

Auto-installs [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph). Claude Code queries a Tree-sitter structural graph through MCP instead of re-reading every file.

## What it does

File scanning is expensive. A graph isn't. This plugin builds and maintains a structural graph of your repo (functions, callers, callees, imports, tests) so Claude can answer "what calls X" or "what's the impact of changing Y" without reading every file.

The graph auto-updates after Bash commands that may have changed code (git operations, build steps, etc.).

## When to use

- The project has 50+ files
- You're planning refactors and want **impact radius** before editing
- Code review needs **callers/dependents** — graph beats grep
- Sessions are spending a lot of tokens on Read/Glob

Single-file scripts and tiny repos won't benefit.

## How it works

```text
 SessionStart        ──► bootstrap (idempotent: installs the MCP server + builds graph
                                     on first run, no-ops on subsequent sessions)
 SessionStart        ──► healthcheck (verifies binary + MCP server, warns on drift)
 PreToolUse  (Edit|Write|Bash) ──► preflight-impact (advisory for broad-blast file edits)
 PostToolUse (Bash)  ──► incremental graph update after code-changing commands
```

Once installed, use the MCP tools: `query_graph_tool`, `detect_changes_tool`, `get_impact_radius_tool`, `semantic_search_nodes_tool`, etc. The CLAUDE.md template included in this marketplace already documents the workflow.

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `SessionStart` | code-graph-bootstrap | First-time install + graph build (idempotent) |
| `SessionStart` | code-graph-healthcheck | Warn if binary or MCP server is missing |
| `PreToolUse` (`Edit\|Write\|Bash`) | preflight-impact | Project-agnostic advisory when about to touch broad-blast files (CI configs, container/orchestration manifests, build files, dependency manifests, lockfiles, top-level tooling configs, schemas/migrations, env files, repo-wide docs); points at `mcp__code-review-graph__get_impact_radius_tool` for callers/dependents — disable: `FORGE_PREFLIGHT_IMPACT=0` |
| `PostToolUse` (`Bash`) | code-graph-update | Refresh graph after code-changing Bash commands |

## Configuration

| Variable | Effect |
|---|---|
| `FORGE_CODE_GRAPH_DISABLED=1` | Skip install and bootstrap entirely |
| `FORGE_PREFLIGHT_IMPACT=0` | Disable the PreToolUse broad-blast advisory |

Claude Code only — Codex CLI and other harnesses do not consume MCP servers in the same way.

## Disable

`/plugin disable code-graph@forge-studio`. The MCP server remains installed; remove it from your global MCP config to fully purge.
