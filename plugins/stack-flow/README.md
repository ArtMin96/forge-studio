# stack-flow

Native-git stacked-PR management. Keeps a branch tree synchronized as parent branches evolve, guards against wrong-branch pushes, and produces clean PR bodies — all without a third-party stacking binary.

## What it does

Sits between the developer and git, providing three layers of safety:

1. A `PreToolUse` guard blocks any `git push` that targets a branch other than the current one, any detached-HEAD push, any bare `--force`/`-f` push, and any whole-remote or deletion push (`--mirror`, `--all`, `--delete`, `:<branch>`) — directing Claude to the skill that does the safe equivalent instead. (`git push origin HEAD` is allowed: `HEAD` resolves to the current branch.)
2. A `SessionStart` hook emits the current branch and its stack position so Claude always knows where it sits in the tree.
3. Skills for reading the stack, creating stacked branches, submitting PRs, restacking after a parent update, and re-parenting after a squash merge — each built on `git rebase --update-refs`, `git rebase --onto`, and `gh`, with force-pushes done safely via `--force-with-lease --force-if-includes`.

Stack state (parent relationships, pre-merge SHAs, PR numbers) is persisted in `${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/` so the squash-merge re-parent case is always recoverable.

## Skills

| Skill | What it does |
|-------|-------------|
| `/stack-status` | Print the current stack tree: each branch, its PR number/state, and a "needs restack" flag where divergence > 0. Read-only. |
| `/stack-create` | Create a new branch stacked on HEAD and register it in the stack graph. |
| `/stack-submit` | Open or refresh PRs for each branch in the stack; force-push moved branches safely. |
| `/stack-restack` | Run `git rebase --update-refs` from a branch, identify which children moved, and safe-push each one. |
| `/stack-reparent` | Re-parent a child branch whose parent was squash-merged into the base, using `git rebase --onto` and the recorded pre-merge SHA. |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `PreToolUse` (`Bash`) | guard-push | Block wrong-branch, detached-HEAD, bare `--force`, and whole-remote/deletion (`--mirror`/`--all`/`--delete`/`:<branch>`) pushes. Emits `permissionDecision: deny` JSON + exit 0. |
| `SessionStart` | session-context | Print current branch and stack position; verify `git >= 2.38` and `gh` are available. |

## State

All mutable state lives under `${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/`:

```text
stack-graph.json   branch → {parent, parent_sha_at_stack_time, pr_number}
ops.jsonl          append-only log of restack/submit/reparent operations
```

`<repo-key>` is derived from the `origin` remote URL (SHA1 hash), falling back to the repo toplevel path when no remote is configured. See [LEDGER.md](LEDGER.md) for the ops-log schema.

## Disable

`/plugin disable stack-flow@forge-studio`. The push guard goes silent; bare `--force` pushes to wrong branches become possible again.
