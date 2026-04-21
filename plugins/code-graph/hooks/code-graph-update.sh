#!/usr/bin/env bash
# code-graph: re-index the Tree-sitter graph after a git operation that moves
# HEAD. Upstream `code-review-graph update` diffs the working tree against
# HEAD~1, so uncommitted Edit/Write have nothing to pick up — only commits,
# merges, rebases, pulls, checkouts, resets, and cherry-picks do. We match
# PostToolUse:Bash and filter the command here.
#
# Detached execution keeps the hook under ~50ms regardless of graph size.
#
# No-op when:
# - FORGE_CODE_GRAPH_DISABLED=1
# - Project has no .code-review-graph/ (not initialized)
# - Bash command is not a git HEAD-moving operation
# - code-review-graph binary is not on PATH

set -u

[ "${FORGE_CODE_GRAPH_DISABLED:-0}" = "1" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$PROJECT_DIR/.code-review-graph" ] || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

case "$CMD" in
  *"git commit"*|*"git merge"*|*"git rebase"*|*"git pull"*|*"git checkout"*|*"git reset"*|*"git cherry-pick"*)
    ;;
  *)
    exit 0
    ;;
esac

export PATH="$HOME/.local/bin:$PATH"
command -v code-review-graph >/dev/null 2>&1 || exit 0

nohup bash -c "cd '$PROJECT_DIR' && code-review-graph update" >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
