#!/usr/bin/env python3
"""Validates SKILL.md frontmatter against the 2026 official schema."""
import re
import glob
import yaml

ALLOWED = {
    'name', 'description', 'when_to_use', 'argument-hint', 'arguments',
    'disable-model-invocation', 'user-invocable', 'allowed-tools', 'model',
    'effort', 'context', 'agent', 'hooks', 'paths', 'shell',
}
failures = []

for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    content = open(path).read()
    m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not m:
        failures.append((path, 'no frontmatter'))
        continue
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        failures.append((path, f'yaml error: {e}'))
        continue
    if 'description' not in fm:
        failures.append((path, 'missing description'))
        continue
    unknown = sorted(set(fm) - ALLOWED)
    if unknown:
        failures.append((path, f'unknown keys: {", ".join(unknown)}'))
        continue
    combined = (fm.get('description') or '') + ' ' + (fm.get('when_to_use') or '')
    if len(combined) > 1536:
        failures.append((path, f'description+when_to_use={len(combined)} chars (>1536 cap)'))
    if fm.get('context') == 'fork' and 'agent' not in fm:
        failures.append((path, 'context: fork without agent (defaults to general-purpose)'))

print('FRONTMATTER_FAILURES:', failures if failures else 'none')
