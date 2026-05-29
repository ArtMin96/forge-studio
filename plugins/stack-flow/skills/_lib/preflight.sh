#!/usr/bin/env bash
# argv-driven pre-flight safety checks shared by restack, reparent, and the
# push guard.  Each subcommand exits 0=ok / non-zero=violation.  On a
# violation the one-line reason goes to stderr; nothing is printed on success.
#
# Subcommands:
#   detached-head                   — violation when HEAD is not on a branch
#   dirty-tree [--autostash]        — violation when the working tree has
#                                     tracked changes; --autostash stashes
#                                     instead of failing
#   rebase-in-progress              — violation while a rebase is in flight
#   branch-in-other-worktree <br>  — violation if <br> is checked out in
#                                     another worktree
#   current-branch                  — prints the short branch name; exit 0

set -euo pipefail

CMD="${1:-}"
shift || true

case "$CMD" in

  detached-head)
    # symbolic-ref exits non-zero when HEAD is detached (pointing at a SHA
    # rather than a ref).  -q suppresses its own output so stderr stays clean.
    if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
      echo "preflight: HEAD is detached — check out a branch before proceeding" >&2
      exit 1
    fi
    ;;

  dirty-tree)
    autostash=0
    if [[ "${1:-}" == "--autostash" ]]; then
      autostash=1
    fi
    # --untracked-files=no keeps the check focused on tracked changes only,
    # matching the rebase --autostash scope (untracked files survive a rebase).
    dirty=$(git status --porcelain --untracked-files=no)
    if [[ -n "$dirty" ]]; then
      if [[ "$autostash" -eq 1 ]]; then
        # Stash so the caller can rebase cleanly; the caller is responsible for
        # popping the stash after the operation completes or fails.
        git stash push --quiet -m "preflight autostash"
      else
        echo "preflight: working tree has uncommitted changes — commit, stash, or pass --autostash" >&2
        exit 1
      fi
    fi
    ;;

  rebase-in-progress)
    # git rev-parse --git-path always exits 0 and prints the path regardless of
    # whether that path exists, so we must test the directory with -d.
    rebase_merge_dir=$(git rev-parse --git-path rebase-merge 2>/dev/null)
    rebase_apply_dir=$(git rev-parse --git-path rebase-apply 2>/dev/null)
    if [[ -d "$rebase_merge_dir" || -d "$rebase_apply_dir" ]]; then
      echo "preflight: a rebase is already in progress — resolve or abort it first" >&2
      exit 1
    fi
    ;;

  branch-in-other-worktree)
    branch="${1:?branch-in-other-worktree requires <branch>}"
    current_wt=$(git rev-parse --show-toplevel 2>/dev/null)
    # --porcelain emits structured records: each worktree block contains a
    # "branch refs/heads/<name>" line.  We check every worktree that is NOT
    # the current one.
    in_other=0
    current_wt_block=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^worktree\ (.*) ]]; then
        wt_path="${BASH_REMATCH[1]}"
        # Normalise the path (git may emit ~ or absolute paths)
        wt_path_abs=$(readlink -f "$wt_path" 2>/dev/null || echo "$wt_path")
        current_abs=$(readlink -f "$current_wt" 2>/dev/null || echo "$current_wt")
        if [[ "$wt_path_abs" == "$current_abs" ]]; then
          current_wt_block=1
        else
          current_wt_block=0
        fi
      elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
        wt_branch="${BASH_REMATCH[1]}"
        if [[ "$current_wt_block" -eq 0 && "$wt_branch" == "$branch" ]]; then
          in_other=1
        fi
      fi
    done < <(git worktree list --porcelain 2>/dev/null)
    if [[ "$in_other" -eq 1 ]]; then
      echo "preflight: branch '$branch' is checked out in another worktree — push there directly or remove that worktree first" >&2
      exit 1
    fi
    ;;

  current-branch)
    git symbolic-ref --short HEAD
    ;;

  ""|--help|-h)
    cat >&2 <<'USAGE'
preflight.sh — pre-flight safety checks for stack operations

Usage:
  preflight.sh detached-head
  preflight.sh dirty-tree [--autostash]
  preflight.sh rebase-in-progress
  preflight.sh branch-in-other-worktree <branch>
  preflight.sh current-branch

Exit codes: 0=ok, non-zero=violation (reason printed to stderr).
USAGE
    exit 1
    ;;

  *)
    printf 'preflight.sh: unknown subcommand: %s\n' "$CMD" >&2
    exit 1
    ;;
esac
