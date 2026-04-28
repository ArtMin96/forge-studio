#!/usr/bin/env python3
"""Validates that every plugins/*/hooks/hooks.json parses."""
import json
import glob

failures = []
for path in sorted(glob.glob('plugins/*/hooks/hooks.json')):
    try:
        json.load(open(path))
    except Exception as e:
        failures.append((path, str(e)))
print('HOOKS_JSON_FAILURES:', failures if failures else 'none')
