#!/usr/bin/env bash
# Rebase a branch stack forward using --update-refs.
#
# Usage: restack.sh <top-branch> [<base>]
#
# <top-branch>  — the tip of the stack to rebase; rebase traverses from this
#                 branch down to <base>.
# <base>        — the rebase upstream (default: the top-branch's recorded parent
#                 from the stack graph).
#
# Stdout: one branch name per line for every branch whose SHA the rebase moved
# (the intermediate refs from git's --update-refs block plus the rebased tip).
# The caller is responsible for pushing — this script does NOT push.
#
# On conflict: git rebase --abort restores HEAD to its pre-rebase position, then
# this script exits non-zero with a diagnostic.  No mid-rebase state is left
# behind (abort is verified by confirming rebase dirs are gone and the rebased
# branch is back at its pre-rebase tip).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_LIB="$SCRIPT_DIR/../../../_lib/jsonl-append.sh"

_usage() {
  cat >&2 <<'USAGE'
restack.sh — rebase a branch stack forward with --update-refs

Usage:
  restack.sh <top-branch> [<base>]

Arguments:
  <top-branch>  Tip of the stack to rebase (checked out branch or any branch name)
  <base>        Upstream for the rebase.  Defaults to the top-branch's recorded
                parent in the stack graph.

Stdout: names of branches that were moved (one per line); pass each to safe-push.sh.
USAGE
  exit 1
}

case "${1:-}" in
  --help|-h) _usage ;;
esac

TOP_BRANCH="${1:-}"
[[ -n "$TOP_BRANCH" ]] || _usage

BASE="${2:-}"

# If no base given, look it up from the stack graph.
if [[ -z "$BASE" ]]; then
  BASE=$("$SCRIPT_DIR/stack-graph.sh" get "$TOP_BRANCH" 2>/dev/null \
    | jq -re '.parent') \
    || { echo "restack.sh: no base given and '$TOP_BRANCH' is not in the stack graph" >&2; exit 1; }
fi

# Record the tip's pre-rebase SHA. git's --update-refs block reports only the
# intermediate refs, never the rebased tip, so we detect a moved tip ourselves;
# it also lets us verify a clean restore if the rebase aborts on conflict.
# (git rebase <base> <top> switches to <top> first, so on --abort HEAD is reset
# to <top>'s pre-rebase tip — TOP_PRE — not whatever branch we started on.)
TOP_PRE=$(git rev-parse "$TOP_BRANCH" 2>/dev/null || true)

# Run the rebase, capturing BOTH streams into the temp file: --update-refs
# reports moved refs on stderr, but a no-op rebase prints "Current branch X is
# up to date." on stdout, which must not leak into this script's own stdout
# (the moved-branch contract channel). git rebase exits non-zero on conflict.
REBASE_OUT=$(mktemp)
trap 'rm -f "$REBASE_OUT"' EXIT

rebase_exit=0
git rebase --update-refs "$BASE" "$TOP_BRANCH" >"$REBASE_OUT" 2>&1 || rebase_exit=$?

if [[ "$rebase_exit" -ne 0 ]]; then
  # Abort to restore clean state before reporting the failure.
  # The abort is necessary because rebase stopped mid-flight; without it the
  # working tree and HEAD remain in a partial state that blocks further git ops.
  git rebase --abort 2>/dev/null || true

  # Verify abort actually restored state: rebase dirs must be gone and HEAD
  # must resolve.  If not, surface a clear diagnostic so the user can intervene.
  rebase_merge_dir=$(git rev-parse --git-path rebase-merge 2>/dev/null || true)
  rebase_apply_dir=$(git rev-parse --git-path rebase-apply 2>/dev/null || true)
  if [[ -d "$rebase_merge_dir" || -d "$rebase_apply_dir" ]]; then
    echo "restack.sh: rebase --abort did not clean up rebase dirs — manual intervention required" >&2
  fi

  # The branch being rebased must be back at its pre-rebase tip; if not, the abort
  # left it in an unexpected position and the user needs to inspect it by hand.
  if [[ -n "$TOP_PRE" ]]; then
    top_post_abort=$(git rev-parse "$TOP_BRANCH" 2>/dev/null || true)
    if [[ -n "$top_post_abort" && "$top_post_abort" != "$TOP_PRE" ]]; then
      echo "restack.sh: after --abort, '$TOP_BRANCH' ($top_post_abort) does not match its pre-rebase tip ($TOP_PRE) — manual intervention required" >&2
    fi
  fi

  cat "$REBASE_OUT" >&2
  echo "restack.sh: rebase of '$TOP_BRANCH' onto '$BASE' failed (exit $rebase_exit); aborted, no state left behind" >&2

  # Log the failed op.
  REPO_KEY=$("$SCRIPT_DIR/repo-key.sh" 2>/dev/null || echo "unknown")
  OPS_LOG="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${REPO_KEY}/ops.jsonl"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  bash "$SHARED_LIB" "$OPS_LOG" \
    "$(jq -nc --arg op "restack" --arg branch "$TOP_BRANCH" --arg base "$BASE" \
        --arg result "conflict" --arg ts "$TS" \
        '{op:$op,branch:$branch,base:$base,result:$result,ts:$ts}')"

  exit "$rebase_exit"
fi

# Parse the list of refs that --update-refs moved from git's stderr output.
# git emits a block like:
#   Updated the following refs with --update-refs:
#         refs/heads/feat-b
#         refs/heads/feat-a
# Extract the refs/heads/ lines and strip the prefix to get bare branch names.
MOVED_BRANCHES=$(grep -E '^\s+refs/heads/' "$REBASE_OUT" \
  | sed 's|.*refs/heads/||' \
  | sed 's/[[:space:]]//g' \
  || true)

# The tip is rebased but never listed in the --update-refs block; if its SHA
# changed it also needs pushing, so add it to the moved list.
TOP_POST=$(git rev-parse "$TOP_BRANCH" 2>/dev/null || true)
if [[ -n "$TOP_PRE" && "$TOP_PRE" != "$TOP_POST" ]]; then
  if [[ -n "$MOVED_BRANCHES" ]]; then
    MOVED_BRANCHES=$(printf '%s\n%s' "$MOVED_BRANCHES" "$TOP_BRANCH")
  else
    MOVED_BRANCHES="$TOP_BRANCH"
  fi
fi

# Print moved branches to stdout for the caller (one per line).
if [[ -n "$MOVED_BRANCHES" ]]; then
  printf '%s\n' "$MOVED_BRANCHES"
fi

# Log the successful op.
REPO_KEY=$("$SCRIPT_DIR/repo-key.sh" 2>/dev/null || echo "unknown")
OPS_LOG="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${REPO_KEY}/ops.jsonl"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -n "$MOVED_BRANCHES" ]]; then
  MOVED_JSON=$(printf '%s\n' "$MOVED_BRANCHES" | jq -Rnc '[inputs]')
else
  MOVED_JSON='[]'
fi
bash "$SHARED_LIB" "$OPS_LOG" \
  "$(jq -nc --arg op "restack" --arg branch "$TOP_BRANCH" --arg base "$BASE" \
      --arg result "ok" --arg ts "$TS" --argjson moved "$MOVED_JSON" \
      '{op:$op,branch:$branch,base:$base,result:$result,moved:$moved,ts:$ts}')"
