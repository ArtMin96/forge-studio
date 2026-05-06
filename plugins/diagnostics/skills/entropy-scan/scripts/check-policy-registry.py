#!/usr/bin/env python3
import json
import os
import glob
import sys

REG = "plugins/diagnostics/registry/policies.json"
SCAN_DIRS = (
    "plugins/behavioral-core/hooks",
    "plugins/policy-gateway/hooks",
    "plugins/research-gate/hooks",
)
EXCLUDE_BASENAMES = {"hooks.json", "rules.d"}

if not os.path.exists(REG):
    print(f"POLICY_REGISTRY_FAIL: missing registry at {REG}")
    sys.exit(1)

try:
    rows = json.load(open(REG))
except Exception as e:
    print(f"POLICY_REGISTRY_FAIL: parse error: {e}")
    sys.exit(1)

ids = [r["id"] for r in rows]
dup_ids = sorted({i for i in ids if ids.count(i) > 1})

registered_impls = {r["implementation"] for r in rows}
missing_impls = sorted(p for p in registered_impls if not os.path.exists(p))

discovered = set()
for d in SCAN_DIRS:
    for path in glob.glob(f"{d}/*.sh"):
        base = os.path.basename(path)
        if base in EXCLUDE_BASENAMES or base.endswith("-healthcheck.sh") or base.endswith("-bootstrap.sh"):
            continue
        discovered.add(path)

unregistered = sorted(discovered - registered_impls)

problems = []
if dup_ids:
    problems.append(("DUP_IDS", dup_ids))
if missing_impls:
    problems.append(("MISSING_IMPL", missing_impls))
if unregistered:
    problems.append(("UNREGISTERED_SCRIPT", unregistered))

if problems:
    for kind, items in problems:
        print(f"POLICY_REGISTRY_FAIL: {kind}: {items}")
    sys.exit(1)

print(f"POLICY_REGISTRY_FAIL: none ({len(rows)} entries, {len(discovered)} scripts checked)")
