# Stack Status

`/stack-status` renders a read-only view of the current stacked-PR chain: branch names, PR numbers and states (OPEN, MERGED, CLOSED), and divergence warnings wherever a branch has drifted from its recorded parent. It belongs to the `stack-flow` plugin, which provides stacked-PR creation, submission, rebasing, and re-parenting skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install stack-flow@forge-studio
```

```bash
/stack-status
```

No arguments are needed.

## Why you need it

Stacked PRs compound: a diverged middle branch cascades divergence to every branch above it, and force-pushing a re-stacked branch without knowing the PR numbers risks targeting the wrong base. Before restacking or submitting, you need an accurate picture of which branches are in sync and which are not.

`/stack-status` gives you that picture without touching any branch or remote. It queries the local stack graph for branch lineage, enriches each entry with live PR data from GitHub, and computes divergence via `git merge-base` — all read-only operations. The output tells you exactly which branches need `/stack-restack` and which are ready for `/stack-submit`.

## When to use it

- Before running `/stack-restack`, to confirm which branches are diverged and need rebasing.
- After a teammate merges upstream changes, to see the blast radius before restacking.
- When reviewing the overall shape of a stacked chain — how many branches, which PRs are open, which are merged.

Do not use it to push branches or open PRs — `/stack-status` is read-only; use `/stack-submit` or `/stack-restack` instead.

## How it works

The skill runs `stack-discovery.sh`, which reads `stack-graph.json` from `${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/<repo-key>/`, enriches each branch entry by calling `gh pr view`, and computes divergence per branch by running `stack-graph.sh diverged`. The enriched tree is printed to stdout.

```bash
bash plugins/stack-flow/skills/_lib/stack-discovery.sh
```

## Output format

```
main
└── feat-auth  [PR #42: OPEN]
    └── feat-auth-tests  [PR #43: OPEN] [DIVERGED: parent 2 ahead, branch 1 ahead]
        └── feat-auth-docs  [PR #44: OPEN]
```

Each line shows:
- Branch name, indented to reflect parent–child nesting.
- PR number and state in brackets (omitted when no PR has been opened yet).
- A `[DIVERGED: ...]` tag when `stack-graph.sh diverged <branch>` returns a non-zero commit count — this branch needs `/stack-restack` before its PR can merge cleanly.

## Examples

**Stack with three branches, all in sync:**

```
main
└── feat-login  [PR #10: OPEN]
    └── feat-login-ui  [PR #11: OPEN]
        └── feat-login-tests  [PR #12: OPEN]
```

---

**Stack where `feat-login-ui` fell behind after a teammate pushed to `feat-login`:**

```
main
└── feat-login  [PR #10: OPEN]
    └── feat-login-ui  [PR #11: OPEN] [DIVERGED: parent 3 ahead, branch 1 ahead]
        └── feat-login-tests  [PR #12: OPEN] [DIVERGED: parent 3 ahead, branch 0 ahead]
```

## Known failure modes

- **No stack graph file.** When no stacks have been registered in this repo, `stack-discovery.sh` exits with a message explaining the file was not found; no tree is printed.
- **`gh` auth expired.** PR state is omitted from the tree and a warning is printed. Branch structure and divergence flags still render from local git data only.

## Related

- [`stack-create.md`](stack-create.md) — create a new branch stacked on the current one
- [`stack-restack.md`](stack-restack.md) — rebase diverged branches onto their parents
- [`stack-submit.md`](stack-submit.md) — open or refresh PRs for the whole chain
- [Architecture](../../architecture.md) — stacked-PR orchestration in the 8-component harness model
