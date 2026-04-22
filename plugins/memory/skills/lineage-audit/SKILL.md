---
name: lineage-audit
description: Audit .claude/lineage/ledger.jsonl for protocol invariants — operator sequence, registry slugs, snapshot presence, append-only discipline. Reports only.
when_to_use: Before trusting self-evolution history, diagnosing a rollback failure, or as a periodic sanity check.
paths:
  - ".claude/lineage/*"
  - ".claude/lineage/ledger.jsonl"
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
---

# Lineage Audit — Ledger Invariant Check

Read-only inspection of the self-evolution ledger. Verifies the invariants in `HARNESS_SPEC.md` §Self-Evolution Protocol and `docs/lineage.md`. Does not modify the ledger.

## When to Use

- Before relying on the ledger as evidence (e.g. before a rollback)
- After a suspected crash during `/commit-proposal` or `/rollback`
- Periodic sanity check (monthly)
- When `/entropy-scan` reports a lineage-related finding

## Instructions

Run the six checks below. Report structured findings. Never write to `.claude/lineage/` from this skill.

### Check 1 — Ledger Exists and Parses

```bash
LEDGER=".claude/lineage/ledger.jsonl"
test -f "$LEDGER" || { echo "N/A — no ledger yet"; exit 0; }

# Every line must be valid JSON
python3 -c "
import json, sys
bad = []
for i, line in enumerate(open('$LEDGER'), 1):
    line = line.strip()
    if not line: continue
    try: json.loads(line)
    except Exception as e: bad.append((i, str(e)))
print('BAD_LINES:', bad if bad else 'none')
"
```

### Check 2 — Operator Values

Every entry's `operator` must be one of `propose`, `assess`, `commit`, `reject`, `rollback`.

```bash
python3 -c "
import json
allowed = {'propose','assess','commit','reject','rollback'}
bad = []
for i, line in enumerate(open('$LEDGER'), 1):
    line = line.strip()
    if not line: continue
    e = json.loads(line)
    op = e.get('operator')
    if op not in allowed: bad.append((i, op))
print('BAD_OPERATORS:', bad if bad else 'none')
"
```

### Check 3 — Resource Slug Format

Every `resource` must match one of the registry slug patterns:

- `rules.d/<filename>`
- `skills/<plugin>/<name>`
- `hooks/<plugin>/<script>`
- `memory/topics/<slug>`
- `env/<VAR>`

```bash
python3 -c "
import json, re
patterns = [
    r'^rules\.d/[^/]+$',
    r'^skills/[^/]+/[^/]+$',
    r'^hooks/[^/]+/[^/]+$',
    r'^memory/topics/[^/]+$',
    r'^env/[A-Z_][A-Z0-9_]*$',
]
bad = []
for i, line in enumerate(open('$LEDGER'), 1):
    line = line.strip()
    if not line: continue
    e = json.loads(line)
    r = e.get('resource','')
    if not any(re.match(p, r) for p in patterns):
        bad.append((i, r))
print('BAD_SLUGS:', bad if bad else 'none')
"
```

### Check 4 — Commit Preconditions

Every `commit` entry must have an earlier `propose` and an `assess` with `verdict: pass` on the same `resource` and target `version`.

```bash
python3 << 'PY'
import json
from collections import defaultdict

entries = []
for line in open('.claude/lineage/ledger.jsonl'):
    line = line.strip()
    if line: entries.append(json.loads(line))

# Index by (resource, version)
proposals = defaultdict(list)
assessments = defaultdict(list)
for i, e in enumerate(entries):
    key = (e.get('resource'), e.get('version'))
    if e.get('operator') == 'propose':
        proposals[key].append(i)
    elif e.get('operator') == 'assess':
        assessments[key].append(i)

violations = []
for i, e in enumerate(entries):
    if e.get('operator') != 'commit': continue
    key = (e.get('resource'), e.get('version'))
    props_before = [p for p in proposals[key] if p < i]
    asses_before = [a for a in assessments[key] if a < i]
    if not props_before:
        violations.append((i+1, 'no prior propose', key))
        continue
    if not asses_before:
        violations.append((i+1, 'no prior assess', key))
        continue
    # The most recent assess for this key should have verdict pass
    last_ass = entries[asses_before[-1]]
    ev = last_ass.get('evidence','')
    # The verdict itself lives in the evidence file; we can only flag if the verdict is in-line on the ledger entry
    verdict = last_ass.get('verdict') or last_ass.get('result')
    if verdict and verdict != 'pass':
        violations.append((i+1, f'assess verdict was {verdict}', key))

print('COMMIT_VIOLATIONS:', violations if violations else 'none')
PY
```

Note: when the verdict field is missing from the ledger entry (stored only in the evidence file), this check cannot confirm a pass. Those commits are reported as `unverified` rather than `violation` — the evidence file must be inspected manually.

### Check 5 — Snapshot Files On Disk

Every `commit` and `rollback` must have a snapshot file at `.claude/lineage/versions/<slug>/<prev-or-target>`.

```bash
python3 << 'PY'
import json, os

missing = []
for i, line in enumerate(open('.claude/lineage/ledger.jsonl'), 1):
    line = line.strip()
    if not line: continue
    e = json.loads(line)
    op = e.get('operator')
    if op not in ('commit','rollback'): continue
    slug = e.get('resource','')
    ver = e.get('prev') if op == 'commit' else e.get('version')
    if not ver: continue
    path = os.path.join('.claude/lineage/versions', slug, ver)
    if not os.path.isfile(path):
        missing.append((i, op, path))

print('MISSING_SNAPSHOTS:', missing if missing else 'none')
PY
```

### Check 6 — Post-Reject Commit

A `reject` on a `(resource, version)` pair should prevent a subsequent `commit` for the same pair unless a new `propose`+`assess` sequence follows.

```bash
python3 << 'PY'
import json

entries = []
for line in open('.claude/lineage/ledger.jsonl'):
    line = line.strip()
    if line: entries.append(json.loads(line))

violations = []
for i, e in enumerate(entries):
    if e.get('operator') != 'commit': continue
    key = (e.get('resource'), e.get('version'))
    # Find most recent reject for this key before i
    last_reject = None
    for j in range(i-1, -1, -1):
        p = entries[j]
        if (p.get('resource'), p.get('version')) == key and p.get('operator') == 'reject':
            last_reject = j
            break
    if last_reject is None:
        continue
    # After the reject, we need at least one new propose and one new assess
    new_propose = False
    new_assess = False
    for j in range(last_reject+1, i):
        p = entries[j]
        if (p.get('resource'), p.get('version')) != key: continue
        if p.get('operator') == 'propose': new_propose = True
        if p.get('operator') == 'assess': new_assess = True
    if not (new_propose and new_assess):
        violations.append((i+1, key, 'commit after reject without new propose+assess'))

print('POST_REJECT_VIOLATIONS:', violations if violations else 'none')
PY
```

## Output Format

```
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
