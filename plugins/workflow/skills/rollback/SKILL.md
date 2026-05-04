---
name: rollback
description: Use to reverse a prior self-evolution commit — restores a snapshot from `.claude/lineage/versions/<slug>/<version>` and appends a rollback entry to the ledger. The rollback itself is logged so history stays append-only and auditable.
when_to_use: Reach for this when a recent `/commit-proposal` produced a regression, when `/lineage-audit` flags a bad commit, or when reverting to a known-good resource version. Do NOT use to undo an arbitrary working-tree change — that's `git`; rollback only reverses versioned harness resources tracked in the lineage ledger.
disable-model-invocation: true
argument-hint: <resource-slug> [target-version]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
logical: resource restored from snapshot; rollback ledger entry appended; forward snapshot saved for re-roll
---

# /rollback — Reverse a Commit

Fourth operator (alongside propose/assess/commit). See `docs/self-evolution.md` §The Four Operators.

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

```text
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

## Execution Checklist

- [ ] Read the resource slug and target version from arguments
- [ ] Confirmed `.claude/lineage/versions/<slug>/<target>` exists (otherwise abort with the entropy-scan hint)
- [ ] Compared current file content to the snapshot — if identical, report no-op and exit
- [ ] Restored the snapshot to the resource's actual path
- [ ] Appended a `rollback` entry to the ledger with the prior version recorded
- [ ] Reported the rollback + the re-roll-forward path the user can take next
