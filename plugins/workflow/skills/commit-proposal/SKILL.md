---
name: commit-proposal
description: Use to apply an assessed self-evolution proposal — snapshots the prior resource version under `.claude/lineage/versions/`, writes the new content, and appends a commit entry to the ledger. Refuses to run unless the most recent `assess` verdict is `pass` and the user has explicitly approved.
when_to_use: Reach for this only after `/evolve` has produced a proposal and `/assess-proposal` has returned `pass`, with explicit user approval to ship. Do NOT use to undo a prior commit — that's `/rollback`; do NOT use for plain git commits — this is the SEPL operator that mutates versioned harness resources only.
disable-model-invocation: true
argument-hint: <proposal-path>
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
logical: snapshot exists at .claude/lineage/versions/<slug>/<prev>; resource updated; commit ledger entry appended
---

# /commit-proposal — SEPL `commit` Operator

Third of the three SEPL operators (propose → assess → **commit**). See `docs/self-evolution.md`.

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

```text
.claude/lineage/versions/<slug>/<prev-version>
```

For `env/<VAR>` slugs, write a snapshot file containing:

```yaml
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

```text
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

## Execution Checklist

- [ ] Read the proposal at `<proposal-path>` and extracted `resource`, `version`, content
- [ ] Confirmed the most recent ledger entry for this `(resource, version)` is `assess` with verdict `pass`
- [ ] Confirmed explicit user approval (or `WORKFLOW_EVOLVE_AUTOCOMMIT=1` conditions are all met)
- [ ] Snapshotted the prior content to `.claude/lineage/versions/<slug>/<prev-version>`
- [ ] Wrote new content to the resource's actual path
- [ ] Appended a `commit` ledger entry with the proposal path as `evidence`
- [ ] Verified post-conditions: snapshot file exists, ledger entry parses, target file matches the proposal

## Examples

### Example 1: Rule addition

Input:
```yaml
proposal: .claude/lineage/proposals/2026-04-28-no-hardcoded-paths.md
resource: rules.d/95-no-hardcoded-paths.txt
version:  v1
prev:     v0
content:  "Avoid hardcoded absolute paths in source. Use repo-relative or env-var-resolved paths so the harness moves between machines without edits."
```

Output:
```json
{"ts":"2026-04-28T14:02:11Z","operator":"commit","resource":"rules.d/95-no-hardcoded-paths.txt","version":"v1","prev":"v0","evidence":".claude/lineage/proposals/2026-04-28-no-hardcoded-paths.md"}
```
Side effect: `.claude/lineage/versions/rules.d/95-no-hardcoded-paths.txt/v0` snapshotted (empty); the live rule file written.

### Example 2: Auto-commit env tweak

Input:
```yaml
proposal: .claude/lineage/proposals/2026-04-28-bump-pressure-threshold.md
resource: env/FORGE_CONTEXT_PRESSURE_THRESHOLD
version:  v3   (numeric: 0.65 → 0.70, +7.7%)
prev:     v2
mode:     WORKFLOW_EVOLVE_AUTOCOMMIT=1
```

Output:
```json
{"ts":"2026-04-28T14:05:32Z","operator":"commit","resource":"env/FORGE_CONTEXT_PRESSURE_THRESHOLD","version":"v3","prev":"v2","auto":true,"evidence":".claude/lineage/proposals/2026-04-28-bump-pressure-threshold.md"}
```
No approval prompt because the auto-commit path applies (env-only, ≤±20% delta, verdict was `pass`).
