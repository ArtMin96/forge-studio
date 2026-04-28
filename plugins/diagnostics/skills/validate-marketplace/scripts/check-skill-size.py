#!/usr/bin/env python3
"""Reports SKILL.md files outside the compaction-survival size budget."""
import os
import glob

warn = []
fail = []
for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    size = os.path.getsize(path)
    tokens = size // 4
    if size > 20000:
        fail.append((path, size, tokens))
    elif size > 8000:
        warn.append((path, size, tokens))
print('OVERSIZED_SKILLS_FAIL:', fail if fail else 'none')
print('OVERSIZED_SKILLS_WARN:', warn if warn else 'none')
