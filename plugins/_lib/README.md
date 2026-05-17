# `_lib` — Shared Helpers

Cross-plugin utilities that don't belong to any single plugin's lifecycle. Underscore prefix sorts ahead of plugin directories and signals "not a plugin."

## Helpers

| Script | Contract | Used by |
|---|---|---|
| `jsonl-append.sh [--with-turn-id] <ledger> <json-line>` | Atomic append with flock; `--with-turn-id` (optional) reads hook payload from stdin and injects `turn_id` into the JSON line, preserving any caller-supplied value | `consecutive-failure-guard.sh`, `scan-injection.sh`, `scan-secrets.sh`, `audit-sensitive-ops.sh`, `route-prompt.sh` |
| `turn-id.sh --from-stdin` | Reads hook JSON payload on stdin and emits `<session_id>-<ppid-or-ms-timestamp>` for cross-ledger correlation | `jsonl-append.sh` (internally), `collect-*.sh` trace collectors |
