#!/usr/bin/env python3
import re
import glob
import sys

BUDGET = 1536  # description + when_to_use combined, per CLAUDE.md SKILL.md spec

oversized = []
for f in sorted(glob.glob("plugins/*/skills/*/SKILL.md")):
    txt = open(f).read()
    m = re.search(r"^---\n(.*?)\n---", txt, re.DOTALL)
    if not m:
        continue
    fm = m.group(1)
    desc = re.search(r"^description:\s*(.+?)(?=\n[a-z_-]+:|\n---|\Z)", fm, re.M | re.DOTALL)
    when = re.search(r"^when_to_use:\s*(.+?)(?=\n[a-z_-]+:|\n---|\Z)", fm, re.M | re.DOTALL)
    d = desc.group(1).strip() if desc else ""
    w = when.group(1).strip() if when else ""
    total = len(d) + len(w)
    if total > BUDGET:
        oversized.append((f, total))

if oversized:
    print(f"DESC_LENGTH_FAIL: {oversized}")
    sys.exit(1)
print("DESC_LENGTH_FAIL: none")
