#!/usr/bin/env bash
# code-graph-healthcheck.sh — verify the bootstrap left the integration usable.
# Runs after code-graph-bootstrap.sh in the same SessionStart group. Always
# exits 0 so a failure does not kill session startup, but emits a multi-line
# warning to stderr so a broken integration cannot stay silent.
#
# Opt-out: export FORGE_CODE_GRAPH_DISABLED=1

set -euo pipefail

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

export PATH="$HOME/.local/bin:$PATH"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
problems=()

if ! command -v code-review-graph >/dev/null 2>&1; then
  problems+=("- 'code-review-graph' is not on PATH")
fi

if [ ${#problems[@]} -eq 0 ]; then
  if ! code-review-graph --version >/dev/null 2>&1; then
    problems+=("- 'code-review-graph --version' did not return 0 (binary present but unhealthy)")
  fi
fi

if [ ! -f "$PROJECT_DIR/.mcp.json" ]; then
  problems+=("- $PROJECT_DIR/.mcp.json is missing (no MCP entry registered for this project)")
elif ! grep -q "code-review-graph\|code_review_graph" "$PROJECT_DIR/.mcp.json" 2>/dev/null; then
  problems+=("- $PROJECT_DIR/.mcp.json has no entry referencing code-review-graph")
fi

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "code-graph: integration check FAILED — the MCP server will not be available this session:"
    for p in "${problems[@]}"; do echo "  $p"; done
    echo "  Remediation:"
    echo "    pipx install code-review-graph     # or: python3 -m venv ~/.local/share/code-review-graph/venv && that-venv/bin/pip install code-review-graph"
    echo "    cd \"$PROJECT_DIR\" && code-review-graph install --platform claude-code"
    echo "  To silence: export FORGE_CODE_GRAPH_DISABLED=1"
  } >&2
fi

exit 0
