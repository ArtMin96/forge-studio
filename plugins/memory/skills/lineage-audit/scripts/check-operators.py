#!/usr/bin/env python3
"""Reports ledger entries whose operator is not in the allowed set."""
import json
import sys

LEDGER = sys.argv[1] if len(sys.argv) > 1 else '.claude/lineage/ledger.jsonl'
ALLOWED = {'propose', 'assess', 'commit', 'reject', 'rollback'}

bad = []
for i, line in enumerate(open(LEDGER), 1):
    line = line.strip()
    if not line:
        continue
    e = json.loads(line)
    op = e.get('operator')
    if op not in ALLOWED:
        bad.append((i, op))
print('BAD_OPERATORS:', bad if bad else 'none')
