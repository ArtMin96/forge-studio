#!/usr/bin/env bash
# code-graph-healthcheck.sh — verify the bootstrap left the integration usable.
# Runs after code-graph-bootstrap.sh in the same SessionStart group. Always
# exits 0 so a failure does not kill session startup, but emits guidance to
# stderr so a broken integration cannot stay silent.
#
# First session: bootstrap installs codegraph in the background, so the binary
# and .codegraph/ index may not exist yet during this check. That is expected,
# not a failure — the server comes online next session. The only real blocker
# worth a warning is a missing Node.js toolchain (no npm/npx), without which
# nothing can install.
#
# Opt-out: export FORGE_CODE_GRAPH_DISABLED=1

set -euo pipefail

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if command -v codegraph >/dev/null 2>&1; then
  if [ -d "$PROJECT_DIR/.codegraph" ]; then
    if ! ( cd "$PROJECT_DIR" && codegraph status >/dev/null 2>&1 ); then
      {
        echo "code-graph: 'codegraph status' failed for $PROJECT_DIR — the index may be corrupt or mid-build."
        echo "  Rebuild: cd \"$PROJECT_DIR\" && codegraph index"
        echo "  Silence: export FORGE_CODE_GRAPH_DISABLED=1"
      } >&2
    fi
  fi
  exit 0
fi

# codegraph not on PATH.
if command -v npm >/dev/null 2>&1 || command -v npx >/dev/null 2>&1; then
  {
    echo "code-graph: codegraph is installing in the background. The MCP server registers and the"
    echo "  graph builds on the first session, then becomes available on the next one."
    echo "  Still missing after a couple of sessions? Run it yourself:"
    echo "    cd \"$PROJECT_DIR\" && npx -y @colbymchenry/codegraph install --target=claude --location=local --yes"
    echo "  Silence: export FORGE_CODE_GRAPH_DISABLED=1"
  } >&2
else
  {
    echo "code-graph: integration check FAILED — codegraph cannot auto-install."
    echo "  - Node.js is required (npm or npx), and neither is on PATH."
    echo "  Remediation:"
    echo "    Install Node.js (https://nodejs.org), then restart Claude Code, or run:"
    echo "    cd \"$PROJECT_DIR\" && npx -y @colbymchenry/codegraph install --target=claude --location=local --yes"
    echo "  To silence: export FORGE_CODE_GRAPH_DISABLED=1"
  } >&2
fi

exit 0
