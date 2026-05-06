#!/usr/bin/env bash
set -u

REG="${FORGE_STUDIO_POLICY_REGISTRY:-plugins/diagnostics/registry/policies.json}"

if [ ! -f "$REG" ]; then
  echo "## Policy Enforcement Index"
  echo
  echo "**Registry missing:** $REG"
  exit 0
fi

REG="$REG" python3 - <<'PY'
import json, os
from collections import defaultdict

reg = os.environ["REG"]
try:
    rows = json.load(open(reg))
except Exception as e:
    print("## Policy Enforcement Index")
    print()
    print(f"**Registry parse error:** {e}")
    raise SystemExit(0)

print("## Policy Enforcement Index")
print()
print(f"**Source:** {reg}")
print(f"**Entries:** {len(rows)}")

by_verdict = defaultdict(list)
for r in rows:
    by_verdict[r.get("verdict", "?")].append(r)

order = ["deny", "gate", "anchor", "nudge", "log"]
seen = set(order)
order += sorted(v for v in by_verdict if v not in seen)

for v in order:
    items = by_verdict.get(v, [])
    if not items:
        continue
    print()
    print(f"### {v}")
    print()
    print("| FS-id | Plugin | Hook | Bypass | Description |")
    print("|---|---|---|---|---|")
    for r in sorted(items, key=lambda x: x["id"]):
        bypass = r.get("bypass", "—")
        print(f"| {r['id']} | {r['plugin']} | `{r['hook_event']}` | {bypass} | {r['description']} |")
PY
