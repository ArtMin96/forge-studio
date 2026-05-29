# Stack Reparent

`/stack-reparent <child-branch> <new-base>` handles the case where a parent branch was squash-merged into its base and the child now contains the parent's commits as duplicates. It strips those duplicates by replaying only the child's own commits onto the new base using `git rebase --onto`, retargets the child's PR, and force-pushes the result. It belongs to the `stack-flow` plugin, which provides stacked-PR creation, submission, rebasing, and re-parenting skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install stack-flow@forge-studio
```

```bash
/stack-reparent <child-branch> <new-base>
```

`<child-branch>` is the branch to re-parent. `<new-base>` is the branch onto which the child's commits will be replayed — typically `main` or `master` after the squash merge has landed.

## Why you need it

A squash merge condenses the parent branch's entire history into a single commit on the base. After that, the child branch still contains the parent's original commits, which are now duplicates of the squash commit. A plain `git rebase <new-base>` cannot strip them: it sees the commits as distinct objects and keeps them in the child. `git rebase --onto` is the correct tool — it specifies exactly where to cut, replaying only the commits above `parent_sha_at_stack_time` onto the new base.

The `parent_sha_at_stack_time` field recorded by `/stack-create` is the pivot. It is the tip SHA of the parent at the moment the child was created, which is exactly the cut point needed to isolate the child's own commits from the parent's.

## When to use it

- When a parent branch (e.g. `feat-auth`) was squash-merged into `main` and the child (`feat-auth-tests`) now contains commits from `feat-auth` as duplicates.

Do not use it for ordinary divergence where the parent's commits were not squash-merged — use `/stack-restack` instead, which rebases the whole chain using `--update-refs`.

## How it works

```bash
# 1. Read the recorded old-base SHA from the stack graph
OLD_SHA=$(bash plugins/stack-flow/skills/_lib/stack-graph.sh get <child-branch> \
  | jq -r '.parent_sha_at_stack_time')

# 2. Assert old-base is an ancestor of the child; rebase --onto the new base
#    and retarget the PR (done inside onto-reparent.sh)
bash plugins/stack-flow/skills/_lib/onto-reparent.sh <child-branch> <new-base> "$OLD_SHA"

# 3. Force-push the child
bash plugins/stack-flow/skills/_lib/safe-push.sh <child-branch>

# 4. Update the stack graph to record the new parent
bash plugins/stack-flow/skills/_lib/stack-graph.sh set \
  <child-branch> <new-base> $(git rev-parse <new-base>) <pr-number>
```

`onto-reparent.sh` performs the ancestor assertion (exits non-zero if `OLD_SHA` is not reachable from the child), runs `git rebase --onto <new-base> <old-base-sha> <child>`, calls `git rebase --abort` on conflict, and on success calls `gh pr edit <child> --base <new-base>` so the PR retarget and branch rewrite happen in the same operation.

`safe-push.sh` runs `git push --force-with-lease --force-if-includes origin <child-branch>`. `--force-with-lease` compares against the local remote-tracking ref; `--force-if-includes` closes the stale-local-ref hole by requiring the remote-tracking ref to be in the local reflog.

## Examples

### Successful re-parent after squash merge

Input:
```
child-branch: feat-auth-tests
Recorded parent: feat-auth (squash-merged into main)
parent_sha_at_stack_time: a3f8c21d
new-base: main
Commits on feat-auth-tests beyond a3f8c21d: 2 (the child's own changes)
```

Output:
```
Ancestor check passed: a3f8c21d is an ancestor of feat-auth-tests
Rebased feat-auth-tests onto main (replayed 2 commits)
Retargeted PR #43: base changed from feat-auth to main
Pushed feat-auth-tests
```

---

### Ancestor check fails

Input:
```
child-branch: feat-auth-tests
parent_sha_at_stack_time: deadbeef
feat-auth-tests has already been rebased; deadbeef is no longer reachable from it
```

Output:
```
Error: deadbeef is not an ancestor of feat-auth-tests
The recorded old-base SHA is not reachable — the child may have already been rebased.
Update the stack graph entry for feat-auth-tests and retry.
```

## Known failure modes

- **Ancestor check fails.** If `parent_sha_at_stack_time` is not reachable from the child, the child has already been rebased without updating the stack graph. Update the graph entry manually (`stack-graph.sh set`) and retry.
- **Conflict during `rebase --onto`.** `onto-reparent.sh` calls `git rebase --abort` and exits non-zero; no partial state is left behind. Resolve the conflict on the child branch first, then re-run.
- **`gh pr edit` fails after rebase succeeds.** The branch is rebased but the PR still targets the old base. Re-run `gh pr edit <child> --base <new-base>` manually, or re-run `/stack-reparent` — the ancestor check is performed fresh each time, and if the child is already on the new base the rebase is a no-op.
- **Stale lease on push.** `safe-push.sh` rejects the push when another process pushed to the same branch since the last fetch. Fetch first (`git fetch origin <child-branch>`), then push.

## Related

- [`stack-create.md`](stack-create.md) — records `parent_sha_at_stack_time` that this skill depends on
- [`stack-status.md`](stack-status.md) — identifies duplicate-commit situations before re-parenting
- [`stack-restack.md`](stack-restack.md) — the ordinary divergence path for non-squash-merge cases
- [Architecture](../../architecture.md) — stacked-PR orchestration in the 8-component harness model
