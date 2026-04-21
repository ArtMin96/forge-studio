# Code Graph — Auto-Bundled Tree-sitter Context

Wraps [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph) as a forge-studio plugin. Installs the `code-review-graph` Python package on first session, registers its MCP server with Claude Code for the current repo, runs an initial `build`, and keeps the graph fresh on every Edit/Write.

The assistant then queries blast-radius context through MCP (measured 200–440 tokens per response on Forge Studio's own `plugins/` tree, ~55–120× smaller than reading the affected files raw) instead of re-reading full files on every task.

**Claude Code only.** Every upstream install call is pinned to `--platform claude-code` — this plugin never touches Cursor, Windsurf, Zed, Continue, or Codex configs even when the binary detects them.

---

## Why this plugin exists

Forge Studio's other context-management plugins (`context-engine`, `token-efficiency`) reduce what gets re-read by *warning* and *tracking*. `code-graph` reduces it by *substitution* — the model asks the MCP server for the minimum set of files affected by a change and skips the rest.

| Approach | Where it acts | Plugin |
|---|---|---|
| Warn on large files / duplicate reads | PostToolUse advisory | `context-engine`, `token-efficiency` |
| Compress shell output at source | Bash wrapper | `rtk-optimizer` |
| Replace "read the whole repo" with "query the graph" | MCP server | **`code-graph`** |

Without this plugin the user would: (a) `pipx install code-review-graph`, (b) run `code-review-graph install --platform claude-code` in every repo, (c) run `code-review-graph build`, (d) remember to re-build when the repo changes significantly. This plugin collapses all of that to `/plugin install code-graph@forge-studio`.

---

## What gets installed, where

| Artifact | Path | Owner | Removed by plugin uninstall? |
|---|---|---|---|
| `code-review-graph` binary | `~/.local/bin/code-review-graph` (symlink or pipx shim) | pipx or this plugin | No |
| Venv (fallback install path) | `~/.local/share/code-review-graph/venv/` | this plugin | No |
| MCP server entry | `<repo>/.mcp.json` → `mcpServers.code-review-graph` | `code-review-graph install --platform claude-code`, then patched to use the installed binary instead of `uvx` | Yes if you delete `.mcp.json` |
| Per-project instructions | `<repo>/CLAUDE.md` (created if absent, **existing file overwritten by upstream**) | `code-review-graph install` | No — restore your own content manually |
| Per-project Claude Code config | `<repo>/.claude/settings.json` + `<repo>/.claude/skills/` | `code-review-graph install` | No |
| `.gitignore` entry | `<repo>/.gitignore` (created if absent) | `code-review-graph install` | No |
| SQLite graph + metadata | `<repo>/.code-review-graph/` | `code-review-graph build/update` | No — delete the directory to force a rebuild |
| Pip install marker | `~/.local/share/code-review-graph/.forge-studio-pip-installed` | this plugin | No |
| Per-repo init marker | `<repo>/.code-review-graph/.forge-studio-initialized` | this plugin | Yes — deleted when the repo's `.code-review-graph/` is removed |

**About the upstream `CLAUDE.md` write.** On first `install --platform claude-code` in a repo, upstream appends/replaces the repo's `CLAUDE.md` with a preamble instructing the model to prefer MCP graph queries over `Grep`/`Glob`/`Read`. If the repo already has a `CLAUDE.md` with your own content, back it up before the first session — see [Known limitations](#known-limitations).

**About the `.mcp.json` rewrite.** Upstream writes `"command": "uvx"`, which assumes `astral-sh/uv` is installed. This plugin rewrites that entry to the absolute path of the binary it just installed (pipx shim or venv), so Claude Code can start the server without requiring `uvx`.

The asymmetry still matters: **uninstalling `code-graph@forge-studio` does not undo the pip install, the venv, the `.mcp.json`, the `.claude/` directory, or the `CLAUDE.md` changes.** The plugin is a convenience installer — it does not own most of the installed artifacts. Use the uninstall steps below to reverse them.

---

## Bootstrap flow

`plugins/code-graph/hooks/code-graph-bootstrap.sh` runs on every `SessionStart` with a 90 s timeout. Logic:

1. `FORGE_CODE_GRAPH_DISABLED=1` → exit 0.
2. Per-session marker at `/tmp/forge-code-graph-${CLAUDE_SESSION_ID}` → exit 0 if already touched.
3. Resolve project dir: `${CLAUDE_PROJECT_DIR:-$(pwd)}`.
4. Global pip marker at `~/.local/share/code-review-graph/.forge-studio-pip-installed`. If missing and the binary is not on PATH:
   - Try `pipx install code-review-graph` (preferred when pipx is present; PEP 668 safe, isolates the binary).
   - Fallback: create a private venv at `~/.local/share/code-review-graph/venv/`, `pip install code-review-graph` into it, then symlink `~/.local/bin/code-review-graph` → venv binary. Chosen because Ubuntu 24.04+ / PEP 668 blocks plain `pip install --user`.
   - Both failure modes log one line to stderr and exit 0 — the session never breaks.
5. Per-repo marker at `<repo>/.code-review-graph/.forge-studio-initialized`. If missing:
   - `code-review-graph install --platform claude-code` in the repo (writes `.mcp.json`, `.claude/settings.json`, `.claude/skills/`, `CLAUDE.md`, `.gitignore`).
   - Rewrite `.mcp.json`'s `mcpServers.code-review-graph.command` from `uvx` to the absolute path of the installed binary so Claude Code can start the server without `uvx`.
   - Patch `CLAUDE.md` via `plugins/code-graph/hooks/patch-claudemd-tool-names.py`: upstream references bare tool names (`query_graph`, `detect_changes`, …) but the actual MCP tools are suffixed (`query_graph_tool`, …). The script appends `_tool` to any backticked bare name it knows about. `refactor_tool` (already suffixed) and unbacktick'd pattern strings like `tests_for` are left alone.
   - Launch `code-review-graph build` with `nohup … & disown` — initial parse doesn't block session start on large monorepos.
   - Touch the marker so subsequent sessions take the fast path.

Every exit is `0`. A failed install degrades to "graph not active" rather than "session broken."

---

## Incremental update flow

`plugins/code-graph/hooks/code-graph-update.sh` runs on `PostToolUse` with matcher `Bash`, 5 s timeout. It only triggers `code-review-graph update` when the Bash command moves HEAD — upstream `update` diffs the working tree against `HEAD~1`, so uncommitted `Edit`/`Write` edits have nothing to pick up.

Logic:

1. `FORGE_CODE_GRAPH_DISABLED=1` → exit 0.
2. No `<repo>/.code-review-graph/` → exit 0. Protects against stray commands outside the project root.
3. Parse `tool_input.command` from stdin JSON. If it is not one of `git commit`, `git merge`, `git rebase`, `git pull`, `git checkout`, `git reset`, `git cherry-pick` → exit 0.
4. No `code-review-graph` binary on PATH → exit 0.
5. `nohup code-review-graph update … & disown` — fire-and-forget. The hook returns in <50 ms regardless of graph size.

Upstream claims a 2,900-file project re-indexes in under 2 s; detached execution means the hook itself is effectively free.

**Consequence.** Between two commits, the graph is stale with respect to the working tree. Claude Code will see yesterday's structure until you commit. If that matters for a session, commit early and often, or re-run `code-review-graph build` manually.

---

## Verifying it works

After a fresh `/plugin install code-graph@forge-studio` and a new session in a real repo:

```bash
# Binary installed
command -v code-review-graph && code-review-graph --version

# Per-repo graph exists
test -d .code-review-graph && ls .code-review-graph/

# MCP server registered for Claude Code (per-repo config)
python3 -c "import json; \
  print(json.load(open('.mcp.json')).get('mcpServers', {}).get('code-review-graph'))"

# Inside a Claude Code session
/mcp                 # should list `code-review-graph` as connected
```

The initial `build` runs in the background — give it a few seconds on small repos, up to a minute on large monorepos, before expecting graph queries to return results.

---

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `FORGE_CODE_GRAPH_DISABLED` | unset | Set to `1` to make bootstrap + update exit immediately. Won't uninstall anything already in place. |
| `CRG_MAX_IMPACT_NODES` | `500` (upstream) | Passed through to the MCP server. Caps nodes returned by impact queries. |
| `CRG_TOOLS` | all | Comma-separated whitelist of MCP tools to expose. |
| `CRG_GIT_TIMEOUT` | `30` | Seconds before git operations time out during `build`/`update`. |
| `CRG_EMBEDDING_MODEL` | upstream default | Vector embedding model for semantic search tools. |

See [upstream README](https://github.com/tirth8205/code-review-graph) for the complete env var list.

---

## Known limitations

- **Supply chain.** First session runs `pipx install code-review-graph` or (fallback) creates a venv and `pip install`s into it from PyPI. Installing this plugin is opting into that. Set `FORGE_CODE_GRAPH_DISABLED=1` before the first session if you want to audit the package first.
- **Upstream rewrites your `CLAUDE.md`.** `code-review-graph install --platform claude-code` inserts a preamble instructing the model to prefer its MCP tools over `Grep`/`Glob`/`Read`. If your repo already had a curated `CLAUDE.md`, save a copy before installing. This plugin does not mediate that write.
- **Upstream creates `.mcp.json`, `.claude/settings.json`, `.claude/skills/`, `.gitignore`** in the project root. Check them into git (or add them to your top-level ignore) deliberately.
- **Background `build` on huge monorepos.** The first assistant query immediately after bootstrap may find an empty graph. Wait a few seconds or run `code-review-graph build` yourself and watch it finish.
- **Offline first session.** No pipx/venv/PyPI → one stderr line, exit 0. Rerun on reconnect or install manually.
- **Update hook only fires after git HEAD moves.** Upstream `code-review-graph update` compares against `HEAD~1`; uncommitted edits never reach the graph. The hook filters on `git commit|merge|rebase|pull|checkout|reset|cherry-pick` to avoid wasted invocations.
- **Upstream CLAUDE.md uses stale tool names.** Upstream writes references to `query_graph`, `detect_changes`, etc.; the running MCP server exposes them as `query_graph_tool`, `detect_changes_tool`, etc. The plugin's bootstrap runs a patcher (`patch-claudemd-tool-names.py`) to append `_tool` to backticked bare names inside the upstream-managed block. If upstream renames tools in a future release, the patcher becomes a no-op and the CLAUDE.md block will need to be resynced.
- **Upstream `serverInfo.version` mismatch.** `code-review-graph --version` reports `2.3.2` but the MCP `initialize` response advertises `2.14.7`. Harmless upstream inconsistency.
- **Language coverage is finite.** Tree-sitter grammars cover 23 languages + Jupyter (see upstream README). Unsupported files contribute no nodes; the graph falls back to whole-file reads for those paths.

---

## Uninstall

Per-repo cleanup (run in each repo where you used the plugin):

```bash
rm -f .mcp.json .gitignore        # only if upstream created them from scratch
rm -rf .claude .code-review-graph # remove upstream's Claude Code config + graph
# Review CLAUDE.md: restore your own content if upstream wrote its preamble
```

Global cleanup:

```bash
# Remove the binary + venv
pipx uninstall code-review-graph 2>/dev/null || true
rm -f ~/.local/bin/code-review-graph
rm -rf ~/.local/share/code-review-graph

# Remove the plugin itself
/plugin uninstall code-graph@forge-studio
```

Everything upstream creates lives in the repo or in `~/.local/share/code-review-graph`; there is nothing to remove from `~/.claude.json` (the plugin uses per-repo `.mcp.json`, not the user-level config).
