---
name: stack-submit
description: Use when you want to open or refresh pull requests for every branch in a stacked-PR chain — creates missing PRs with the correct base branch and refreshes the body of existing ones, then force-pushes any branch whose tip has moved.
when_to_use: Reach for this after pushing new commits to a stacked branch or when a PR body is stale and needs refreshing. It iterates every branch in the stack, opens a PR where none exists (base always set explicitly to the recorded parent, never the repo default), updates the body of existing PRs via pr-body.sh, and force-pushes moved branches via safe-push.sh. Do NOT use to rebase branches onto a new upstream — that is /stack-restack; use /stack-submit only to open/refresh PRs after the branch history is already correct.
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
argument-hint: "[<branch>]"
scheduling: user wants PRs opened or refreshed for a stacked-PR chain
structural:
  - Collect all branches in the stack via stack-graph.sh list
  - For each branch, generate the PR body via pr-body.sh
  - Push the branch via safe-push.sh first so its remote ref exists and is current
  - If no PR exists, create one with gh pr create --base <parent> --head <branch>
  - If a PR exists, refresh its body with gh pr edit --body-file -
  - Backfill the PR number into the stack graph via stack-graph.sh set
logical: every branch in the stack has an open PR whose base is its recorded parent, whose body is current, and whose remote ref matches the local branch tip
---

# /stack-submit — Open or Refresh Stacked PRs

For every branch in the stack: open a pull request targeting the recorded parent branch if none exists, or refresh the PR body if one does, then force-push any branch whose local tip differs from the remote ref.

## Invocation

```
/stack-submit
/stack-submit <branch>   # submit only from <branch> upward
```

## What it does

For each branch in stack order (base → tip):

1. Generate the PR body:
   ```bash
   bash plugins/stack-flow/skills/_lib/pr-body.sh <branch>
   ```
2. Push the branch first, so its remote ref exists and is current. `gh pr create --head`
   does not push — it requires the branch to already be on the remote — so the push has
   to precede creation. For a never-pushed branch this is the initial push; for an
   existing one it updates the moved tip:
   ```bash
   bash plugins/stack-flow/skills/_lib/safe-push.sh <branch>
   ```
3. If no PR exists, create one — base is always the recorded parent, never the repo default:
   ```bash
   bash plugins/stack-flow/skills/_lib/pr-body.sh <branch> \
     | gh pr create --base <parent> --head <branch> \
         --title "<title reflecting the change, not the branch name>" \
         --body-file -
   ```
4. If a PR already exists, refresh its body:
   ```bash
   bash plugins/stack-flow/skills/_lib/pr-body.sh <branch> \
     | gh pr edit <branch> --body-file -
   ```
5. Backfill the PR number into the stack graph:
   ```bash
   bash plugins/stack-flow/skills/_lib/stack-graph.sh set <branch> <parent> <parent-sha> <pr-number>
   ```

The parent base is read from the stack graph entry for each branch — it is never inferred from the repo default branch.

## Execution Checklist

- [ ] Run `bash plugins/stack-flow/skills/_lib/stack-graph.sh list` to enumerate all branches in the stack
- [ ] For each branch, read its recorded parent: `bash plugins/stack-flow/skills/_lib/stack-graph.sh get <branch>`
- [ ] Generate the PR body: `bash plugins/stack-flow/skills/_lib/pr-body.sh <branch>`
- [ ] Push the branch first (creates/updates the remote ref `gh pr create` needs): `bash plugins/stack-flow/skills/_lib/safe-push.sh <branch>`
- [ ] Check whether a PR already exists: `gh pr view <branch> --json number,state 2>/dev/null`
- [ ] If no PR: create it with `gh pr create --base <parent> --head <branch> --title "<purpose>" --body-file -`
- [ ] If PR exists: refresh with `gh pr edit <branch> --body-file -`
- [ ] Capture the PR number from `gh pr view <branch> --json number --jq .number`
- [ ] Backfill: `bash plugins/stack-flow/skills/_lib/stack-graph.sh set <branch> <parent> <sha> <pr-number>`
- [ ] Report a summary: branches submitted, PRs opened, PRs refreshed, pushes made

## Input / Output examples

### Pair 1 — new stack, no PRs yet

Input:
```
Stack: main → feat-auth → feat-auth-tests
feat-auth:       no PR
feat-auth-tests: no PR
```

Output (branches pushed first, then two PRs created):
```
Pushed feat-auth (initial push)
Created PR #42: "Add JWT authentication middleware" (feat-auth → main)
Pushed feat-auth-tests (initial push)
Created PR #43: "Add unit tests for auth middleware" (feat-auth-tests → feat-auth)
```

---

### Pair 2 — existing PRs, body refresh only

Input:
```
Stack: main → feat-auth → feat-auth-tests
feat-auth:       PR #42 (OPEN)
feat-auth-tests: PR #43 (OPEN)
One new commit added to feat-auth since last submit.
```

Output (bodies refreshed, feat-auth pushed):
```
Refreshed PR #42 body (feat-auth)
Pushed feat-auth (tip moved)
Refreshed PR #43 body (feat-auth-tests)
feat-auth-tests up to date, no push needed
```

## Known Failure Modes

- **PR creation fails after the push.** `safe-push.sh` and `gh pr create` are two separate calls; if creation fails after the branch is pushed, the branch exists on the remote but has no PR. Re-running `/stack-submit` sees no PR and creates it — it is idempotent.
- **Stale lease rejected.** `safe-push.sh` uses `--force-with-lease --force-if-includes`; the push fails when another process pushed to the same branch since the last fetch. Fetch first (`git fetch origin <branch>`) then re-run.
- **`gh` auth expired mid-submit.** PR creation or body refresh fails. Re-authenticate with `gh auth login` and re-run — already-created PRs are skipped (body refresh is safe to repeat).
- **Title is the branch name.** The plan requires the title to reflect the change's purpose, not the branch name. If Claude cannot determine a meaningful title from the commit log, it asks the user before creating the PR.
