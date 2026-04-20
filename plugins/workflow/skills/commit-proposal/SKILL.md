---
name: commit-proposal
description: Apply an assessed self-evolution proposal. Snapshots the prior resource version, writes the change, appends a commit entry to the lineage ledger. Requires a prior assess verdict of pass and explicit user approval.
disable-model-invocation: true
argument-hint: <proposal-path>
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# /commit-proposal — SEPL `commit` Operator

Third of the three SEPL operators (propose → assess → **commit**). See `docs/lineage.md`.

## Preconditions

1. **Assess verdict exists and passed**. Read `.claude/lineage/ledger.jsonl` tail. The most recent entry for this resource must be an `assess` with `verdict: pass` in its evidence JSON. If missing or failing, stop. Tell the user to run `/assess-proposal` first. Do not proceed.

2. **User approval recorded**. Before mutating any file, ask the user in plain text:

   ```
   About to commit <resource> v<N> → v<N+1>. Diff preview:
   <first 20 lines of diff>
   Approve? (y/N)
   ```

   Only on explicit `y` or `yes` continue. On anything else, append a `reject` ledger entry and stop.

3. **Ledger directory exists**. `mkdir -p .claude/lineage/versions .claude/lineage/proposals`.

## Steps

### Step 1 — Resolve the resource path

Given slug `rules.d/25-brevity.txt`, map to on-disk path. Resource-kind resolution:

| Slug | Repo path |
|---|---|
| `rules.d/<f>` | `plugins/behavioral-core/hooks/rules.d/<f>` |
| `skills/<plugin>/<name>` | `plugins/<plugin>/skills/<name>/SKILL.md` |
| `hooks/<plugin>/<script>` | `plugins/<plugin>/hooks/<script>` |
| `memory/topics/<slug>` | `.claude/memory/topics/<slug>.md` |
| `env/<VAR>` | `.claude/settings.json` key `env.<VAR>` |

For unresolved slugs, stop with an error.

### Step 2 — Determine prev version

Scan the ledger for the last `commit` entry on this resource. If none, `prev = v0`. Else `prev = <that entry's version>`. Target version is `prev + 1` (e.g. `v2` → `v3`).

### Step 3 — Snapshot the current state

Copy the current resource contents to:

```
.claude/lineage/versions/<slug>/<prev-version>
```

For `env/<VAR>` slugs, write a snapshot file containing:

```
value: <current value>
source: .claude/settings.json
key: env.<VAR>
```

The snapshot MUST exist before step 4 runs. If the copy fails, stop — no ledger entry, no mutation.

### Step 4 — Apply the proposal

Read the proposal's `Proposed value` (or `Diff`) section. For file resources, use `Edit` (small diffs) or `Write` (whole-file replacements). For `env/<VAR>`, update `.claude/settings.json`. For `memory/topics/<slug>`, delegate to `/remember` which already handles version headers.

### Step 5 — Append the ledger entry

```json
{"ts":"<UTC>","operator":"commit","resource":"<slug>","version":"<target>","prev":"<prev>","trigger":"proposal:<basename>","evidence":"<proposal-path>","actor":"workflow:/commit-proposal"}
```

### Step 6 — Report

One line:

```
Committed <slug> <prev> → <target>. Rollback: /rollback <slug> <prev>
```

## Failure Modes

- Snapshot write fails → abort, no ledger entry.
- File write fails after snapshot → **restore from snapshot**, abort, no ledger entry.
- User says no → append `reject` entry, no mutation.
- Target version already exists in ledger → abort (shouldn't happen; indicates the ledger was edited). Tell the user to investigate.

## Auto-Commit Escape Hatch

If `WORKFLOW_EVOLVE_AUTOCOMMIT=1` AND `resource` starts with `env/` AND the proposal's numeric delta is within ±20% of the current value AND the verdict is `pass`, skip the approval prompt and proceed directly. Default `0`. Existence of this path is documented so users can disable it in policy. Do not extend auto-commit to file resources without user opt-in.

## Do NOT

- Do not commit without an `assess: pass` entry preceding in the ledger.
- Do not commit the same proposal twice — check the ledger for a prior `commit` with the same evidence path, and abort if found.
- Do not mutate the proposal artifact. It is the evidence of intent; it stays readable.
- Do not batch multiple slugs into one commit — one resource per commit call. The loop is deliberate.
