# Stack Create

`/stack-create <new-branch-name>` creates a new git branch whose parent is the currently checked-out branch and registers the parent–child relationship in the stack graph. No push or PR happens here — the branch is local until `/stack-submit` pushes it. It belongs to the `stack-flow` plugin, which provides stacked-PR creation, submission, rebasing, and re-parenting skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install stack-flow@forge-studio
```

```bash
/stack-create <new-branch-name>
```

## Why you need it

A stacked-PR workflow depends on knowing the exact parent–child relationship between branches. If you create branches with plain `git checkout -b`, subsequent skills like `/stack-restack` and `/stack-reparent` have no lineage to work from and cannot rebase the chain correctly. `/stack-create` wires the relationship into the stack graph at branch creation time, so every later operation has the data it needs.

The recorded `parent_sha_at_stack_time` — the tip SHA of the parent at the moment the child was created — is particularly important for the squash-merge recovery case. When the parent is squash-merged into main, `/stack-reparent` uses that SHA to isolate exactly the child's own commits via `git rebase --onto`. Without it, that recovery is not deterministic.

## When to use it

- Starting a new branch that should build on top of the current branch rather than on main.
- Layering a related change (tests, docs, follow-up refactor) on top of a feature branch already in review.

Do not use it to open or refresh pull requests — `/stack-create` only creates the branch and records the lineage; use `/stack-submit` to open or refresh PRs.

## How it works

1. Resolves the current branch name via `git symbolic-ref --short HEAD`.
2. Creates the new branch with `git checkout -b <new-branch> <current>`.
3. Records the relationship in the stack graph:

```bash
bash plugins/stack-flow/skills/_lib/stack-graph.sh set \
  <new-branch> <current> $(git rev-parse <current>) null
```

`stack-graph.json` is written to `${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/<repo-key>/`. The PR number field is `null` until `/stack-submit` backfills it.

## Examples

### Branch created on top of a feature branch

Input:
```
Current branch: feat-auth
Command: /stack-create feat-auth-tests
```

Stack graph entry written for `feat-auth-tests`:
```json
{
  "parent": "feat-auth",
  "parent_sha_at_stack_time": "a3f8c21d9e04b657c12890f1234567890abcdef0",
  "pr_number": null
}
```

---

### Branch stacked directly on main

Input:
```
Current branch: main
Command: /stack-create feat-login
```

Stack graph entry written for `feat-login`:
```json
{
  "parent": "main",
  "parent_sha_at_stack_time": "b7d01f4e2a39c8556d78901e2345678901bcdef1",
  "pr_number": null
}
```

## Known failure modes

- **Detached HEAD at invocation.** `git symbolic-ref --short HEAD` exits non-zero when HEAD is detached. Stop immediately and check out a named branch first — there is no parent to record.
- **Branch name already exists.** `git checkout -b` fails if the name is already in the repository. The stack graph is not modified; no cleanup is needed.

## Related

- [`stack-status.md`](stack-status.md) — inspect the chain after creating branches
- [`stack-submit.md`](stack-submit.md) — open PRs once the branch is ready for review
- [`stack-reparent.md`](stack-reparent.md) — recover the child after the parent is squash-merged; uses the `parent_sha_at_stack_time` recorded here
- [Architecture](../../architecture.md) — stacked-PR orchestration in the 8-component harness model
