---
name: entropy-scan
description: Scan the marketplace for documentation drift, registration gaps, convention violations, stale memory, and HARNESS_SPEC invariant compliance. Reports only — no writes.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Entropy Scan — Codebase Health Validation

Detect drift between documentation and reality. Run periodically (weekly recommended) or before releases.

## Instructions

Run all 7 checks. Report results in the structured format below. **Do not modify any files** — report issues and propose fixes only.

### Check 1: Plugin Count Drift

Compare README.md header line (e.g., "11 plugins. 39 skills. 25 hooks. 4 agents.") against actual counts:

```bash
# Plugins
ls -d plugins/*/ | wc -l

# Skills (SKILL.md files)
find plugins -name "SKILL.md" | wc -l

# Hooks (count entries across all hooks.json, not files)
# Each matcher+hooks pair in a hooks.json counts as one hook
python3 -c "
import json, glob
total = 0
for f in glob.glob('plugins/*/hooks/hooks.json'):
    data = json.load(open(f))
    for event, matchers in data.get('hooks', {}).items():
        total += len(matchers)
print(total)
"

# Agents
find plugins -name "*.md" -path "*/agents/*" | wc -l
```

Compare against README header. Report any mismatch.

### Check 2: Marketplace Registration Gap

```bash
# Actual plugin directories
ls -d plugins/*/ | xargs -I{} basename {}

# Registered names in marketplace.json
python3 -c "
import json
data = json.load(open('.claude-plugin/marketplace.json'))
for p in data['plugins']:
    print(p['name'])
"
```

Report: directories without marketplace entries, and marketplace entries without directories.

### Check 3: SKILL.md Frontmatter Completeness

For each SKILL.md found via `find plugins -name "SKILL.md"`:
- Verify `name:` field exists
- Verify `description:` field exists
- Verify `disable-model-invocation: true` is present

Report any SKILL.md missing required fields.

### Check 4: Hook Script Executability

```bash
find plugins -name "*.sh" -path "*/hooks/*" ! -perm -u+x
```

Report any non-executable hook scripts.

### Check 5: Memory Staleness

If `.claude/memory/` exists, check topic files for dates:
- Extract any "Last verified:" or date patterns from each file
- Flag files where the date is > 90 days old
- Flag files with no date at all

If no memory directory exists, report "N/A — no memory directory found."

### Check 6: HARNESS_SPEC.md Invariant Compliance

Read `HARNESS_SPEC.md` and validate these invariants:

1. **Plugin Structure**: Every `plugins/*/` directory that has hooks also has `hooks/hooks.json`
2. **Agent Tool Boundaries**: Read each `plugins/*/agents/*.md` — verify planner/reviewer don't have Write/Edit in allowed-tools
3. **Marketplace Registration**: (covered by Check 2, reference result)
4. **Hook Exit Codes**: Grep for `exit 2` in hooks not under PreToolUse or PreCompact (informational — may have false positives)
5. **Async Blocking Mismatch**: Check hooks.json for PreCompact hooks that use `exit 2` or `{"decision":"block"}` while also having `"async": true` — async hooks cannot block. Flag as misconfiguration.
6. **Monitors Manifest**: If any hooks.json contains a `monitors` key, validate entries have `description` and `command` fields

### Check 7: Skill Token Weight

For each SKILL.md, count characters (approximate tokens = chars / 4):

```bash
find plugins -name "SKILL.md" -exec sh -c '
  chars=$(wc -c < "$1")
  tokens=$((chars / 4))
  if [ "$tokens" -gt 2000 ]; then
    echo "OVERSIZED: $1 (~${tokens} tokens)"
  fi
' _ {} \;
```

Thresholds:
- Under 2,000 tokens (~8,000 chars): ideal
- 2,000-5,000 tokens: warn (may lose content after compaction)
- Over 5,000 tokens (~20,000 chars): flag as oversized (truncated after compaction)

Skills survive compaction with first 5,000 tokens per skill, shared 25,000-token budget across all invoked skills.

## Output Format

```
## Entropy Scan Report

**Date:** {YYYY-MM-DD}
**Overall:** {CLEAN / {N} issues found}

### Check 1: Plugin Count Drift
**Status:** {PASS / DRIFT}
README claims: {N} plugins, {N} skills, {N} hooks, {N} agents
Actual: {N} plugins, {N} skills, {N} hooks, {N} agents
{Mismatch details if DRIFT}

### Check 2: Marketplace Registration
**Status:** {PASS / GAP}
{Details if GAP}

### Check 3: SKILL.md Frontmatter
**Status:** {PASS / {N} incomplete}
{List of files and missing fields if incomplete}

### Check 4: Hook Executability
**Status:** {PASS / {N} non-executable}
{List of files if non-executable}

### Check 5: Memory Staleness
**Status:** {PASS / {N} stale / N/A}
{List of stale files if any}

### Check 6: Invariant Compliance
**Status:** {PASS / {N} violations}
{Details if violations}

### Check 7: Skill Token Weight
**Status:** {PASS / {N} oversized}
{List of SKILL.md files exceeding 2,000 tokens with approximate size}

### Proposed Fixes
{For each issue, one-line fix command or description}
```

Keep the report factual. No opinions, no suggestions beyond fixing the detected issues.
