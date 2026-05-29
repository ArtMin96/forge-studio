---
name: stack-status
description: Use when you want a read-only view of the current stacked-PR chain — which branches are in the stack, their PR numbers and states (OPEN, MERGED, CLOSED), and which branches have diverged from their parent and need a restack. Renders the full tree without touching any branch or remote.
when_to_use: Reach for this before deciding whether to restack or submit — it tells you exactly where divergence is so you can act on facts, not guesses. Also useful after a teammate merges upstream changes and you want to see the blast radius before running restack. Do NOT use to push or restack — stack-status is read-only; use /stack-submit or /stack-restack instead.
context: fork
agent: Explore
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Read
scheduling: user wants to know the current state of a stacked-PR chain (branch names, PR numbers, divergence) without modifying any branch or remote
structural:
  - Locate the stack graph for this repo via stack-discovery.sh
  - Enrich each branch with live PR number and state from gh
  - Compute divergence for each branch against its parent
  - Render the tree with DIVERGED flags where divergence > 0
logical: tree is printed with every branch in the stack, its PR number/state, and a DIVERGED flag on every branch whose git merge-base count > 0; no writes occur
---

# /stack-status — Stack Tree Inspector

Show the full stacked-PR chain for the current repo: branch names, PR numbers, open/merged/closed states, and divergence warnings wherever a branch has drifted from its parent.

## Invocation

```
/stack-status
```

No arguments needed. The skill reads the local stack graph and queries GitHub for live PR state.

## What it does

```bash
bash plugins/stack-flow/skills/_lib/stack-discovery.sh
```

`stack-discovery.sh` reads `stack-graph.json` from `${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/stack-flow/<repo-key>/`, enriches each branch entry with `gh pr view` output, and computes divergence via `stack-graph.sh diverged`. It then emits the tree to stdout.

## Output format

```
main
└── feat-auth  [PR #42: OPEN]
    └── feat-auth-tests  [PR #43: OPEN] [DIVERGED: parent 2 ahead, branch 1 ahead]
        └── feat-auth-docs  [PR #44: OPEN]
```

Each line shows:
- Branch name and indentation reflecting parent–child nesting
- PR number and state in brackets (omitted if no PR has been created yet)
- A `[DIVERGED: ...]` tag when `stack-graph.sh diverged <branch>` returns a non-zero commit count — this branch needs `/stack-restack` before its PR can merge cleanly

## Execution Checklist

- [ ] Run `bash plugins/stack-flow/skills/_lib/stack-discovery.sh` and capture stdout
- [ ] Confirm the tree root is the base branch (typically `main` or `master`)
- [ ] Identify every branch tagged `[DIVERGED: ...]` — list them for the user
- [ ] If `gh` is unavailable, note that PR state is omitted and the tree still shows branch structure and divergence flags
- [ ] Report the summary: total branches in stack, number with open PRs, number diverged

## Input / Output examples

**Input:** Stack with three branches, all in sync.

**Output:**
```
main
└── feat-login  [PR #10: OPEN]
    └── feat-login-ui  [PR #11: OPEN]
        └── feat-login-tests  [PR #12: OPEN]
```

---

**Input:** Stack where `feat-login-ui` has fallen behind its parent after a teammate pushed to `feat-login`.

**Output:**
```
main
└── feat-login  [PR #10: OPEN]
    └── feat-login-ui  [PR #11: OPEN] [DIVERGED: parent 3 ahead, branch 1 ahead]
        └── feat-login-tests  [PR #12: OPEN] [DIVERGED: parent 3 ahead, branch 0 ahead]
```

## Known Failure Modes

- When the stack graph file is missing (no stacks registered yet), `stack-discovery.sh` exits with a message explaining the file was not found; no tree is printed.
- When `gh` auth is expired, PR state is omitted from the tree and a warning is printed; branch structure and divergence flags still render from local git data.
