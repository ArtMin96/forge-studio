# Cross-Repo Workspace Ledger

Append-only JSON-lines log of every cross-repo run. One ledger per `<run-id>`.

## Location

```
~/.forge-cross-repo/<run-id>/ledger.jsonl
```

Outside the repo tree by design — cross-repo work spans repos that may not even be cloned at the same path.

## Per-line schema

```json
{"event": "<event-type>", "ts": "<ISO-8601 UTC>", "run_id": "<id>", "repo": "<basename>", "detail": "<optional>"}
```

| Event | Emitted by | Meaning |
|-------|-----------|---------|
| `start` | `/federated-fan-out` | A repo's subagent began work |
| `complete` | `/federated-fan-out` | Subagent finished cleanly (exit 0) |
| `failed` | `/federated-fan-out` | Subagent exited non-zero |
| `aggregate_complete` | `/aggregate-results` | A run's per-repo results were collected and clustered |

Additional fields by event:
- `start`: `{turn_at_open}` — turn counter at start (for handoff-style tracking parity).
- `complete`/`failed`: `{exit_code, stdout_tail, stderr_tail}`.
- `aggregate_complete`: `{repos: int, clusters: int}`.

## Invariants

1. **Append-only.** Tooling never edits or deletes prior lines. To "undo," append a new event; never rewrite.
2. **Per-repo terminal event.** Every `start` line for a repo must be followed (eventually) by exactly one of `complete` or `failed`. A run with unmatched `start` lines is in-flight or crashed.
3. **One ledger per run.** Different `<run-id>` values get different files. Never share a ledger across runs.
4. **Outside the repo tree.** `~/.forge-cross-repo/` is user-scoped, not repo-scoped. Cross-repo state should not leak into any single repo's git history.

## Retention

User-managed. Tooling never auto-deletes. To clean up old runs:

```bash
rm -rf ~/.forge-cross-repo/<old-run-id>/
```

Or sweep all runs older than 30 days:

```bash
find ~/.forge-cross-repo -maxdepth 1 -mindepth 1 -type d -mtime +30 -exec rm -rf {} +
```

## Reading the ledger

Quick run summary:

```bash
jq -r '. | "\(.ts) \(.event) \(.repo // "")"' < ~/.forge-cross-repo/<run-id>/ledger.jsonl
```

Find unfinished repos in a run:

```bash
jq -s '
  group_by(.repo) | map(select(.[-1].event == "start")) | .[] | .[0].repo
' < ~/.forge-cross-repo/<run-id>/ledger.jsonl
```

## Composition

The ledger is the handoff artifact between `/federated-fan-out` (writes `start` + terminal events) and `/aggregate-results` (reads them, writes `aggregate_complete`). Treat it like the in-repo `.claude/lineage/ledger.jsonl` — the source of truth for what happened in this run.
