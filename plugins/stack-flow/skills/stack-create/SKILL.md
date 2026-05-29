---
name: stack-create
description: Use when the user says "create a stacked branch", "start a new branch on top of the current one", or "add a layer to the stack" — creates a new git branch whose parent is the currently checked-out branch and registers it in the stack graph so subsequent stack-submit and stack-restack know the lineage.
when_to_use: Reach for this when starting work that should sit on top of the current branch rather than on main/master. The branch is created locally; no push or PR happens here. Do NOT use to open or refresh pull requests — stack-create only makes the branch and records the lineage; use /stack-submit to open or refresh PRs.
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
argument-hint: <new-branch-name>
scheduling: user wants a new branch stacked on the current branch, with lineage recorded in the stack graph
structural:
  - Resolve the current branch name via git symbolic-ref
  - Create the new branch with git checkout -b
  - Record the relationship in the stack graph via stack-graph.sh set
logical: the new branch exists locally, HEAD points at it, and stack-graph.json contains an entry mapping new-branch → {parent, parent_sha_at_stack_time, pr_number:null}
---

# /stack-create — Create a Stacked Branch

Create a new branch on top of the currently checked-out branch, then register the parent/child relationship in the stack graph. The PR number is left null until `/stack-submit` fills it.

## Execution Checklist

- [ ] Confirm HEAD is not detached: `git symbolic-ref --short HEAD`
- [ ] Capture the current branch name as `<current>`
- [ ] Capture the current branch tip SHA: `git rev-parse <current>`
- [ ] Create the new branch: `git checkout -b <new-branch> <current>`
- [ ] Register in the stack graph:
  ```bash
  bash plugins/stack-flow/skills/_lib/stack-graph.sh set <new-branch> <current> $(git rev-parse <current>) null
  ```
- [ ] Confirm: `bash plugins/stack-flow/skills/_lib/stack-graph.sh get <new-branch>`

## Example Pairs

### Pair 1 — branch created on a feature branch

Input:
```
Current branch: feat-auth
Command: /stack-create feat-auth-tests
```

Output (stack-graph.json entry for feat-auth-tests):
```json
{
  "parent": "feat-auth",
  "parent_sha_at_stack_time": "a3f8c21d9e04b657c12890f1234567890abcdef0",
  "pr_number": null
}
```

### Pair 2 — branch stacked on main

Input:
```
Current branch: main
Command: /stack-create feat-login
```

Output (stack-graph.json entry for feat-login):
```json
{
  "parent": "main",
  "parent_sha_at_stack_time": "b7d01f4e2a39c8556d78901e2345678901bcdef1",
  "pr_number": null
}
```

## What the Recorded SHA Means

`parent_sha_at_stack_time` is the SHA of the parent branch tip at the moment the stack relationship was created. `/stack-reparent` uses this value as the `<old-base>` argument to `git rebase --onto` when the parent branch was squash-merged and its commits now appear duplicated on the child. Without this recorded SHA, the squash-merge recovery case cannot be handled deterministically.

## Known Failure Modes

- **Detached HEAD at invocation.** `git symbolic-ref --short HEAD` exits non-zero when HEAD is detached. Stop immediately and tell the user to check out a named branch first — there is no parent to record.
- **Branch name already exists.** `git checkout -b` fails if the branch name is already in the repo. The stack graph is not modified in this case; no cleanup is needed.
