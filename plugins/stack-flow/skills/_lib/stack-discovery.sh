#!/usr/bin/env bash
# Print the stack tree with live PR state and divergence flags.
#
# Usage: stack-discovery.sh
#
# Reads the stack graph and enriches each branch with:
#   - PR number and state from `gh pr view` / `gh pr list`
#   - A diverged-from-parent flag (computed via stack-graph.sh diverged)
#
# Output: human-readable tree, one branch per line, e.g.:
#   main
#   └── feat-a  [PR #12: OPEN]
#       └── feat-b  [PR #13: OPEN] [DIVERGED: parent 2 ahead, branch 3 ahead]
#
# Tolerates gh being absent or erroring: degrades gracefully to graph-only
# output with a warning, does not crash.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_LIB="$SCRIPT_DIR/../../../_lib/jsonl-append.sh"

_usage() {
  cat >&2 <<'USAGE'
stack-discovery.sh — print the branch stack with PR state and divergence flags

Usage:
  stack-discovery.sh

Output: tree of branches from the stack graph with live PR state (via gh) and
divergence-from-parent flags.  Degrades to graph-only if gh is unavailable.
USAGE
  exit 1
}

case "${1:-}" in
  --help|-h) _usage ;;
esac

# --- gh availability check -----------------------------------------------

GH_AVAILABLE=0
if command -v gh >/dev/null 2>&1; then
  # gh is installed; check it can talk to GitHub (non-fatal if it can't).
  if gh auth status >/dev/null 2>&1; then
    GH_AVAILABLE=1
  else
    echo "[stack-discovery] gh is installed but not authenticated — showing graph-only" >&2
  fi
else
  echo "[stack-discovery] gh not found — showing graph-only" >&2
fi

# --- Collect all branches from the stack graph ---------------------------

mapfile -t ALL_BRANCHES < <("$SCRIPT_DIR/stack-graph.sh" list 2>/dev/null || true)

if [[ "${#ALL_BRANCHES[@]}" -eq 0 ]]; then
  echo "(no branches in the stack graph)"
  exit 0
fi

# --- Fetch PR state for all branches (one gh call per branch) -----------

declare -A PR_STATE  # branch -> "PR #N: STATE" or ""

if [[ "$GH_AVAILABLE" -eq 1 ]]; then
  for b in "${ALL_BRANCHES[@]}"; do
    [[ -z "$b" ]] && continue
    pr_info=$(gh pr view "$b" --json number,state \
      --jq '"PR #\(.number): \(.state)"' 2>/dev/null) || pr_info=""
    PR_STATE["$b"]="$pr_info"
  done
fi

# --- Compute divergence for each branch -----------------------------------

declare -A DIVERGE_INFO  # branch -> human-readable divergence or ""

for b in "${ALL_BRANCHES[@]}"; do
  [[ -z "$b" ]] && continue
  div_json=$("$SCRIPT_DIR/stack-graph.sh" diverged "$b" 2>/dev/null) || { DIVERGE_INFO["$b"]=""; continue; }
  parent_ahead=$(printf '%s' "$div_json" | jq -r '.parent_ahead' 2>/dev/null) || parent_ahead=0
  branch_ahead=$(printf '%s' "$div_json" | jq -r '.branch_ahead' 2>/dev/null) || branch_ahead=0
  if [[ "$parent_ahead" -gt 0 ]]; then
    DIVERGE_INFO["$b"]="DIVERGED: parent ${parent_ahead} ahead, branch ${branch_ahead} ahead"
  else
    DIVERGE_INFO["$b"]=""
  fi
done

# --- Build and print the tree --------------------------------------------

# Find root branches: those whose recorded parent is NOT itself in the graph.
declare -A IN_GRAPH
for b in "${ALL_BRANCHES[@]}"; do
  [[ -n "$b" ]] && IN_GRAPH["$b"]=1
done

# Build a children map.
declare -A CHILDREN  # parent -> space-separated list of child branches
for b in "${ALL_BRANCHES[@]}"; do
  [[ -z "$b" ]] && continue
  parent=$("$SCRIPT_DIR/stack-graph.sh" get "$b" 2>/dev/null | jq -re '.parent' 2>/dev/null) || continue
  if [[ -n "${IN_GRAPH[$parent]+_}" ]]; then
    CHILDREN["$parent"]="${CHILDREN[$parent]:-} $b"
  else
    # Parent not in graph — this is a root-level branch.
    CHILDREN["__roots__"]="${CHILDREN[__roots__]:-} $b"
    # Print the external parent once as context if we haven't already.
    if [[ -z "${IN_GRAPH[__printed_$parent]+_}" ]]; then
      echo "$parent  (external)"
      IN_GRAPH["__printed_$parent"]=1
    fi
  fi
done

_print_branch() {
  local branch="$1"
  local prefix="$2"
  local connector="$3"

  local label="$branch"

  # Append PR state if known.
  local pr="${PR_STATE[$branch]:-}"
  [[ -n "$pr" ]] && label="$label  [$pr]"

  # Append divergence flag if present.
  local div="${DIVERGE_INFO[$branch]:-}"
  [[ -n "$div" ]] && label="$label  [$div]"

  echo "${prefix}${connector}${label}"

  # Recurse into children.
  local child_list="${CHILDREN[$branch]:-}"
  read -ra children <<< "$child_list"
  local count="${#children[@]}"
  local i=0
  for child in "${children[@]}"; do
    [[ -z "$child" ]] && continue
    i=$((i+1))
    if [[ "$i" -lt "$count" ]]; then
      _print_branch "$child" "${prefix}│   " "├── "
    else
      _print_branch "$child" "${prefix}    " "└── "
    fi
  done
}

# Print root branches (those with no in-graph parent).
ROOT_LIST="${CHILDREN[__roots__]:-}"
read -ra ROOTS <<< "$ROOT_LIST"

# Also catch branches explicitly listed but not appearing as children of any
# in-graph branch (fully isolated roots).
for b in "${ALL_BRANCHES[@]}"; do
  [[ -z "$b" ]] && continue
  parent=$("$SCRIPT_DIR/stack-graph.sh" get "$b" 2>/dev/null | jq -re '.parent' 2>/dev/null) || continue
  if [[ -z "${IN_GRAPH[$parent]+_}" ]] && [[ -z "${IN_GRAPH["__printed_$parent"]+_}" ]]; then
    # Already handled above; skip.
    true
  fi
done

for root in "${ROOTS[@]}"; do
  [[ -z "$root" ]] && continue
  _print_branch "$root" "" ""
done

# --- Log the op -----------------------------------------------------------

REPO_KEY=$("$SCRIPT_DIR/repo-key.sh" 2>/dev/null || echo "unknown")
OPS_LOG="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${REPO_KEY}/ops.jsonl"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COUNT="${#ALL_BRANCHES[@]}"
bash "$SHARED_LIB" "$OPS_LOG" \
  "$(jq -nc --arg op "stack-discovery" --argjson count "$COUNT" \
      --arg gh_available "$GH_AVAILABLE" --arg ts "$TS" \
      '{op:$op,branch_count:$count,gh_available:($gh_available=="1"),ts:$ts}')"
