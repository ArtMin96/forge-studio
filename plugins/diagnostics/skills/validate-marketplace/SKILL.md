---
name: validate-marketplace
description: Pre-commit mechanical validator — checks plugin registration, SKILL.md frontmatter, hook executability, and token budget. Focuses on correctness; complements `/entropy-scan` which focuses on drift.
when_to_use: Before committing changes that touch `plugins/`, after editing `marketplace.json` or any SKILL.md, or as a CI gate before a version bump.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Validate Marketplace — Pre-Commit Correctness Check

Mechanical validation of marketplace integrity. Fast, deterministic, scriptable. Distinct from `/entropy-scan`: this skill focuses on **correctness** (will the marketplace install cleanly?), not **drift** (is the README accurate?).

## When to Use

- Before committing plugin changes (ideally wired into a pre-commit hook later)
- After manually editing `marketplace.json` or a SKILL.md
- CI gate before shipping a plugin version bump
- When `/entropy-scan` reports issues and you want a focused pass

## Instructions

Run the six checks below. Stop at the first check that returns `FAIL` if time-constrained; otherwise run all six and produce a structured report.

### Check 1 — `marketplace.json` Parses

```bash
python3 -c "
import json, sys
try:
    data = json.load(open('.claude-plugin/marketplace.json'))
    print('PARSE: OK')
    print('PLUGIN_COUNT:', len(data.get('plugins', [])))
except Exception as e:
    print('PARSE: FAIL -', e)
    sys.exit(1)
"
```

### Check 2 — Directory / Registration Equality

Every `plugins/*/` directory must have a marketplace entry whose `name` matches the directory and whose `source` points to `./plugins/<name>`. And vice versa.

```bash
python3 << 'PY'
import json, os, glob

data = json.load(open('.claude-plugin/marketplace.json'))
registered = {p['name']: p for p in data.get('plugins', [])}
dirs = {os.path.basename(p.rstrip('/')) for p in glob.glob('plugins/*/')}

missing_entry = sorted(dirs - set(registered))
missing_dir = sorted(set(registered) - dirs)

# Source-path mismatch
source_mismatch = []
for name, p in registered.items():
    expected = f'./plugins/{name}'
    if p.get('source') != expected:
        source_mismatch.append((name, p.get('source'), expected))

print('MISSING_MARKETPLACE_ENTRY:', missing_entry)
print('MISSING_PLUGIN_DIR:', missing_dir)
print('SOURCE_PATH_MISMATCH:', source_mismatch)
PY
```

### Check 3 — SKILL.md Frontmatter Schema

Every SKILL.md must have `description`. Only the 2026 official fields are allowed; unknown keys are flagged.

Allowed fields (per code.claude.com/docs/en/skills, 2026 schema):
`name`, `description`, `when_to_use`, `argument-hint`, `arguments`,
`disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`,
`effort`, `context`, `agent`, `hooks`, `paths`, `shell`.

```bash
python3 << 'PY'
import re, glob, yaml

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
    # description + when_to_use combined cap (1536 chars per official listing budget)
    combined = (fm.get('description') or '') + ' ' + (fm.get('when_to_use') or '')
    if len(combined) > 1536:
        failures.append((path, f'description+when_to_use={len(combined)} chars (>1536 cap)'))
    # context: fork requires a task body — flag but don't fail
    if fm.get('context') == 'fork' and 'agent' not in fm:
        failures.append((path, 'context: fork without agent (defaults to general-purpose — OK but explicit is better)'))

print('FRONTMATTER_FAILURES:', failures if failures else 'none')
PY
```

### Check 4 — Hook Script Executability

Every `plugins/*/hooks/*.sh` must be executable. `hooks.json` files are not expected to be executable.

```bash
non_exec=$(find plugins -type f -path '*/hooks/*.sh' ! -perm -u+x 2>/dev/null)
if [ -z "$non_exec" ]; then
  echo "HOOK_EXEC: CLEAN"
else
  echo "HOOK_EXEC: FAIL"
  echo "$non_exec"
fi
```

### Check 5 — Hook JSON Parses

Every `plugins/*/hooks/hooks.json` must parse.

```bash
python3 << 'PY'
import json, glob
failures = []
for path in sorted(glob.glob('plugins/*/hooks/hooks.json')):
    try:
        json.load(open(path))
    except Exception as e:
        failures.append((path, str(e)))
print('HOOKS_JSON_FAILURES:', failures if failures else 'none')
PY
```

### Check 6 — Agent Schema + Skill Preload Coherence

Every agent `.md` in `plugins/*/agents/` must have valid frontmatter and any skill it preloads
must NOT have `disable-model-invocation: true` (per official docs: disabled skills cannot be
preloaded into a subagent — Claude Code silently skips them).

```bash
python3 << 'PY'
import re, glob, yaml, os

failures = []

# Collect all skill names with their disable-model-invocation flag
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

# Validate each agent
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
    # Plugin agents cannot use hooks, mcpServers, permissionMode (silently ignored per docs)
    for banned in ('hooks', 'mcpServers', 'permissionMode'):
        if banned in fm:
            failures.append((path, f'plugin agent uses unsupported field: {banned}'))
    # Preloaded skills must not be disabled
    for sk in fm.get('skills') or []:
        if sk not in skills_dmi:
            failures.append((path, f'preloads unknown skill: {sk}'))
        elif skills_dmi[sk]:
            failures.append((path, f'preloads disabled skill: {sk} (has disable-model-invocation: true — will be silently skipped)'))

print('AGENT_FAILURES:', failures if failures else 'none')
PY
```

### Check 7 — Skill Size Budget

Skills should stay under the compaction survival budget.

| Band | Character count | Approx tokens | Status |
|---|---|---|---|
| Ideal | ≤ 8,000 | ≤ 2,000 | OK |
| Warn | 8,001–20,000 | 2,000–5,000 | truncation risk after compaction |
| Fail | > 20,000 | > 5,000 | will be dropped after compaction |

```bash
python3 << 'PY'
import os, glob
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
PY
```

## Output Format

```
## Validate Marketplace Report

### Check 1 — marketplace.json parses
Status: {OK / FAIL}
Plugins registered: {N}

### Check 2 — Directory/Registration Equality
Status: {CLEAN / FAIL}
Missing marketplace entry: {list}
Missing plugin directory: {list}
Source path mismatches: {list}

### Check 3 — SKILL.md Frontmatter
Status: {CLEAN / {N} failures}
{list}

### Check 4 — Hook Executability
Status: {CLEAN / {N} non-executable}
{list}

### Check 5 — hooks.json Parses
Status: {CLEAN / {N} failures}
{list}

### Check 6 — Agent Schema + Skill Preload Coherence
Status: {CLEAN / {N} failures}
{list — flags unknown fields, banned fields (hooks/mcpServers/permissionMode), and disabled-skill preloads}

### Check 7 — Skill Size Budget
Status: {CLEAN / {N} warn / {N} fail}
Oversized-fail (>5,000 tokens, will be dropped): {list}
Oversized-warn (>2,000 tokens, truncation risk): {list}

### Verdict
Overall: {VALID / INVALID}
{One-line remediation per issue kind}
```

## Rules

- This skill never writes. It reports findings and proposes fixes.
- Distinct from `/entropy-scan`: this checks **correctness**, entropy-scan checks **drift**. A commit can pass validate-marketplace while entropy-scan reports stale README counts.
- If a check requires a tool that is missing (e.g. `python3`), report `SKIPPED` for that check rather than failing the whole scan.
- If `plugins/` has no subdirectories, report the whole scan as `N/A`.
