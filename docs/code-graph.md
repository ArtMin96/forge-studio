# Code Graph

Auto-bundles [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph). Claude Code queries a tree-sitter structural graph of the current repo through MCP, so it pulls the minimum set of affected files instead of re-reading the codebase on every task.

**Claude Code only.**

---

## What happens when you install

On the first session in a repo, the bootstrap hook runs the whole setup **in the background** so session startup never blocks:

1. The `codegraph` CLI is installed if it isn't already on `PATH` — via `npm install -g @colbymchenry/codegraph`, falling back to `npx`. codegraph's own installer places the `codegraph` binary on `PATH` so the MCP server can launch later.
2. `codegraph install --target=claude --location=local --yes` registers the per-repo MCP server, configures Claude Code auto-allow permissions, and initializes the project.
3. The initial graph index builds (`.codegraph/`), in the background.

Because Claude Code reads MCP server config at session start, a freshly registered server first becomes available on the **next** session — the first session primes it. On subsequent sessions in the same repo nothing runs: the presence of `.codegraph/` short-circuits the bootstrap.

The graph refreshes with an incremental `codegraph sync` after `git commit`, `git merge`, `git rebase`, `git pull`, `git checkout`, `git reset`, or `git cherry-pick`. Routine edits are picked up by the next sync.

A second SessionStart hook (`code-graph-healthcheck.sh`) runs immediately after the bootstrap. If `codegraph` is on `PATH` and a `.codegraph/` index exists, it confirms the index with `codegraph status`. If the binary is still absent it distinguishes two cases: Node.js (npm or npx) is present — setup is just running in the background, so it prints an informational note; or Node is missing entirely — it prints a remediation block, since nothing can install without it. Exit code stays 0 either way, so a missing integration cannot kill session startup but can no longer fail silently. Set `FORGE_CODE_GRAPH_DISABLED=1` to suppress both bootstrap and healthcheck.

---

## Files created in your repo

`codegraph install --target=claude --location=local` writes, in the project root on first run:

- the MCP server config Claude Code reads (so the `codegraph` server is registered for this repo)
- Claude Code auto-allow permissions under `.claude/` (so the MCP tools don't prompt)
- an instructions file describing the tools to the model
- `.codegraph/` — the SQLite index (`codegraph.db`); add it to `.gitignore` if it isn't already

Uninstalling the plugin does not remove these. Use `codegraph uninstall` and the per-repo cleanup below.

---

## Verifying it works

```bash
command -v codegraph
test -d .codegraph && codegraph status   # node/edge/file counts + backend

# In a Claude Code session:
/mcp   # expect `codegraph` listed and connected
```

If the initial index hasn't finished, graph queries return empty. Wait a few seconds on small repos, up to a minute on large monorepos, or run `codegraph index` yourself.

---

## Configuration

codegraph is zero-config — there is no config file to write or keep in sync.

| Variable | Effect |
|---|---|
| `FORGE_CODE_GRAPH_DISABLED=1` | Plugin is inert. No install, no MCP registration, no updates. |

Indexing scope is controlled by `.gitignore`. codegraph skips dependency/build directories (`node_modules`, `vendor`, `dist`, `build`, `target`, `.venv`, `Pods`, `.next`), anything listed in `.gitignore`, and files over 1 MB. To re-include an excluded directory, add a negation such as `!vendor/` to `.gitignore`. Nothing leaves your machine — the index is local SQLite.

---

## MCP tools

Once the server is connected, codegraph exposes these tools:

| Tool | Purpose |
|---|---|
| `codegraph_search` | Find symbols by name across the codebase |
| `codegraph_context` | Build relevant context for a task — composes search + node + callers + callees |
| `codegraph_trace` | Trace the call path between two symbols |
| `codegraph_callers` | Find what calls a function |
| `codegraph_callees` | Find what a function calls |
| `codegraph_impact` | Analyze what code is affected by changing a symbol |
| `codegraph_node` | Get details about a symbol (optionally with source) |
| `codegraph_explore` | Source for several related symbols grouped by file, plus a relationship map |
| `codegraph_files` | Get the indexed file structure |
| `codegraph_status` | Check index health and statistics |

The `/impact-trace` skill joins `codegraph_callers` with execution traces — see [skills/code-graph/impact-trace.md](skills/code-graph/impact-trace.md).

---

## Limitations

- **Node.js required.** codegraph installs from npm; without `npm` or `npx` on `PATH` the bootstrap cannot install it and the healthcheck reports so.
- **First-session lag.** Setup runs in the background, so the MCP server first comes online on the session after install. Early graph queries may return nothing while the index builds.
- **Sync cadence.** The graph refreshes on HEAD-moving git commands. Between those it can be stale with respect to uncommitted edits; run `codegraph sync` manually if you need it current.
- **Language coverage is finite.** tree-sitter grammars cover a fixed set of languages. Unsupported files don't contribute graph nodes; reads fall back to normal file I/O.

---

## Uninstall

Per repo:

```bash
rm -f .mcp.json
rm -rf .codegraph
# remove the codegraph instructions block / .claude auto-allow entries if you added them
```

Global:

```bash
codegraph uninstall            # removes codegraph config from configured agents, keeps indexes
npm uninstall -g @colbymchenry/codegraph 2>/dev/null || true
/plugin uninstall code-graph@forge-studio
```
