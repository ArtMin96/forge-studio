---
name: stack-reparent
description: Use when a parent branch was squash-merged into its base and the child branch now shows duplicate commits — replays only the child's own commits onto the new base using rebase --onto, then retargets the child's PR and force-pushes.
when_to_use: Reach for this when a parent branch (e.g. feat-auth) was squash-merged into main and the child branch (e.g. feat-auth-tests) now contains duplicated commits from the merged parent. The recorded parent_sha_at_stack_time from the stack graph is used as the upstream for rebase --onto, isolating only the child's commits. Do NOT use for ordinary divergence where the parent's commits were not squash-merged — use /stack-restack instead, which rebases the whole chain using --update-refs.
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
argument-hint: "<child-branch> <new-base>"
scheduling: a parent branch was squash-merged and the child branch contains duplicate commits that need stripping via rebase --onto
structural:
  - Read parent_sha_at_stack_time from the stack graph for the child branch
  - Assert that the recorded old-base SHA is an ancestor of the child
  - Run onto-reparent.sh to rebase --onto the new base and retarget the PR
  - Force-push the child branch via safe-push.sh
logical: the child branch contains only its own commits (none from the squash-merged parent), its PR targets the new base, and its remote ref matches the local tip
---

# /stack-reparent — Re-parent After a Squash Merge

When a parent branch is squash-merged into its base, the child branch retains the parent's commits as duplicates. This skill strips those duplicates by replaying only the child's own commits onto the new base, then retargets the child's PR and force-pushes.

## Invocation

```
/stack-reparent <child-branch> <new-base>
```

`<child-branch>` is the branch to re-parent. `<new-base>` is the branch onto which the child's commits will be replayed (typically `main` or `master` after the squash merge lands).

## What it does

```bash
# 1. Read the recorded old-base SHA from the stack graph
OLD_SHA=$(bash plugins/stack-flow/skills/_lib/stack-graph.sh get <child-branch> \
  | jq -r '.parent_sha_at_stack_time')

# 2. Assert old-base is an ancestor of the child (done inside onto-reparent.sh)

# 3. Rebase --onto new-base, strip the old parent's commits, retarget the PR
bash plugins/stack-flow/skills/_lib/onto-reparent.sh <child-branch> <new-base> "$OLD_SHA"

# 4. Force-push the child
bash plugins/stack-flow/skills/_lib/safe-push.sh <child-branch>
```

`onto-reparent.sh` performs the ancestor assertion, runs `git rebase --onto <new-base> <old-base-sha> <child>`, calls `git rebase --abort` on conflict, and on success calls `gh pr edit <child> --base <new-base>` so the PR retarget and branch rewrite happen in the same operation.

## Execution Checklist

- [ ] Read the stack graph entry: `bash plugins/stack-flow/skills/_lib/stack-graph.sh get <child-branch>`
- [ ] Extract `parent_sha_at_stack_time` — this is the `<old-base-sha>` argument
- [ ] Confirm the new base exists locally: `git rev-parse --verify <new-base>`
- [ ] Run: `bash plugins/stack-flow/skills/_lib/onto-reparent.sh <child-branch> <new-base> <old-base-sha>`
  - If it exits non-zero (ancestor check failed or conflict), stop and report — do not push
- [ ] Force-push: `bash plugins/stack-flow/skills/_lib/safe-push.sh <child-branch>`
- [ ] Update the stack graph to record the new parent: `bash plugins/stack-flow/skills/_lib/stack-graph.sh set <child-branch> <new-base> $(git rev-parse <new-base>) <pr-number>`
- [ ] Report: old parent, new base, commits replayed count, push result

## Input / Output examples

### Pair 1 — successful re-parent after squash merge

Input:
```
child-branch: feat-auth-tests
Recorded parent: feat-auth (squash-merged into main)
parent_sha_at_stack_time: a3f8c21d
new-base: main
feat-auth-tests commits beyond a3f8c21d: 2 (the child's own changes)
```

Output:
```
Ancestor check passed: a3f8c21d is an ancestor of feat-auth-tests
Rebased feat-auth-tests onto main (replayed 2 commits)
Retargeted PR #43: base changed from feat-auth to main
Pushed feat-auth-tests
```

---

### Pair 2 — ancestor check fails

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

## Known Failure Modes

- **Ancestor check fails.** If `parent_sha_at_stack_time` is not reachable from the child, the child has already been rebased without updating the stack graph. Update the graph entry manually and retry.
- **Conflict during rebase --onto.** `onto-reparent.sh` calls `git rebase --abort` and exits non-zero; no partial state is left. Resolve the conflict on the child branch first, then re-run.
- **`gh pr edit` fails after rebase succeeds.** The branch is rebased but the PR still targets the old base. Re-run `gh pr edit <child> --base <new-base>` manually, or re-run `/stack-reparent` — `onto-reparent.sh` checks the ancestor condition fresh each time.
- **Stale lease on push.** `safe-push.sh` rejects the push when another process pushed to the same branch since the last fetch. Fetch first, then push.
