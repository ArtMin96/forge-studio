#!/usr/bin/env python3
"""Checks that no SKILL.md body exceeds 500 lines.

Body is the content after the closing --- of frontmatter. If a file has no
frontmatter, the entire file is treated as body. The 500-line cap comes from
Anthropic best-practices (Source 5, 2026): longer bodies saturate the context
window before the skill has finished reasoning.
"""
import re
import glob
import sys

CAP = 500

results = []
for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    content = open(path).read()
    # Strip the frontmatter block (opening --- through closing ---).
    # re.DOTALL so (.*?) matches across newlines.
    m = re.match(r'^---\n.*?\n---\n?(.*)', content, re.DOTALL)
    body = m.group(1) if m else content
    line_count = len(body.splitlines())
    results.append((path, line_count))

failures = [(p, n) for p, n in results if n > CAP]
top3 = sorted(results, key=lambda x: x[1], reverse=True)[:3]

if failures:
    print(f'BODY_LINES_FAIL: {len(failures)} skills exceed {CAP}-line cap')
    for path, n in sorted(failures, key=lambda x: x[1], reverse=True):
        print(f'  {path}: {n} lines')
else:
    print('BODY_LINES_FAIL: none')

print('# Top 3 longest bodies:')
for path, n in top3:
    print(f'  {path}: {n} lines')

if failures:
    sys.exit(1)
