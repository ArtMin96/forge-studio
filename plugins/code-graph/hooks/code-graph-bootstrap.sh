#!/usr/bin/env bash
set -euo pipefail
# code-graph: auto-install colbymchenry/codegraph and register its MCP server
# for the current repo so Claude Code queries a tree-sitter structural graph
# instead of re-reading full files.
#
# All install work runs detached in the background, so SessionStart never
# blocks: a slow first index on a large repo cannot stall startup. The
# presence of $PROJECT_DIR/.codegraph/ marks "set up" — the bootstrap re-spawns
# each new session only until that directory exists, so a transient failure
# (offline, npm not ready) self-heals on the next session without a permanent
# failure marker.
#
# Setup chain (background):
#   1. Ensure the `codegraph` binary is available. Prefer an existing one on
#      PATH; otherwise `npm install -g @colbymchenry/codegraph`; otherwise run
#      the installer through `npx`. codegraph's own installer places the binary
#      on PATH, so the MCP server (command: codegraph) resolves later.
#   2. `codegraph install --target=claude --location=local --yes` — writes the
#      project MCP config + Claude Code auto-allow permissions and initializes
#      the project (per upstream docs, --location=local inits the project).
#   3. Fallback `codegraph init -i` if .codegraph/ still absent.
#
# The MCP server config is read by Claude Code at session start, so a freshly
# registered server first becomes available on the *next* session — the first
# session primes it.
#
# Opt-out: export FORGE_CODE_GRAPH_DISABLED=1
#
# Caveats:
# - Needs Node.js (npm or npx) to install codegraph. No Node → no install;
#   the healthcheck reports this.
# - `codegraph install --location=local` writes .mcp.json, .claude/ (auto-allow
#   permissions), and an instructions file into the project dir, and creates
#   .codegraph/ (the SQLite index). Uninstalling this plugin does NOT remove
#   those files — see docs/code-graph.md.
# - Pinned to --target=claude: never configures Cursor/Codex/other agents.
# - Always exits 0 so session startup never fails.

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

SESSION_MARKER="/tmp/forge-code-graph-${CLAUDE_SESSION_ID:-$$}"
[ -f "$SESSION_MARKER" ] && exit 0
touch "$SESSION_MARKER" 2>/dev/null || true

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# npm/npx global bins commonly land here; make sure background setup sees them.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# Already set up for this repo — nothing to do.
[ -d "$PROJECT_DIR/.codegraph" ] && exit 0

nohup bash -c '
  set -e
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
  PROJECT_DIR="$1"

  if ! command -v codegraph >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
      npm install -g @colbymchenry/codegraph >/dev/null 2>&1 || true
    fi
  fi

  cd "$PROJECT_DIR" || exit 0

  if command -v codegraph >/dev/null 2>&1; then
    codegraph install --target=claude --location=local --yes >/dev/null 2>&1 || true
    [ -d "$PROJECT_DIR/.codegraph" ] || codegraph init -i >/dev/null 2>&1 || true
  elif command -v npx >/dev/null 2>&1; then
    npx -y @colbymchenry/codegraph install --target=claude --location=local --yes >/dev/null 2>&1 || true
    if [ ! -d "$PROJECT_DIR/.codegraph" ]; then
      if command -v codegraph >/dev/null 2>&1; then
        codegraph init -i >/dev/null 2>&1 || true
      else
        npx -y @colbymchenry/codegraph init -i >/dev/null 2>&1 || true
      fi
    fi
  fi
' _ "$PROJECT_DIR" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
