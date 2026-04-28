#!/usr/bin/env python3
"""Flags agents/skills declaring more tools than FORGE_TOOL_MENU_MAX (default 10)."""
import os, glob, re

MAX = int(os.environ.get('FORGE_TOOL_MENU_MAX', '10'))


def count_tools(path, field_names):
    try:
        text = open(path).read()
    except Exception:
        return None
    if not text.startswith('---'):
        return None
    fm = text.split('---', 2)[1] if text.count('---') >= 2 else ''
    for field in field_names:
        block = re.search(rf'^{field}[ \t]*:[ \t]*\n((?:[ \t]*-[ \t]+.+\n?)+)', fm, re.M)
        if block:
            return len(re.findall(r'^[ \t]*-[ \t]+\S', block.group(1), re.M))
        m = re.search(rf'^{field}[ \t]*:[ \t]*([^\n]+)$', fm, re.M)
        if m:
            inline = m.group(1).strip().strip('[]')
            parts = [p.strip() for p in re.split(r'[,\s]+', inline) if p.strip()]
            return len(parts) if parts else None
    return None


for path in sorted(glob.glob('plugins/*/agents/*.md')):
    n = count_tools(path, ['tools', 'allowed-tools'])
    if n and n > MAX:
        print(f"TOOL-BLOAT: {path} declares {n} tools (max {MAX})")
for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    n = count_tools(path, ['allowed-tools'])
    if n and n > MAX:
        print(f"TOOL-BLOAT: {path} declares {n} tools (max {MAX})")
