#!/usr/bin/env python3
"""Reports commits that follow a reject on the same key without a fresh propose+assess."""
import json
import sys

LEDGER = sys.argv[1] if len(sys.argv) > 1 else '.claude/lineage/ledger.jsonl'

entries = []
for line in open(LEDGER):
    line = line.strip()
    if line:
        entries.append(json.loads(line))

violations = []
for i, e in enumerate(entries):
    if e.get('operator') != 'commit':
        continue
    key = (e.get('resource'), e.get('version'))
    last_reject = None
    for j in range(i - 1, -1, -1):
        p = entries[j]
        if (p.get('resource'), p.get('version')) == key and p.get('operator') == 'reject':
            last_reject = j
            break
    if last_reject is None:
        continue
    new_propose = False
    new_assess = False
    for j in range(last_reject + 1, i):
        p = entries[j]
        if (p.get('resource'), p.get('version')) != key:
            continue
        if p.get('operator') == 'propose':
            new_propose = True
        if p.get('operator') == 'assess':
            new_assess = True
    if not (new_propose and new_assess):
        violations.append((i + 1, key, 'commit after reject without new propose+assess'))

print('POST_REJECT_VIOLATIONS:', violations if violations else 'none')
