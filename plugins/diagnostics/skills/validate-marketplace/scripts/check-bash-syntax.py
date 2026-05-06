#!/usr/bin/env python3
import glob
import subprocess
import sys

failures = []
for path in sorted(glob.glob("plugins/*/hooks/*.sh") + glob.glob("plugins/*/skills/*/scripts/*.sh") + glob.glob("plugins/*/lib/*.sh")):
    res = subprocess.run(["bash", "-n", path], capture_output=True, text=True)
    if res.returncode != 0:
        failures.append((path, res.stderr.strip()))

if failures:
    print(f"BASH_SYNTAX_FAILURES: {failures}")
    sys.exit(1)
print("BASH_SYNTAX_FAILURES: none")
