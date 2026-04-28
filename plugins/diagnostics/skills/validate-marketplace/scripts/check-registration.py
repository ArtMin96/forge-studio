#!/usr/bin/env python3
"""Reports plugin directories without marketplace entries (and vice versa) and source-path mismatches."""
import json
import os
import glob

data = json.load(open('.claude-plugin/marketplace.json'))
registered = {p['name']: p for p in data.get('plugins', [])}
dirs = {os.path.basename(p.rstrip('/')) for p in glob.glob('plugins/*/')}

missing_entry = sorted(dirs - set(registered))
missing_dir = sorted(set(registered) - dirs)

source_mismatch = []
for name, p in registered.items():
    expected = f'./plugins/{name}'
    if p.get('source') != expected:
        source_mismatch.append((name, p.get('source'), expected))

print('MISSING_MARKETPLACE_ENTRY:', missing_entry)
print('MISSING_PLUGIN_DIR:', missing_dir)
print('SOURCE_PATH_MISMATCH:', source_mismatch)
