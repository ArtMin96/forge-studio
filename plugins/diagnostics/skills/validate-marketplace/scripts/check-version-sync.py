#!/usr/bin/env python3
import json
import glob
import sys

mp_path = ".claude-plugin/marketplace.json"
mp = json.load(open(mp_path))
mp_versions = {p["name"]: p.get("version", "MISSING") for p in mp["plugins"]}

mismatches = []
for plugin_json in sorted(glob.glob("plugins/*/.claude-plugin/plugin.json")):
    name = plugin_json.split("/")[1]
    try:
        pv = json.load(open(plugin_json)).get("version", "MISSING")
    except Exception as e:
        mismatches.append((name, "PARSE_ERROR", str(e)))
        continue
    mv = mp_versions.get(name, "NOT_REGISTERED")
    if pv != mv:
        mismatches.append((name, mv, pv))

if mismatches:
    print(f"VERSION_SYNC_FAILURES: {mismatches}")
    sys.exit(1)
print("VERSION_SYNC_FAILURES: none")
