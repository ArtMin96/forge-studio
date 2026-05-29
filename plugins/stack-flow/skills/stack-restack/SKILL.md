---
name: stack-restack
description: Use when branches in a stacked-PR chain have diverged from their parents and need rebasing — runs the full stack rebase using --update-refs, then force-pushes each moved branch and reconciles its PR body.
when_to_use: Reach for this after a teammate pushes to a parent branch or after you amend a commit mid-stack and subsequent branches fall behind. Run /stack-status first to confirm which branches are diverged, then run this to rebase the whole chain in one shot. Do NOT use when the parent branch was squash-merged and its commits now appear duplicated on the child — that is the squash-merge re-parent case; use /stack-reparent instead.
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
argument-hint: "[<top-branch> [<base>]]"
scheduling: one or more branches in the stack are diverged from their parent and need rebasing
structural:
  - Run pre-flight checks via preflight.sh (detached-head, dirty-tree, rebase-in-progress)
  - Run restack.sh to rebase the chain with --update-refs
  - Force-push each branch restack.sh reports as moved via safe-push.sh
  - Refresh each moved PR body via pr-body.sh piped to gh pr edit
logical: every branch in the stack is rebased onto its parent, its remote ref matches its local tip, and its PR body reflects the updated diff
---

# /stack-restack — Rebase the Whole Stack

Rebase every branch in a stacked-PR chain onto its recorded parent, force-push each moved branch, and refresh each PR body so the diff shown on GitHub stays accurate.

## Invocation

```
/stack-restack
/stack-restack <top-branch>
/stack-restack <top-branch> <base>
```

With no arguments the skill uses the current branch as the top and reads its base from the stack graph.

## What it does

```bash
# 1. Pre-flight checks
bash plugins/stack-flow/skills/_lib/preflight.sh detached-head
bash plugins/stack-flow/skills/_lib/preflight.sh dirty-tree
bash plugins/stack-flow/skills/_lib/preflight.sh rebase-in-progress

# 2. Rebase the chain
MOVED=$(bash plugins/stack-flow/skills/_lib/restack.sh <top-branch> [<base>])

# 3. For each branch printed by restack.sh
for branch in $MOVED; do
  bash plugins/stack-flow/skills/_lib/safe-push.sh "$branch"
  bash plugins/stack-flow/skills/_lib/pr-body.sh "$branch" | gh pr edit "$branch" --body-file -
done
```

`restack.sh` uses `git rebase --update-refs` so intermediate branches are rebased in a single pass; it prints the names of every branch whose tip moved to stdout.

## Execution Checklist

- [ ] Check: `bash plugins/stack-flow/skills/_lib/preflight.sh detached-head`
- [ ] Check: `bash plugins/stack-flow/skills/_lib/preflight.sh dirty-tree`
- [ ] Check: `bash plugins/stack-flow/skills/_lib/preflight.sh rebase-in-progress`
- [ ] Rebase: `bash plugins/stack-flow/skills/_lib/restack.sh <top-branch> [<base>]` — capture stdout (list of moved branches)
- [ ] For each moved branch, push: `bash plugins/stack-flow/skills/_lib/safe-push.sh <branch>`
- [ ] For each moved branch with a PR, refresh body: `bash plugins/stack-flow/skills/_lib/pr-body.sh <branch> | gh pr edit <branch> --body-file -`
- [ ] Report: number of branches rebased, pushed, and PR bodies refreshed

## Known Failure Modes

- **Conflict mid-restack.** `restack.sh` calls `git rebase --abort` on conflict and exits non-zero, leaving no partial state behind. The working tree is restored to its pre-rebase position. Resolve the conflict on the specific branch first, then re-run.
- **Stale lease on push.** `safe-push.sh` rejects the push when another process pushed to the same branch since the last fetch. Fetch (`git fetch origin <branch>`) then retry.
- **Rebase-in-progress on entry.** If a prior rebase was interrupted, `preflight.sh rebase-in-progress` exits non-zero before any rebase runs. Resolve the in-progress rebase (`git rebase --continue` or `--abort`) then re-run.
- **Dirty working tree.** `preflight.sh dirty-tree` stops the run if tracked files are modified. Commit or stash changes before restacking.
