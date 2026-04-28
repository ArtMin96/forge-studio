#!/usr/bin/env python3
"""Validates plugin agent frontmatter and skill-preload coherence."""
import re
import glob
import yaml
import os

failures = []

skills_dmi = {}
for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    content = open(path).read()
    m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not m:
        continue
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        continue
    name = fm.get('name') or os.path.basename(os.path.dirname(path))
    skills_dmi[name] = bool(fm.get('disable-model-invocation'))

for path in sorted(glob.glob('plugins/*/agents/*.md')):
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
    if 'name' not in fm or 'description' not in fm:
        failures.append((path, 'missing name or description'))
        continue
    for banned in ('hooks', 'mcpServers', 'permissionMode'):
        if banned in fm:
            failures.append((path, f'plugin agent uses unsupported field: {banned}'))
    for sk in fm.get('skills') or []:
        if sk not in skills_dmi:
            failures.append((path, f'preloads unknown skill: {sk}'))
        elif skills_dmi[sk]:
            failures.append((path, f'preloads disabled skill: {sk} (disable-model-invocation: true — silently skipped)'))

print('AGENT_FAILURES:', failures if failures else 'none')
