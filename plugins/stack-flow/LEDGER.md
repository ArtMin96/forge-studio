# Stack-Flow Ops Log

Append-only JSON-lines log of every stack operation in a repo. One log per `<repo-key>`.

## Location

```
${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/ops.jsonl
```

`<repo-key>` is a 12-hex-character SHA derived from `remote.origin.url` (or the repo root path as fallback) by `skills/_lib/repo-key.sh`. It is stable across machines that clone the same remote. The `stack-flow/` segment is always present — the log is never written directly under `${CLAUDE_PLUGIN_DATA}/<repo-key>/`.

## Per-line schema

Each line is one JSON object. All entries share:

| Field | Type | Meaning |
|-------|------|---------|
| `op` | string | Operation name (see table below) |
| `ts` | string | ISO-8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`) |
| `result` | string | Outcome of the operation |

Additional fields vary by op:

### `restack`

Emitted by `skills/_lib/restack.sh`. Fires once per invocation, including conflict aborts.

```json
{"op":"restack","branch":"feat-b","base":"feat-a","result":"ok","moved":["feat-a","feat-b"],"ts":"2026-05-29T10:00:00Z"}
{"op":"restack","branch":"feat-b","base":"feat-a","result":"conflict","ts":"2026-05-29T10:05:00Z"}
```

| Field | Type | Values / Meaning |
|-------|------|-----------------|
| `branch` | string | Tip of the stack that was rebased |
| `base` | string | Upstream branch used for the rebase |
| `result` | string | `ok` — rebase completed; `conflict` — rebase failed, state aborted |
| `moved` | array of strings | Branches whose SHAs changed (present only when `result` is `ok`) |

### `safe-push`

Emitted by `skills/_lib/safe-push.sh`. Fires once per branch push attempt.

```json
{"op":"safe-push","branch":"feat-a","result":"ok","ts":"2026-05-29T10:01:00Z"}
{"op":"safe-push","branch":"feat-a","result":"failed","ts":"2026-05-29T10:06:00Z"}
```

| Field | Type | Values / Meaning |
|-------|------|-----------------|
| `branch` | string | Branch that was pushed |
| `result` | string | `ok` — push succeeded; `failed` — push exited non-zero |

### `onto-reparent`

Emitted by `skills/_lib/onto-reparent.sh`. Fires once per re-parent attempt, including pre-flight failures.

```json
{"op":"onto-reparent","child":"feat-b","new_base":"main","old_base_sha":"abc1234","result":"ok","ts":"2026-05-29T10:02:00Z"}
{"op":"onto-reparent","child":"feat-b","new_base":"main","old_base_sha":"abc1234","result":"conflict","ts":"2026-05-29T10:07:00Z"}
```

| Field | Type | Values / Meaning |
|-------|------|-----------------|
| `child` | string | Branch being re-parented |
| `new_base` | string | New base branch (e.g. `main` after a squash-merge) |
| `old_base_sha` | string | SHA of the old parent at stack-create time (the `--onto` upstream) |
| `result` | string | `ok` — rebase + PR retarget succeeded; `conflict` — rebase failed, state aborted; `ancestor-check-failed` — `old_base_sha` not reachable from `child`; `pr-edit-failed` — rebase succeeded but `gh pr edit --base` failed |

### `pr-body`

Emitted by `skills/_lib/pr-body.sh`. Fires once per PR body generation.

```json
{"op":"pr-body","branch":"feat-a","source":"template:.github/pull_request_template.md","ts":"2026-05-29T10:03:00Z"}
{"op":"pr-body","branch":"feat-a","source":"fallback","ts":"2026-05-29T10:04:00Z"}
```

| Field | Type | Values / Meaning |
|-------|------|-----------------|
| `branch` | string | Branch the PR body was generated for |
| `source` | string | `template:<path>` — a repo template was used; `fallback` — no template found, structured fallback emitted |

### `stack-discovery`

Emitted by `skills/_lib/stack-discovery.sh`. Fires once per stack-status view.

```json
{"op":"stack-discovery","branch_count":3,"gh_available":true,"ts":"2026-05-29T10:00:00Z"}
```

| Field | Type | Values / Meaning |
|-------|------|-----------------|
| `branch_count` | integer | Number of branches in the stack graph at time of call |
| `gh_available` | boolean | Whether `gh` was authenticated and reachable; if `false`, PR state is omitted from the tree |

## Invariants

1. **Append-only.** Writes go through `plugins/_lib/jsonl-append.sh` to avoid torn lines under concurrent writes. Never truncate or rewrite prior lines.
2. **One log per repo.** Each `<repo-key>` gets its own file. Different repos do not share a log.
3. **Fires on every outcome.** Conflict aborts and pre-flight failures write an entry (with a non-`ok` `result`) so the log reflects every attempt, not only successes.
4. **`jq`-formatted.** All entries are produced by `jq -nc` — no string-concatenation JSON. Field values may contain `/`, `"`, and other characters that would break naive string concat.

## Retention

User-managed. Tooling never auto-deletes. To remove a repo's log:

```bash
rm -rf "${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/"
```

## Reading the log

Recent ops for a repo:

```bash
jq -r '"\(.ts) \(.op) \(.result)"' "${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/ops.jsonl"
```

All conflict or failure entries:

```bash
jq 'select(.result != "ok")' "${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/ops.jsonl"
```

Restack ops that moved specific branches:

```bash
jq 'select(.op == "restack" and (.moved // [] | contains(["feat-b"])))' \
  "${CLAUDE_PLUGIN_DATA}/stack-flow/<repo-key>/ops.jsonl"
```
