#!/usr/bin/env python3
"""Typed SSL overlay validator. Informational only — exits 0 always."""
import glob
import json
import os
import re
import sys

import yaml

SCHEMA_PATH = os.path.join(
    os.path.dirname(__file__), '..', 'schema', 'ssl.schema.json'
)

# Placeholder pattern: matches TODO, FIXME, or angle-bracket tokens like <...>
PLACEHOLDER_RE = re.compile(r'^(TODO|FIXME|<.*>)$', re.IGNORECASE)

# Frontmatter extraction — same regex pattern as check-frontmatter.py
FRONTMATTER_RE = re.compile(r'^---\n(.*?)\n---', re.DOTALL)


def load_enums(schema_path):
    """Return (action_enum, resource_enum, effect_enum) sets from the schema."""
    try:
        with open(schema_path) as f:
            schema = json.load(f)
        defs = schema.get('$defs', {})
        actions = set(defs.get('action-enum', {}).get('enum', []))
        resources = set(defs.get('resource-enum', {}).get('enum', []))
        effects = set(defs.get('effect-enum', {}).get('enum', []))
        return actions, resources, effects
    except Exception:
        return set(), set(), set()


def slug(root, path):
    rel = os.path.relpath(path, root)
    # Produce skills/<plugin>/<skill> form
    m = re.match(r'plugins/([^/]+)/skills/([^/]+)/SKILL\.md', rel)
    if m:
        return f'skills/{m.group(1)}/{m.group(2)}'
    return rel


def check_field(findings, label, value, level='WARN'):
    """Check a scalar string field for placeholder and empty-string issues."""
    if value == '':
        findings.append((level, label, 'empty value (omit instead)'))
        return
    if isinstance(value, str) and PLACEHOLDER_RE.match(value.strip()):
        findings.append((level, label, f'ungrounded placeholder ("{value}")'))


def validate_structural_item(findings, label, item, action_enum, resource_enum, effect_enum):
    """Validate a single structural list item — string or typed-step mapping."""
    if isinstance(item, str):
        # Plain string form — no further checks needed
        if item == '':
            findings.append(('WARN', label, 'empty string item (omit instead)'))
        elif PLACEHOLDER_RE.match(item.strip()):
            findings.append(('WARN', label, f'ungrounded placeholder ("{item}")'))
        return
    if isinstance(item, dict):
        # Typed-step form
        if 'step' not in item:
            findings.append(('WARN', label, 'typed-step mapping missing required "step" key'))
        for field, enum_set, fname in [
            ('actions', action_enum, 'action'),
            ('resources', resource_enum, 'resource'),
            ('effects', effect_enum, 'effect'),
        ]:
            if field in item:
                if not isinstance(item[field], list):
                    findings.append(('WARN', f'{label}.{field}', 'expected a list'))
                    continue
                for val in item[field]:
                    if enum_set and val not in enum_set:
                        findings.append(('INFO', f'{label}.{field}', f'"{val}" not in schema enum (draft)'))
        return
    # Neither string nor mapping
    findings.append(('WARN', label, f'unexpected type {type(item).__name__} (expected string or mapping)'))


def validate_skill(path, root, action_enum, resource_enum, effect_enum):
    """Return list of (level, location, message) findings for one SKILL.md."""
    findings = []
    try:
        content = open(path).read()
    except OSError as e:
        findings.append(('WARN', path, f'unreadable: {e}'))
        return findings, {}

    m = FRONTMATTER_RE.match(content)
    if not m:
        return findings, {}

    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return findings, {}

    skill_label = slug(root, path)

    # --- scheduling ---
    if 'scheduling' in fm:
        val = fm['scheduling']
        if not isinstance(val, str):
            findings.append(('WARN', f'{skill_label}  scheduling', f'expected string, got {type(val).__name__}'))
        else:
            check_field(findings, f'{skill_label}  scheduling', val)

    # --- structural ---
    if 'structural' in fm:
        val = fm['structural']
        if not isinstance(val, list):
            findings.append(('WARN', f'{skill_label}  structural', f'expected list, got {type(val).__name__}'))
        else:
            for i, item in enumerate(val):
                validate_structural_item(
                    findings,
                    f'{skill_label}  structural[{i}]',
                    item,
                    action_enum, resource_enum, effect_enum,
                )

    # --- logical ---
    if 'logical' in fm:
        val = fm['logical']
        if not isinstance(val, str):
            findings.append(('WARN', f'{skill_label}  logical', f'expected string, got {type(val).__name__}'))
        else:
            check_field(findings, f'{skill_label}  logical', val)

    return findings, fm


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    root = os.path.normpath(root)

    action_enum, resource_enum, effect_enum = load_enums(SCHEMA_PATH)

    pattern = os.path.join(root, 'plugins', '*', 'skills', '*', 'SKILL.md')
    paths = sorted(glob.glob(pattern))

    total = 0
    with_scheduling = 0
    with_structural = 0
    with_logical = 0
    all_findings = []

    for path in paths:
        total += 1
        findings, fm = validate_skill(path, root, action_enum, resource_enum, effect_enum)
        if 'scheduling' in fm:
            with_scheduling += 1
        if 'structural' in fm:
            with_structural += 1
        if 'logical' in fm:
            with_logical += 1
        all_findings.extend(findings)

    missing_logical = total - with_logical
    warn_count = sum(1 for f in all_findings if f[0] == 'WARN')
    info_count = sum(1 for f in all_findings if f[0] == 'INFO')

    print('## SSL Audit (typed)')
    print(f'Skills scanned: {total}')
    print(f'With scheduling: {with_scheduling}')
    print(f'With structural: {with_structural}')
    print(f'With logical: {with_logical}')
    print(f'Missing logical: {missing_logical}')
    print()
    print('### Findings')
    if all_findings:
        for level, location, message in all_findings:
            print(f'- {level:<4}  {location:<40}  {message}')
    else:
        print('(none)')
    print()
    print('### Summary')
    print(f'Findings: {warn_count} WARN, {info_count} INFO. (Informational — exit 0.)')

    sys.exit(0)


if __name__ == '__main__':
    main()
