# `_lib` — Shared Helpers

Cross-plugin utilities that don't belong to any single plugin's lifecycle. Underscore prefix sorts ahead of plugin directories and signals "not a plugin."

## Helpers

| Script | Contract | Used by |
|---|---|---|
| `jsonl-append.sh <ledger> <json-line>` | Atomic append with flock; falls back to bare append where flock is absent | `consecutive-failure-guard.sh`, `scan-injection.sh`, `scan-secrets.sh`, `audit-sensitive-ops.sh`, `route-prompt.sh` |
