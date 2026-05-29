#!/usr/bin/env bash
set -euo pipefail
# code-graph: re-index the structural graph after a git operation that moves
# HEAD (commit, merge, rebase, pull, checkout, reset, cherry-pick) — the points
# where the working tree shifts enough to be worth an incremental `codegraph
# sync`. Routine Edit/Write are picked up by the next sync or session build.
# We match PostToolUse:Bash and filter the command here.
#
# Detached execution keeps the hook under ~50ms regardless of graph size.
#
# No-op when:
# - FORGE_CODE_GRAPH_DISABLED=1
# - Project has no .codegraph/ (not initialized)
# - Bash command is not a git HEAD-moving operation
# - codegraph binary is not on PATH

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$PROJECT_DIR/.codegraph" ] || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true
[ -z "$CMD" ] && exit 0

case "$CMD" in
  *"git commit"*|*"git merge"*|*"git rebase"*|*"git pull"*|*"git checkout"*|*"git reset"*|*"git cherry-pick"*)
    ;;
  *)
    exit 0
    ;;
esac

export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
command -v codegraph >/dev/null 2>&1 || exit 0

nohup bash -c "cd '$PROJECT_DIR' && codegraph sync" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
