#!/usr/bin/env python3
import re
import glob
import os
import sys

skills = set()
for f in glob.glob("plugins/*/skills/*/SKILL.md"):
    skills.add("/" + os.path.basename(os.path.dirname(f)))

broken = []
for f in sorted(glob.glob("plugins/*/skills/*/SKILL.md")):
    txt = open(f).read()
    for ref in re.findall(r"use\s+`(/[a-z][a-z0-9-]*)`\s+instead", txt, re.I):
        if ref not in skills:
            broken.append((f, ref))

if broken:
    print(f"SIBLING_REF_FAIL: {broken}")
    sys.exit(1)
print("SIBLING_REF_FAIL: none")
