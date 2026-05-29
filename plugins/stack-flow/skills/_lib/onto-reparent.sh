#!/usr/bin/env bash
# Re-parent a child branch after a squash-merge using rebase --onto.
#
# Usage: onto-reparent.sh <child> <new-base> <old-base-sha>
#
# <child>        — branch whose history is being re-parented.
# <new-base>     — the new base branch (e.g. main after the squash-merge lands).
# <old-base-sha> — the SHA of the old parent at the time the stack was created
#                  (recorded in the stack graph as parent_sha_at_stack_time).
#                  Used as the upstream for rebase --onto, so only the child's
#                  own commits are replayed (not the merged-parent commits).
#
# Pre-flight: asserts <old-base-sha> is an ancestor of <child>.  If it is not,
# the stack is already in an unexpected state; abort with a clear message rather
# than silently rebasing onto the wrong base.
#
# After rebase: calls `gh pr edit <child> --base <new-base>` so the PR retarget
# and the rewritten branch are reconciled atomically from GitHub's perspective.
#
# On conflict: git rebase --abort restores clean state; exits non-zero.
# The abort is needed to prevent a mid-rebase state from blocking subsequent ops.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_LIB="$SCRIPT_DIR/../../../_lib/jsonl-append.sh"

_usage() {
  cat >&2 <<'USAGE'
onto-reparent.sh — re-parent a child branch after a squash-merge

Usage:
  onto-reparent.sh <child> <new-base> <old-base-sha>

Arguments:
  <child>        Branch to re-parent
  <new-base>     New base branch (e.g. main after the squash-merge)
  <old-base-sha> SHA of the old parent recorded at stack-create time

Requires: git, gh (for PR retarget)
USAGE
  exit 1
}

CHILD="${1:-}"
NEW_BASE="${2:-}"
OLD_BASE_SHA="${3:-}"

[[ -n "$CHILD" && -n "$NEW_BASE" && -n "$OLD_BASE_SHA" ]] || _usage

_log_op() {
  local result="$1"
  REPO_KEY=$("$SCRIPT_DIR/repo-key.sh" 2>/dev/null || echo "unknown")
  OPS_LOG="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${REPO_KEY}/ops.jsonl"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  bash "$SHARED_LIB" "$OPS_LOG" \
    "$(jq -nc --arg op "onto-reparent" --arg child "$CHILD" \
        --arg new_base "$NEW_BASE" --arg old_sha "$OLD_BASE_SHA" \
        --arg result "$result" --arg ts "$TS" \
        '{op:$op,child:$child,new_base:$new_base,old_base_sha:$old_sha,result:$result,ts:$ts}')"
}

# Assert the recorded old-base SHA is still an ancestor of the child branch.
# If it is not, the assumption that rebase --onto will isolate only the child's
# commits is violated; proceeding would replay commits that do not belong to
# the child.
if ! git merge-base --is-ancestor "$OLD_BASE_SHA" "$CHILD" 2>/dev/null; then
  echo "onto-reparent.sh: '$OLD_BASE_SHA' is not an ancestor of '$CHILD'" >&2
  echo "  The recorded old-base SHA is not reachable from '$CHILD'." >&2
  echo "  This can happen when the child was already rebased without updating the stack graph." >&2
  echo "  Update the stack graph entry for '$CHILD' and retry." >&2
  _log_op "ancestor-check-failed"
  exit 1
fi

# Run the onto-rebase: replay only the commits between <old-base-sha> and <child>
# onto <new-base>.  git exits non-zero on conflict.
rebase_exit=0
git rebase --onto "$NEW_BASE" "$OLD_BASE_SHA" "$CHILD" || rebase_exit=$?

if [[ "$rebase_exit" -ne 0 ]]; then
  # Abort to restore clean state before reporting the failure.
  # Without abort the working tree and HEAD are in partial rebase state, blocking
  # any subsequent git command.
  git rebase --abort 2>/dev/null || true

  echo "onto-reparent.sh: rebase --onto '$NEW_BASE' '$OLD_BASE_SHA' '$CHILD' failed (exit $rebase_exit); aborted" >&2
  _log_op "conflict"
  exit "$rebase_exit"
fi

# Retarget the PR base on GitHub so the PR and the rewritten branch agree.
# If gh is unavailable this is a hard error: the branch is now rebased but the
# PR still targets the old base, which will confuse reviewers and GitHub's merge
# button.
gh pr edit "$CHILD" --base "$NEW_BASE" \
  || { echo "onto-reparent.sh: rebase succeeded but 'gh pr edit $CHILD --base $NEW_BASE' failed" >&2
       echo "  Manually retarget the PR or re-run the gh command." >&2
       _log_op "pr-edit-failed"
       exit 1; }

_log_op "ok"
