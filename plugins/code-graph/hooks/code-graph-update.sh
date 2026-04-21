#!/usr/bin/env bash
# code-graph: keep the Tree-sitter graph in sync with edits. Runs after every
# Edit/Write. Detached so the hook adds <50ms of latency to the tool call.
#
# No-op when:
# - FORGE_CODE_GRAPH_DISABLED=1
# - The current project has not been initialized yet (no .code-review-graph/)
# - code-review-graph binary is not on PATH

set -u

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

[ -d "$PROJECT_DIR/.code-review-graph" ] || exit 0

export PATH="$HOME/.local/bin:$PATH"
command -v code-review-graph >/dev/null 2>&1 || exit 0

nohup bash -c "cd '$PROJECT_DIR' && code-review-graph update" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
