#!/usr/bin/env bash
# Force-push a single branch using strategy A (bare lease + --force-if-includes).
#
# Usage: safe-push.sh <branch>
#
# Strategy A: git push --force-with-lease --force-if-includes origin <branch>
#
# --force-with-lease (bare form) guards against clobbering a remote ref that
# was updated since the last fetch; --force-if-includes requires the remote-
# tracking ref to appear in the local reflog, closing the stale-local-ref hole.
# Together these make the push safe when the local remote-tracking ref is fresh
# (the common case after a restack).
#
# Refuses to run when HEAD is detached; a push from a detached HEAD targets the
# wrong ref and the push guard would block it anyway.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_LIB="$SCRIPT_DIR/../../../_lib/jsonl-append.sh"

_usage() {
  cat >&2 <<'USAGE'
safe-push.sh — force-push a branch with --force-with-lease --force-if-includes

Usage:
  safe-push.sh <branch>

Strategy A (bare lease + if-includes): no gh round-trip, gh-independent.
USAGE
  exit 1
}

case "${1:-}" in
  --help|-h) _usage ;;
esac

BRANCH="${1:-}"
[[ -n "$BRANCH" ]] || _usage

# Refuse to run from a detached HEAD; this would push an unnamed SHA-based ref
# which is likely wrong and cannot be validated against the current branch name.
"$SCRIPT_DIR/preflight.sh" detached-head \
  || { echo "safe-push.sh: refusing to push from detached HEAD" >&2; exit 1; }

push_exit=0
git push --force-with-lease --force-if-includes origin "$BRANCH" || push_exit=$?

RESULT="ok"
[[ "$push_exit" -eq 0 ]] || RESULT="failed"

# Log the op regardless of push outcome.
REPO_KEY=$("$SCRIPT_DIR/repo-key.sh" 2>/dev/null || echo "unknown")
OPS_LOG="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${REPO_KEY}/ops.jsonl"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
bash "$SHARED_LIB" "$OPS_LOG" \
  "$(jq -nc --arg op "safe-push" --arg branch "$BRANCH" \
      --arg result "$RESULT" --arg ts "$TS" \
      '{op:$op,branch:$branch,result:$result,ts:$ts}')"

exit "$push_exit"
