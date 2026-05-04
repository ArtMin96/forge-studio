---
name: lineage-audit
description: Audit .claude/lineage/ledger.jsonl for protocol invariants — operator sequence, registry slugs, snapshot presence, append-only discipline. Reports only.
when_to_use: Reach for this before trusting the SEPL ledger as evidence (e.g., before a `/rollback`), after a suspected crash during `/commit-proposal` or `/rollback`, or on a monthly sanity-check schedule. Do NOT use to validate marketplace or harness drift — that's `/entropy-scan` and `/validate-marketplace`; lineage-audit only inspects `.claude/lineage/`.
paths:
  - ".claude/lineage/*"
  - ".claude/lineage/ledger.jsonl"
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
logical: report shows CLEAN or {N} violations per check (parse / operators / slugs / snapshots / post-reject)
---

# Lineage Audit — Ledger Invariant Check

Read-only inspection of the self-evolution ledger. Verifies the invariants in `HARNESS_SPEC.md` §Self-Evolution Protocol and `docs/self-evolution.md`. Does not modify the ledger.

## When to Use

- Before relying on the ledger as evidence (e.g. before a rollback)
- After a suspected crash during `/commit-proposal` or `/rollback`
- Periodic sanity check (monthly)
- When `/entropy-scan` reports a lineage-related finding

## Instructions

Run the six checks below. Report structured findings. Never write to `.claude/lineage/` from this skill.

All check scripts accept the ledger path as `$1`, defaulting to `.claude/lineage/ledger.jsonl`.

### Check 1 — Ledger Exists and Parses

```bash
LEDGER=".claude/lineage/ledger.jsonl"
test -f "$LEDGER" || { echo "N/A — no ledger yet"; exit 0; }
python3 plugins/memory/skills/lineage-audit/scripts/check-parse.py "$LEDGER"
```

### Check 2 — Operator Values

Every entry's `operator` must be one of `propose`, `assess`, `commit`, `reject`, `rollback`.

```bash
python3 plugins/memory/skills/lineage-audit/scripts/check-operators.py "$LEDGER"
```

### Check 3 — Resource Slug Format

Every `resource` must match one of the registry slug patterns:

- `rules.d/<filename>`
- `skills/<plugin>/<name>`
- `hooks/<plugin>/<script>`
- `memory/topics/<slug>`
- `env/<VAR>`

```bash
python3 plugins/memory/skills/lineage-audit/scripts/check-slugs.py "$LEDGER"
```

### Check 4 — Commit Preconditions

Every `commit` entry must have an earlier `propose` and an `assess` with `verdict: pass` on the same `resource` and target `version`. When the verdict lives only in the evidence file (not on the ledger entry), the check reports `unverified` rather than `violation` — manual inspection required.

```bash
python3 plugins/memory/skills/lineage-audit/scripts/check-commit-preconditions.py "$LEDGER"
```

### Check 5 — Snapshot Files On Disk

Every `commit` and `rollback` must have a snapshot file at `.claude/lineage/versions/<slug>/<prev-or-target>`.

```bash
python3 plugins/memory/skills/lineage-audit/scripts/check-snapshots.py "$LEDGER"
```

### Check 6 — Post-Reject Commit

A `reject` on a `(resource, version)` pair should prevent a subsequent `commit` for the same pair unless a new `propose`+`assess` sequence follows.

```bash
python3 plugins/memory/skills/lineage-audit/scripts/check-post-reject.py "$LEDGER"
```

## Output Format

```markdown
## Lineage Audit

Ledger: .claude/lineage/ledger.jsonl
Entries scanned: {N}

### Check 1 — Parse
Status: {CLEAN / {N} bad lines}
{line numbers and errors if any}

### Check 2 — Operator Values
Status: {CLEAN / {N} violations}
{offending entries if any}

### Check 3 — Resource Slugs
Status: {CLEAN / {N} violations}
{offending entries if any}

### Check 4 — Commit Preconditions
Status: {CLEAN / {N} violations / {N} unverified}
{details}

### Check 5 — Snapshots
Status: {CLEAN / {N} missing}
{missing paths if any}

### Check 6 — Post-Reject Commits
Status: {CLEAN / {N} violations}
{details}

### Summary
Overall: {CLEAN / {N} issues}
{One-line fix suggestion per issue kind}
```

## Rules

- This skill never modifies the ledger, snapshots, or the `.claude/lineage/` tree.
- If the ledger does not exist, report "N/A — no ledger yet" and exit.
- Unverified checks (e.g., verdict not in-line) are reported separately from violations. Do not conflate them.
- If a violation is found, suggest the manual remediation but do not apply it. Repairing the ledger is a deliberate human action.
