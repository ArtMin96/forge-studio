#!/usr/bin/env bash
# argv-driven stack-graph state store.
#
# Reads and writes per-repo branch metadata to
#   ${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/<repo-key>/stack-graph.json
#
# JSON shape per branch:
#   { "parent": "<str>", "parent_sha_at_stack_time": "<str>", "pr_number": <int|null> }
#
# Subcommands:
#   get <branch>                              — print the branch object (JSON)
#   set <branch> <parent> <parent-sha> <pr>  — upsert; pr may be "null" or an integer
#   list                                      — print all branch names (one per line)
#   path                                      — print the graph file path (for inspection)
#   diverged <branch>                         — compute live divergence from stored parent

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate (and if needed create) the state file.
_graph_path() {
  local repo_key
  repo_key=$(bash "$LIB_DIR/repo-key.sh")
  local state_dir="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${repo_key}"
  mkdir -p "$state_dir"
  printf '%s/stack-graph.json' "$state_dir"
}

_read_graph() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    printf '{}'
  fi
}

CMD="${1:-}"
shift || true

case "$CMD" in
  get)
    branch="${1:?get requires <branch>}"
    graph_file=$(_graph_path)
    _read_graph "$graph_file" | jq -e --arg b "$branch" '.[$b] // error("branch not found: "+$b)'
    ;;

  set)
    branch="${1:?set requires <branch>}"
    parent="${2:?set requires <parent>}"
    parent_sha="${3:?set requires <parent-sha>}"
    pr_arg="${4:?set requires <pr-number> (integer or null)}"
    # Normalise pr_number: accept literal "null" or an integer string.
    if [[ "$pr_arg" == "null" ]]; then
      pr_json="null"
    elif [[ "$pr_arg" =~ ^[0-9]+$ ]]; then
      pr_json="$pr_arg"
    else
      printf 'stack-graph set: pr-number must be a non-negative integer or "null", got: %s\n' "$pr_arg" >&2
      exit 1
    fi
    graph_file=$(_graph_path)
    current=$(_read_graph "$graph_file")
    updated=$(printf '%s' "$current" | jq \
      --arg b   "$branch" \
      --arg p   "$parent" \
      --arg sha "$parent_sha" \
      --argjson pr "$pr_json" \
      '.[$b] = {"parent": $p, "parent_sha_at_stack_time": $sha, "pr_number": $pr}')
    printf '%s\n' "$updated" > "$graph_file"
    ;;

  list)
    graph_file=$(_graph_path)
    _read_graph "$graph_file" | jq -r 'keys[]'
    ;;

  path)
    _graph_path
    ;;

  diverged)
    branch="${1:?diverged requires <branch>}"
    graph_file=$(_graph_path)
    parent=$(_read_graph "$graph_file" | jq -re --arg b "$branch" '.[$b].parent // error("branch not in graph: "+$b)')
    # A deleted/renamed parent is exactly the broken-tree state this tool exists to surface,
    # so fail with a clear diagnostic rather than the opaque exit 128 from merge-base under set -e.
    for ref in "$parent" "$branch"; do
      git rev-parse --verify --quiet "$ref^{commit}" >/dev/null \
        || { echo "diverged: ref not found: $ref" >&2; exit 1; }
    done
    # Compute live: left = commits on parent not on branch, right = commits on branch not on parent.
    merge_base=$(git merge-base "$parent" "$branch" 2>/dev/null)
    counts=$(git rev-list --left-right --count "${parent}...${branch}" 2>/dev/null)
    left=$(printf '%s' "$counts" | awk '{print $1}')
    right=$(printf '%s' "$counts" | awk '{print $2}')
    printf '{"merge_base":"%s","parent_ahead":%s,"branch_ahead":%s}\n' \
      "$merge_base" "$left" "$right"
    ;;

  ""|--help|-h)
    cat >&2 <<'USAGE'
stack-graph.sh — per-repo branch stack state

Usage:
  stack-graph.sh get <branch>
  stack-graph.sh set <branch> <parent> <parent-sha> <pr-number|null>
  stack-graph.sh list
  stack-graph.sh path
  stack-graph.sh diverged <branch>
USAGE
    exit 1
    ;;

  *)
    printf 'stack-graph.sh: unknown subcommand: %s\n' "$CMD" >&2
    exit 1
    ;;
esac
