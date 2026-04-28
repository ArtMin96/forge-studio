#!/usr/bin/env python3
"""Reports any line in the ledger that is not valid JSON."""
import json
import sys

LEDGER = sys.argv[1] if len(sys.argv) > 1 else '.claude/lineage/ledger.jsonl'

bad = []
for i, line in enumerate(open(LEDGER), 1):
    line = line.strip()
    if not line:
        continue
    try:
        json.loads(line)
    except Exception as e:
        bad.append((i, str(e)))
print('BAD_LINES:', bad if bad else 'none')
