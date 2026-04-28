#!/usr/bin/env python3
"""Verifies every commit/rollback has a corresponding snapshot file on disk."""
import json
import os
import sys

LEDGER = sys.argv[1] if len(sys.argv) > 1 else '.claude/lineage/ledger.jsonl'
VERSIONS_DIR = sys.argv[2] if len(sys.argv) > 2 else '.claude/lineage/versions'

missing = []
for i, line in enumerate(open(LEDGER), 1):
    line = line.strip()
    if not line:
        continue
    e = json.loads(line)
    op = e.get('operator')
    if op not in ('commit', 'rollback'):
        continue
    slug = e.get('resource', '')
    ver = e.get('prev') if op == 'commit' else e.get('version')
    if not ver:
        continue
    path = os.path.join(VERSIONS_DIR, slug, ver)
    if not os.path.isfile(path):
        missing.append((i, op, path))

print('MISSING_SNAPSHOTS:', missing if missing else 'none')
