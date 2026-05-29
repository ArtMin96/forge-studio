# code-graph

Auto-installs [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph). Claude Code queries a tree-sitter structural graph through MCP instead of re-reading every file.

## What it does

File scanning is expensive. A graph isn't. This plugin builds and maintains a structural graph of your repo (functions, callers, callees, imports, references) so Claude can answer "what calls X" or "what's the impact of changing Y" without reading every file.

The graph auto-updates after Bash commands that move HEAD (git commit, merge, rebase, pull, checkout, reset, cherry-pick).

## When to use

- The project has 50+ files
- You're planning refactors and want **impact radius** before editing
- Code review needs **callers/dependents** — graph beats grep
- Sessions are spending a lot of tokens on Read/Glob

Single-file scripts and tiny repos won't benefit.

## How it works

```text
 SessionStart        ──► bootstrap (idempotent: installs codegraph + registers
                                     the MCP server + builds the graph on first
                                     run in the background, no-ops once .codegraph/ exists)
 SessionStart        ──► healthcheck (verifies the binary, warns on drift)
 PostToolUse (Bash)  ──► incremental `codegraph sync` after HEAD-moving git commands
```

All install work runs detached, so SessionStart never blocks. The MCP server is read at session start, so it first comes online on the session after the one that installs it.

Once installed, use the MCP tools: `codegraph_search`, `codegraph_context`, `codegraph_callers`, `codegraph_callees`, `codegraph_impact`, `codegraph_trace`, `codegraph_node`, `codegraph_explore`, `codegraph_files`, `codegraph_status`. The CLAUDE.md template included in this marketplace already documents the workflow.

## Skills

| Skill | Purpose |
|---|---|
| `/impact-trace <symbol> [days]` | Static × execution dual-view (arXiv:2605.18747 §4.4). Joins `codegraph_callers` with recent execution traces. Emits three disjoint sets — intersection (real blast radius), static-only (callable but dormant), runtime-only (likely dynamic dispatch or graph drift). |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `SessionStart` | code-graph-bootstrap | First-time install + graph build, in the background (idempotent) |
| `SessionStart` | code-graph-healthcheck | Warn if the binary or Node toolchain is missing |
| `PostToolUse` (`Bash`) | code-graph-update | `codegraph sync` after HEAD-moving git commands |

## Configuration

| Variable | Effect |
|---|---|
| `FORGE_CODE_GRAPH_DISABLED=1` | Skip install and bootstrap entirely |

codegraph itself is zero-config: it respects `.gitignore` and skips dependency/build dirs and files over 1 MB. Claude Code only — Codex CLI and other harnesses do not consume MCP servers in the same way.

## Disable

`/plugin disable code-graph@forge-studio`. The MCP server remains installed; run `codegraph uninstall` to remove it from your agent configs (project indexes are preserved).
