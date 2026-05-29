#!/usr/bin/env bash
# SessionStart: surface dependency status and stack position so Claude always
# knows where it sits in the stacked-PR chain at the start of each session.
#
# Emits context via stdout + exit 0. A SessionStart hook must never block, so
# every branch ends with exit 0 — errors are swallowed silently after printing
# whatever context was gathered. Matches the long-session surface-progress.sh
# pattern: accumulate into OUT, printf "%b" at the end.
#
# No network: gh is not called here. A gh round-trip on every SessionStart
# would slow session startup unacceptably. Stack state comes from the local
# graph file only.

set -uo pipefail

# Resolve lib dir relative to this script so the hook works wherever the
# plugin is installed — CLAUDE_PLUGIN_ROOT is set by the harness at run time,
# but $0 (the script's own path) is always reliable for sibling resolution.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../skills/_lib"

OUT=""

# 1. Dependency check — warn once if git < 2.38 or gh is absent.
#    These are surfaced as warnings, not fatal errors. Plugins cannot
#    auto-install dependencies; printing is the only enforcement mechanism.
missing_parts=""

git_version_str=$(git --version 2>/dev/null || true)
if [[ -z "$git_version_str" ]]; then
  missing_parts="git not found"
else
  # Extract major.minor from "git version X.Y.Z[...]"
  git_major=$(printf '%s' "$git_version_str" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | cut -d. -f1)
  git_minor=$(printf '%s' "$git_version_str" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | cut -d. -f2)
  git_major=${git_major:-0}
  git_minor=${git_minor:-0}
  # 2.38 is the floor for --update-refs (used by stack-restack)
  if [[ "$git_major" -lt 2 || ( "$git_major" -eq 2 && "$git_minor" -lt 38 ) ]]; then
    missing_parts="git ${git_major}.${git_minor} < 2.38"
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  if [[ -n "$missing_parts" ]]; then
    missing_parts="${missing_parts}, gh not found"
  else
    missing_parts="gh not found"
  fi
fi

if [[ -n "$missing_parts" ]]; then
  OUT="${OUT}[stack-flow] requires git>=2.38 and gh — ${missing_parts}\n"
fi

# 2. Stack position — only when inside a git repo.
if git rev-parse --git-dir >/dev/null 2>&1; then
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)

  if [[ -n "$current_branch" ]]; then
    # Read the local stack graph — no network, no gh.
    repo_key=$(bash "${LIB_DIR}/repo-key.sh" 2>/dev/null || true)
    graph_file=""
    if [[ -n "$repo_key" ]]; then
      data_dir="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/${repo_key}"
      graph_file="${data_dir}/stack-graph.json"
    fi

    if [[ -n "$graph_file" && -f "$graph_file" ]]; then
      # Parent of current branch (empty string if not in graph)
      parent=$(jq -re --arg b "$current_branch" '.[$b].parent // empty' "$graph_file" 2>/dev/null || true)

      # Children: branches whose parent field equals the current branch
      child_count=$(jq -r --arg b "$current_branch" '[to_entries[] | select(.value.parent == $b)] | length' "$graph_file" 2>/dev/null || true)
      child_count=${child_count:-0}

      if [[ -n "$parent" ]]; then
        OUT="${OUT}[stack-flow] branch: ${current_branch} (parent: ${parent}, children: ${child_count})\n"
      else
        # Branch exists in repo but not in the stack graph
        OUT="${OUT}[stack-flow] branch: ${current_branch} (not in stack — use /stack-create to register)\n"
      fi
    fi
    # No graph file: stay silent (no stack context to surface)
  fi
fi

if [[ -n "$OUT" ]]; then
  printf "%b" "$OUT"
fi

exit 0
