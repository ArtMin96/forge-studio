# Stack Submit

`/stack-submit` opens or refreshes pull requests for every branch in a stacked-PR chain. For each branch it generates a PR body, pushes the branch so its remote ref is current, creates a PR if none exists (with the base set to the recorded parent, never the repo default), or refreshes the body of an existing PR. It belongs to the `stack-flow` plugin, which provides stacked-PR creation, submission, rebasing, and re-parenting skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install stack-flow@forge-studio
```

```bash
/stack-submit
/stack-submit <branch>   # submit only from <branch> upward in the stack
```

## Why you need it

Stacked PRs require each PR to target the right base branch — the branch directly below it in the stack, not `main`. Manually creating PRs with `gh pr create` and remembering to set `--base` correctly for each layer is error-prone, especially after restacking when tips move. `/stack-submit` reads the recorded parent from the stack graph for every branch, so the bases are always correct regardless of how many layers the stack has.

The skill is also idempotent: if a PR already exists, it refreshes the body rather than creating a duplicate. If the branch tip has moved, it force-pushes first so the remote ref is current before any GitHub API call.

## When to use it

- After committing to one or more stacked branches and wanting to open or update their PRs in one pass.
- After running `/stack-restack`, to update the PR bodies to reflect the rebased history.
- When a PR body is stale and needs to reflect new commits.

Do not use it to rebase branches onto a new upstream — that is `/stack-restack`. Use `/stack-submit` only when the branch history is already correct and you want PRs opened or refreshed.

## How it works

For each branch in stack order (base → tip):

1. Generate the PR body:
   ```bash
   bash plugins/stack-flow/skills/_lib/pr-body.sh <branch>
   ```
2. Push the branch so its remote ref exists and is current. `gh pr create --head` requires the branch to be on the remote before creation, so the push precedes it:
   ```bash
   bash plugins/stack-flow/skills/_lib/safe-push.sh <branch>
   ```
   `safe-push.sh` runs `git push --force-with-lease --force-if-includes origin <branch>`. `--force-with-lease` compares against the local remote-tracking ref; `--force-if-includes` closes the stale-local-ref hole by requiring the remote-tracking ref to be in the local reflog.
3. If no PR exists, create one — base is the recorded parent, never the repo default:
   ```bash
   bash plugins/stack-flow/skills/_lib/pr-body.sh <branch> \
     | gh pr create --base <parent> --head <branch> \
         --title "<purpose of the change>" --body-file -
   ```
4. If a PR exists, refresh its body:
   ```bash
   bash plugins/stack-flow/skills/_lib/pr-body.sh <branch> \
     | gh pr edit <branch> --body-file -
   ```
5. Backfill the PR number into the stack graph:
   ```bash
   bash plugins/stack-flow/skills/_lib/stack-graph.sh set \
     <branch> <parent> <parent-sha> <pr-number>
   ```

## Examples

### New stack — no PRs yet

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

### Existing PRs — body refresh only

Input:
```
Stack: main → feat-auth → feat-auth-tests
feat-auth:       PR #42 (OPEN)
feat-auth-tests: PR #43 (OPEN)
One new commit added to feat-auth since last submit.
```

Output (bodies refreshed, feat-auth pushed):
```
Pushed feat-auth (tip moved)
Refreshed PR #42 body (feat-auth)
feat-auth-tests up to date, no push needed
Refreshed PR #43 body (feat-auth-tests)
```

## Known failure modes

- **PR created but body refresh fails mid-stack.** `safe-push.sh` and `gh pr create` are separate calls. If creation fails after the branch is pushed, the branch exists on the remote but has no PR. Re-running `/stack-submit` is safe — it sees no PR and creates one.
- **Stale lease rejected on push.** `safe-push.sh` fails when another process pushed to the same branch since the last fetch. Fetch first (`git fetch origin <branch>`) then re-run.
- **`gh` auth expired mid-submit.** PR creation or body refresh fails. Re-authenticate with `gh auth login` and re-run — already-created PRs are skipped on the next pass.
- **PR title is the branch name.** The title should reflect the change's purpose. When Claude cannot determine a meaningful title from the commit log, it asks before creating the PR.

## Related

- [`stack-status.md`](stack-status.md) — inspect the chain before submitting
- [`stack-restack.md`](stack-restack.md) — rebase diverged branches before submitting
- [`stack-create.md`](stack-create.md) — create stacked branches whose lineage this skill reads
- [Architecture](../../architecture.md) — stacked-PR orchestration in the 8-component harness model
