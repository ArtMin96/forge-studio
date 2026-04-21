---
name: validate-marketplace
description: Pre-commit mechanical validator. Parses marketplace.json, checks every plugin is registered, every SKILL.md has required frontmatter, every hook script is executable, every skill fits the token budget. Complements /entropy-scan (which focuses on drift); this skill focuses on correctness. Safe to run before every commit that touches plugins/.
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

### Check 3 — SKILL.md Frontmatter Completeness

Every SKILL.md must have `name`, `description`, and `disable-model-invocation: true`.

```bash
python3 << 'PY'
import re, glob

required = ['name', 'description', 'disable-model-invocation']
failures = []

for path in sorted(glob.glob('plugins/*/skills/*/SKILL.md')):
    content = open(path).read()
    # Extract frontmatter
    m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not m:
        failures.append((path, 'no frontmatter'))
        continue
    fm = m.group(1)
    missing = [k for k in required if not re.search(rf'^{k}:', fm, re.MULTILINE)]
    if missing:
        failures.append((path, f'missing: {", ".join(missing)}'))
        continue
    # disable-model-invocation must be true
    dmi = re.search(r'^disable-model-invocation:\s*(\S+)', fm, re.MULTILINE)
    if dmi and dmi.group(1).strip() != 'true':
        failures.append((path, f'disable-model-invocation={dmi.group(1)} (expected true)'))

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

### Check 6 — Skill Size Budget

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

### Check 6 — Skill Size Budget
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
