#!/usr/bin/env python3
"""Reports ledger entries whose resource slug doesn't match a registry pattern."""
import json
import re
import sys

LEDGER = sys.argv[1] if len(sys.argv) > 1 else '.claude/lineage/ledger.jsonl'
PATTERNS = [
    r'^rules\.d/[^/]+$',
    r'^skills/[^/]+/[^/]+$',
    r'^hooks/[^/]+/[^/]+$',
    r'^memory/topics/[^/]+$',
    r'^env/[A-Z_][A-Z0-9_]*$',
]

bad = []
for i, line in enumerate(open(LEDGER), 1):
    line = line.strip()
    if not line:
        continue
    e = json.loads(line)
    r = e.get('resource', '')
    if not any(re.match(p, r) for p in PATTERNS):
        bad.append((i, r))
print('BAD_SLUGS:', bad if bad else 'none')
