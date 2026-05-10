#!/usr/bin/env python3
"""Validates SKILL.md frontmatter against the 2026 official schema."""
import re
import glob
import sys
import yaml

# Enforced name shape: lowercase, alphanumeric segments joined by single hyphens.
# Rationale (Source 3 — agentskills.io spec): names are used as CLI slugs and
# XML tag attributes; uppercase, underscores, and consecutive hyphens break
# both usages. Gerund preference (e.g. "checking" over "check") is a soft style
# hint only — not enforced here because existing forge-studio names like
# "verify" and "dispatch" wouldn't conform.
NAME_RE = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')

ALLOWED = {
    'name', 'description', 'when_to_use', 'argument-hint', 'arguments',
    'disable-model-invocation', 'user-invocable', 'allowed-tools', 'model',
    'effort', 'context', 'agent', 'hooks', 'paths', 'shell',
    'scheduling', 'structural', 'logical',
    'compatibility', 'license', 'metadata', 'mode',
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
    # metadata must be a flat string→string map (spec: no nested dicts/lists/numbers)
    if 'metadata' in fm:
        meta = fm['metadata']
        if not isinstance(meta, dict):
            failures.append((path, f"metadata must be a dict, got {type(meta).__name__}"))
        else:
            for k, v in meta.items():
                if not isinstance(v, str):
                    failures.append((path, f"metadata value '{k}' must be a string, got {type(v).__name__}"))
    # compatibility must be 1–500 chars
    if 'compatibility' in fm:
        compat = str(fm['compatibility'])
        if not (1 <= len(compat) <= 500):
            failures.append((path, f"compatibility must be 1–500 chars, got {len(compat)}"))
    name_val = fm.get('name') or ''
    if name_val and not NAME_RE.match(name_val):
        failures.append((path, f"name '{name_val}' violates regex (lowercase, hyphenated, no consecutive '--', no leading/trailing hyphen, no underscores, no uppercase)"))
    combined = (fm.get('description') or '') + ' ' + (fm.get('when_to_use') or '')
    if len(combined) > 1536:
        failures.append((path, f'description+when_to_use={len(combined)} chars (>1536 cap)'))
    if fm.get('context') == 'fork' and 'agent' not in fm:
        failures.append((path, 'context: fork without agent (defaults to general-purpose)'))

print('FRONTMATTER_FAILURES:', failures if failures else 'none')
if failures:
    sys.exit(1)
