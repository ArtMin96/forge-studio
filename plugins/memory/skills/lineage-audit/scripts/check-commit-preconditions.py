#!/usr/bin/env python3
"""Verifies every commit has a prior propose + assess on the same (resource, version)."""
import json
import sys
from collections import defaultdict

LEDGER = sys.argv[1] if len(sys.argv) > 1 else '.claude/lineage/ledger.jsonl'

entries = []
for line in open(LEDGER):
    line = line.strip()
    if line:
        entries.append(json.loads(line))

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
    if e.get('operator') != 'commit':
        continue
    key = (e.get('resource'), e.get('version'))
    props_before = [p for p in proposals[key] if p < i]
    asses_before = [a for a in assessments[key] if a < i]
    if not props_before:
        violations.append((i + 1, 'no prior propose', key))
        continue
    if not asses_before:
        violations.append((i + 1, 'no prior assess', key))
        continue
    last_ass = entries[asses_before[-1]]
    verdict = last_ass.get('verdict') or last_ass.get('result')
    if verdict and verdict != 'pass':
        violations.append((i + 1, f'assess verdict was {verdict}', key))

print('COMMIT_VIOLATIONS:', violations if violations else 'none')
