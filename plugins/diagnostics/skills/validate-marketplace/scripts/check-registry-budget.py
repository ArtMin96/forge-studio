#!/usr/bin/env python3
"""Checks the auto-loadable registry budget for description+when_to_use fields.

The <available_skills> block injected into the LLM context at runtime has a
15 000-byte ceiling (Source 4: Hanchung, leehanchung.github.io, 2025-10-26).
Only auto-loadable skills occupy this block. Skills marked with
`disable-model-invocation: true` appear in the user-facing `/` menu but are
NOT injected into the LLM context — so they don't count toward the budget.

This script sums description+when_to_use bytes only for SKILL.md files that
do NOT have `disable-model-invocation: true`. Skills with that flag set are
counted separately and reported for transparency but excluded from the total.

UTF-8 byte length (len(s.encode('utf-8'))) is used because the runtime budget
is a byte limit on the serialized XML block, not a Unicode code-point count.
For ASCII-heavy prose the difference is negligible; for mixed-script descriptions
it can matter.
"""
import re
import glob
import sys

try:
    import yaml
except ImportError:
    print("REGISTRY_BUDGET_ERROR: PyYAML not installed (pip install pyyaml)")
    sys.exit(2)

BUDGET = 15_000
FM_RE = re.compile(r'^---\n(.*?)\n---', re.DOTALL)

auto_loadable = []
skipped = 0

for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    content = open(path, encoding='utf-8').read()
    m = FM_RE.match(content)
    if not m:
        continue
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        continue

    if fm.get('disable-model-invocation') is True:
        skipped += 1
        continue

    desc = fm.get('description') or ''
    when = fm.get('when_to_use') or ''
    byte_len = len(desc.encode('utf-8')) + len(when.encode('utf-8'))
    auto_loadable.append((path, byte_len))

total = sum(b for _, b in auto_loadable)
n_auto = len(auto_loadable)

if total > BUDGET:
    top5 = sorted(auto_loadable, key=lambda x: x[1], reverse=True)[:5]
    print(f'REGISTRY_BUDGET_FAIL: {total}/{BUDGET} bytes (auto-loadable skills only)')
    print('# Top 5 offenders (auto-loadable):')
    for path, b in top5:
        slug = '/'.join(path.split('/')[1:4])
        print(f'  {slug}: {b} bytes')
    sys.exit(1)

pct = round(total / BUDGET * 100, 1)
print(
    f'REGISTRY_BUDGET_OK: {total}/{BUDGET} bytes '
    f'({pct}% — {n_auto} auto-loadable skills counted; '
    f'{skipped} skills with disable-model-invocation skipped)'
)
