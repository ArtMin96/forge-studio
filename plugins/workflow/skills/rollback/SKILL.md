---
name: rollback
description: Reverse a prior self-evolution commit. Restores a snapshot from .claude/lineage/versions/ and appends a rollback entry to the ledger. Itself logged — history is append-only.
disable-model-invocation: true
argument-hint: <resource-slug> [target-version]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# /rollback — Reverse a Commit

Fourth operator (alongside propose/assess/commit). See `docs/lineage.md` §Operator Semantics.

## Input

- `<resource-slug>` — required. Same slug format as commit (`rules.d/<f>`, `skills/<p>/<n>`, `env/<VAR>`, etc.).
- `[target-version]` — optional. Default: the most recent snapshotted version (i.e. the one replaced by the latest commit).

## Preconditions

1. Ledger has a `commit` entry for this resource.
2. Snapshot file exists at `.claude/lineage/versions/<slug>/<target-version>`.
3. User confirms. Show a diff preview (current → target) and ask `y/N`.

If any precondition fails, stop and report the specific gap.

## Steps

### Step 1 — Resolve paths

Same slug → on-disk path mapping as `/commit-proposal` (see that skill for the table).

### Step 2 — Snapshot the current state first

Before restoring, copy current contents to `.claude/lineage/versions/<slug>/<current-version>` if not already present. Rollbacks are commits in reverse — the forward state must also be snapshotted so a subsequent `/rollback` can restore it.

Example: current is v3, user rolls back to v2. Snapshot v3 → versions dir. Then restore v2 from versions dir.

### Step 3 — Restore

For file resources, `Write` the snapshot contents over the live file. For `env/<VAR>`, parse the snapshot's `value:` line and write it back into `.claude/settings.json`.

### Step 4 — Append ledger entry

```json
{"ts":"<UTC>","operator":"rollback","resource":"<slug>","version":"<target-version>","prev":"<current-version>","trigger":"user","evidence":".claude/lineage/versions/<slug>/<target-version>","actor":"workflow:/rollback"}
```

### Step 5 — Report

```
Rolled back <slug> <current> → <target>. Forward version snapshot saved: /rollback <slug> <current>
```

The report hints at the re-roll-forward path: the user can `/rollback` back to the version they just rolled out of.

## Failure Modes

- No commit found for this resource → "nothing to roll back" message.
- Snapshot file missing → `/entropy-scan` should have caught this; tell the user to investigate manually. Do not fabricate a version.
- Current contents already match target snapshot → no-op, report that and skip the ledger write.

## Do NOT

- Do not delete snapshot files. They are the append-only history. Cleanup is a separate concern (not implemented in v1).
- Do not roll back to a version that has no snapshot file — the `v0` state (original shipped file) is not automatically snapshotted. Use git for pre-evolution history.
- Do not rollback batch. One resource per call.
