#!/usr/bin/env bash
# code-graph: prune CALLS edges whose target has no matching node.
#
# Upstream's tree-sitter extractor records every function-call-shaped token
# it sees, including shell builtins (printf, grep, exit, date, jq, etc.) that
# are not nodes in the graph. Those orphan targets become pivot points for
# get_impact_radius_tool's recursive BFS — every function that calls `printf`
# appears "impacted" by every other function that calls `printf`, across
# unrelated files. We prune them so impact analysis reflects real edges only.
#
# Safe by construction: deletes only rows whose target_qualified does not
# match any qualified_name in the nodes table. Upstream code cannot resolve
# those targets to nodes anyway.
#
# Intended to run right after `code-review-graph build` or `update`.

set -u

PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
DB="$PROJECT_DIR/.code-review-graph/graph.db"

[ -f "$DB" ] || exit 0
command -v sqlite3 >/dev/null 2>&1 || exit 0

sqlite3 "$DB" "DELETE FROM edges WHERE kind='CALLS' AND target_qualified NOT IN (SELECT qualified_name FROM nodes);" 2>/dev/null || true

exit 0
