#!/usr/bin/env bash
# code-graph: auto-install tirth8205/code-review-graph (PyPI) and register its
# MCP server for the current repo so Claude Code can query a Tree-sitter graph
# instead of re-reading full files.
#
# Install strategy (first host): pipx if present; otherwise a self-contained
# venv at ~/.local/share/code-review-graph/venv with a symlink into
# ~/.local/bin. PEP 668 (Ubuntu 24.04+) blocks plain `pip install --user`, so
# we do not rely on it.
#
# First session on a new repo: runs `code-review-graph install --platform claude-code`
# in the repo, kicks off `code-review-graph build` in the background.
# Subsequent sessions: fast path, no network, no writes.
#
# Opt-out: export FORGE_CODE_GRAPH_DISABLED=1
#
# Caveats:
# - Installs a Python package (pipx-managed or in a plugin-owned venv).
# - `code-review-graph install --platform claude-code` writes .mcp.json,
#   .claude/, CLAUDE.md, and .gitignore into the project dir. This plugin
#   then rewrites .mcp.json's command from `uvx` to the installed binary.
#   Uninstalling this plugin does NOT remove those files — see docs/code-graph.md.
# - Pinned to --platform claude-code: never configures Cursor/Windsurf/Zed/etc.
# - Always exits 0 so session startup never fails.

set -u

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

SESSION_MARKER="/tmp/forge-code-graph-${CLAUDE_SESSION_ID:-$$}"
[ -f "$SESSION_MARKER" ] && exit 0
touch "$SESSION_MARKER" 2>/dev/null || true

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

export PATH="$HOME/.local/bin:$PATH"

STATE_DIR="$HOME/.local/share/code-review-graph"
VENV_DIR="$STATE_DIR/venv"
PIP_MARKER="$STATE_DIR/.forge-studio-pip-installed"
BIN_LINK="$HOME/.local/bin/code-review-graph"

if ! command -v code-review-graph >/dev/null 2>&1 && [ ! -f "$PIP_MARKER" ]; then
  installed=0

  if command -v pipx >/dev/null 2>&1; then
    if pipx install code-review-graph >/dev/null 2>&1; then
      installed=1
    fi
  fi

  if [ "$installed" -eq 0 ]; then
    mkdir -p "$STATE_DIR" "$HOME/.local/bin" 2>/dev/null || true
    if python3 -m venv "$VENV_DIR" >/dev/null 2>&1 \
       && "$VENV_DIR/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 \
       && "$VENV_DIR/bin/pip" install --quiet code-review-graph >/dev/null 2>&1; then
      ln -sf "$VENV_DIR/bin/code-review-graph" "$BIN_LINK" 2>/dev/null && installed=1
    fi
  fi

  if [ "$installed" -eq 1 ]; then
    touch "$PIP_MARKER" 2>/dev/null || true
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "code-graph: install failed (needs python3 -m venv or pipx). Retry next session or set FORGE_CODE_GRAPH_DISABLED=1 to silence." >&2
    exit 0
  fi
fi

if ! command -v code-review-graph >/dev/null 2>&1; then
  exit 0
fi

REPO_MARKER="$PROJECT_DIR/.code-review-graph/.forge-studio-initialized"
if [ ! -f "$REPO_MARKER" ]; then
  ( cd "$PROJECT_DIR" && code-review-graph install --platform claude-code >/dev/null 2>&1 ) \
    || echo "code-graph: 'install --platform claude-code' failed in $PROJECT_DIR." >&2

  # Upstream writes .mcp.json with `"command": "uvx"`. We did not install uvx;
  # rewrite to invoke the binary we did install (pipx shim or our venv symlink).
  CRG_BIN="$(command -v code-review-graph || true)"
  MCP_FILE="$PROJECT_DIR/.mcp.json"
  if [ -n "$CRG_BIN" ] && [ -f "$MCP_FILE" ]; then
    python3 - "$MCP_FILE" "$CRG_BIN" <<'PY' 2>/dev/null || true
import json, sys
path, binary = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
srv = cfg.get("mcpServers", {}).get("code-review-graph")
if srv:
    srv["command"] = binary
    srv["args"] = ["serve"]
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
PY
  fi

  # Upstream's injected CLAUDE.md block references bare tool names (e.g.
  # `query_graph`), but the actual MCP tool names have a `_tool` suffix.
  # Patch the block in-place so Claude Code calls names that exist.
  CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ]; then
    python3 "${CLAUDE_PLUGIN_ROOT}/hooks/patch-claudemd-tool-names.py" "$CLAUDE_MD" 2>/dev/null || true
  fi

  mkdir -p "$PROJECT_DIR/.code-review-graph" 2>/dev/null || true
  nohup bash -c "cd '$PROJECT_DIR' && code-review-graph build && bash '${CLAUDE_PLUGIN_ROOT}/hooks/sanitize-graph.sh' '$PROJECT_DIR'" >/dev/null 2>&1 &
  disown 2>/dev/null || true

  touch "$REPO_MARKER" 2>/dev/null || true
fi

exit 0
