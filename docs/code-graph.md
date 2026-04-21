# Code Graph

Auto-bundles [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph). Claude Code queries a Tree-sitter structural graph of the current repo through MCP, so it pulls the minimum set of affected files instead of re-reading the codebase on every task.

**Claude Code only.**

---

## What happens when you install

On the first session in a repo:

1. The `code-review-graph` Python package is installed once per host (via `pipx` if present, otherwise in a private venv under `~/.local/share/code-review-graph/`). Binary lands at `~/.local/bin/code-review-graph`.
2. The per-repo MCP server is registered by writing `.mcp.json` in the project root. Claude Code picks it up automatically.
3. An initial graph `build` runs in the background.

On subsequent sessions in the same repo: nothing — everything is already set up.

The graph refreshes after `git commit`, `git merge`, `git rebase`, `git pull`, `git checkout`, `git reset`, or `git cherry-pick`. Uncommitted edits are not reflected until you commit.

---

## Files created in your repo

`code-review-graph install` creates these in the project root on first run:

- `.mcp.json` — the MCP server entry Claude Code reads
- `.claude/settings.json` and `.claude/skills/` — Claude Code config
- `CLAUDE.md` — usage guidance for the model
- `.gitignore` — adds `.code-review-graph/`
- `.code-review-graph/` — the SQLite graph (add to `.gitignore` if not already)

**If you already had `CLAUDE.md`, back it up before the first session** — upstream's installer rewrites it.

---

## Verifying it works

```bash
command -v code-review-graph && code-review-graph --version
test -d .code-review-graph && ls .code-review-graph/

# In a Claude Code session:
/mcp   # expect `code-review-graph` listed and connected
```

If the initial `build` hasn't finished, graph queries return empty. Wait a few seconds on small repos, up to a minute on large monorepos, or run `code-review-graph build` yourself.

---

## Configuration

| Variable | Effect |
|---|---|
| `FORGE_CODE_GRAPH_DISABLED=1` | Plugin is inert. No install, no MCP registration, no updates. |
| `CRG_MAX_IMPACT_NODES` | Caps nodes returned by impact queries (default `500`). |
| `CRG_TOOLS` | Comma-separated whitelist of MCP tools to expose. |
| `CRG_GIT_TIMEOUT` | Seconds before git operations time out (default `30`). |
| `CRG_EMBEDDING_MODEL` | Vector embedding model for semantic search. |

See [upstream README](https://github.com/tirth8205/code-review-graph) for the complete list.

---

## Limitations

- **Graph tracks commits, not edits.** Between commits the graph is stale with respect to the working tree. Commit early and often, or run `code-review-graph build` manually.
- **Background `build` on large monorepos** takes a minute or more. Early queries may return nothing.
- **Offline first session** — no PyPI means nothing installs. Rerun on reconnect.
- **Language coverage is finite.** Tree-sitter grammars cover ~23 languages + Jupyter. Unsupported files don't contribute graph nodes; reads fall back to normal file I/O.
- **First install in a repo rewrites `CLAUDE.md`** and adds files listed above. Know this before enabling the plugin on a repo with a curated `CLAUDE.md`.

---

## Known upstream quirks

Tracked here so you don't chase them as plugin bugs. Filed upstream where relevant.

- **Orphan-target pivots in `get_impact_radius_tool` (worked around).** Upstream's extractor records CALLS edges for every call-shaped token — including shell builtins like `printf`, `grep`, `echo`, `jq`, `date`. These have no matching node, but the recursive BFS treats them as pivots, so every function that calls `printf` appears as impacted by every other function that does. This plugin runs a one-line sanitizer (`plugins/code-graph/hooks/sanitize-graph.sh`) after every `build` and `update` that deletes CALLS edges whose target has no matching node. Without the sanitizer the tool returns heavy false positives on any language with many external/builtin calls (shell, C with libc, etc.).
- **`query_graph_tool` returns one result row per call site.** A function that calls another nine times shows nine identical rows. Cosmetic; costs tokens.
- **Semantic search is keyword-only by default.** `semantic_search_nodes_tool` falls back to FTS until embeddings are populated — see the next section.

---

## Enabling semantic search (optional)

Out of the box `semantic_search_nodes_tool` runs keyword-only — it returns nothing (or very low scores) for queries that don't match file/symbol text. To get vector search, install the extras and embed the graph once.

Pick the install location you already use (pipx shim or this plugin's venv):

```bash
# If installed via pipx
pipx inject code-review-graph sentence-transformers

# Or if installed via this plugin's venv fallback
~/.local/share/code-review-graph/venv/bin/pip install sentence-transformers
```

Then in a Claude Code session, ask the model to call `embed_graph_tool` once per repo. It downloads `all-MiniLM-L6-v2` (~90 MB) on first use, then embeds every node. Re-embedding only touches new/changed nodes.

Override the model with `CRG_EMBEDDING_MODEL=<huggingface-id>` before the session if you want something other than the default.

Skip this if you only use the graph for structural queries (`query_graph_tool`, `get_impact_radius_tool`, `detect_changes_tool`) — they don't need embeddings.

---

## Uninstall

Per repo:

```bash
rm -f .mcp.json
rm -rf .claude .code-review-graph
# Restore your own CLAUDE.md if upstream replaced it
```

Global:

```bash
pipx uninstall code-review-graph 2>/dev/null || true
rm -f ~/.local/bin/code-review-graph
rm -rf ~/.local/share/code-review-graph
/plugin uninstall code-graph@forge-studio
```
