# cross-repo

Parallel work across sibling repos with result aggregation. Use when the same operation must be applied to 2-5 independent sibling repos, or when you need to compare code patterns across repos.

## Skills

| Skill | What it does |
|-------|-------------|
| `/federated-fan-out` | Spawn one subagent per repo (≤5) with a shared prompt template; capture per-repo results under `~/.forge-cross-repo/<run-id>/` |
| `/sync-discovery` | Search a pattern in two repos; classify matches as only-in-a, only-in-b, or in-both (with divergence flag) |
| `/aggregate-results` | Collect per-repo `result.json` files from a fan-out run; de-dup by content hash; emit verdict matrix and `aggregated.json` |

## When to use

- Applying a convention change, security patch, or audit across a monorepo group of sibling repos
- Checking whether a utility function in repo-A has been copied (and diverged) into repo-B
- Reviewing the results of a multi-repo fan-out run in one place

## Workspace ledger

All cross-repo runs write append-only ledger entries to `~/.forge-cross-repo/<run-id>/ledger.jsonl`. See [LEDGER.md](LEDGER.md) for the format.

## Architecture

See [docs/architecture.md](../../docs/architecture.md) for how cross-repo fits into the orchestration harness component.
