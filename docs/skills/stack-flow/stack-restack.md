# Stack Restack

`/stack-restack` rebases every branch in a stacked-PR chain onto its recorded parent, force-pushes each branch whose tip moved, and refreshes each PR body so the diff shown on GitHub stays accurate. It belongs to the `stack-flow` plugin, which provides stacked-PR creation, submission, rebasing, and re-parenting skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install stack-flow@forge-studio
```

```bash
/stack-restack
/stack-restack <top-branch>
/stack-restack <top-branch> <base>
```

With no arguments the skill uses the current branch as the top and reads its base from the stack graph. Providing `<top-branch>` and `<base>` is useful when restacking a sub-chain without touching branches above `<top-branch>`.

## Why you need it

When a parent branch receives new commits — from a teammate's push or from an amendment mid-stack — all branches above it diverge. Each diverged branch needs to be rebased in order, base-to-tip, so that each child's diff stays anchored to its parent's latest state. Doing this manually with `git rebase` per branch is tedious and easy to get wrong for deeper stacks.

`/stack-restack` uses `git rebase --update-refs` so the entire chain is rebased in a single pass, with every intermediate ref updated atomically. It then force-pushes only the branches that actually moved and refreshes their PR bodies, leaving unchanged branches untouched.

## When to use it

- After a teammate pushes new commits to a parent branch and `/stack-status` shows `[DIVERGED]` flags.
- After amending a commit mid-stack and subsequent branches fall behind.
- Before running `/stack-submit` when the branch history has changed since the last push.

Do not use it when the parent branch was squash-merged into its base and the child now contains duplicate commits — that is the squash-merge re-parent case; use `/stack-reparent` instead.

## How it works

```bash
# 1. Pre-flight checks
bash plugins/stack-flow/skills/_lib/preflight.sh detached-head
bash plugins/stack-flow/skills/_lib/preflight.sh dirty-tree
bash plugins/stack-flow/skills/_lib/preflight.sh rebase-in-progress

# 2. Rebase the chain with --update-refs
MOVED=$(bash plugins/stack-flow/skills/_lib/restack.sh <top-branch> [<base>])

# 3. For each branch restack.sh reports as moved
for branch in $MOVED; do
  bash plugins/stack-flow/skills/_lib/safe-push.sh "$branch"
  bash plugins/stack-flow/skills/_lib/pr-body.sh "$branch" \
    | gh pr edit "$branch" --body-file -
done
```

`restack.sh` calls `git rebase --update-refs`, which rebases the chain in a single pass and updates every intermediate branch ref. It prints to stdout the names of branches whose tips moved; branches that were already up to date produce no output.

`safe-push.sh` runs `git push --force-with-lease --force-if-includes origin <branch>`. `--force-with-lease` compares against the local remote-tracking ref; `--force-if-includes` closes the stale-local-ref hole by requiring the remote-tracking ref to be in the local reflog.

## Examples

### Stack with two diverged branches

Input (from `/stack-status`):
```
main
└── feat-auth  [PR #42: OPEN] [DIVERGED: parent 2 ahead, branch 1 ahead]
    └── feat-auth-tests  [PR #43: OPEN] [DIVERGED: parent 2 ahead, branch 0 ahead]
```

After `/stack-restack`:
```
Rebased feat-auth onto main (2 commits applied)
Pushed feat-auth
Refreshed PR #42 body
Rebased feat-auth-tests onto feat-auth (1 commit applied)
Pushed feat-auth-tests
Refreshed PR #43 body
```

---

### No-op when already in sync

Input: all branches already rebased onto their parents.

Output: empty — `restack.sh` emits nothing when no branch tip moves.

## Known failure modes

- **Conflict mid-restack.** `restack.sh` calls `git rebase --abort` on conflict and exits non-zero, leaving no partial state behind. The working tree is restored to its pre-rebase position. Resolve the conflict on the specific branch manually, then re-run.
- **Stale lease rejected on push.** `safe-push.sh` fails when another process pushed to the same branch since the last fetch. Fetch (`git fetch origin <branch>`) then retry.
- **Rebase already in progress.** If a prior rebase was interrupted, `preflight.sh rebase-in-progress` stops the run before any rebase starts. Resolve the in-progress rebase with `git rebase --continue` or `git rebase --abort`, then re-run.
- **Dirty working tree.** `preflight.sh dirty-tree` stops the run when tracked files are modified. Commit or stash changes before restacking.

## Related

- [`stack-status.md`](stack-status.md) — identify diverged branches before restacking
- [`stack-submit.md`](stack-submit.md) — open or refresh PRs after the chain is in sync
- [`stack-reparent.md`](stack-reparent.md) — the squash-merge recovery path; use instead of restack when the parent's commits are now duplicated on the child
- [Architecture](../../architecture.md) — stacked-PR orchestration in the 8-component harness model
