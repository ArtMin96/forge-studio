---
name: entropy-scan
description: Scan the marketplace for documentation drift, registration gaps, convention violations, stale memory, and HARNESS_SPEC invariant compliance. Reports only — no writes.
when_to_use: Run weekly or before releases to catch drift between documentation and reality.
disable-model-invocation: true
effort: high
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Entropy Scan — Codebase Health Validation

Detect drift between documentation and reality. Run periodically (weekly recommended) or before releases.

## Instructions

Run all 9 checks. Report results in the structured format below. **Do not modify any files** — report issues and propose fixes only.

### Check 1: Plugin Count Drift

Compare README.md header line (e.g., "14 plugins. 47 skills. 51 hooks. 4 agents.") against actual counts:

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
- Verify `description:` field exists (official 2026 schema — only `description` is strongly recommended; `name` defaults to directory name if omitted)
- If any of these fields are present, verify they use valid values:
  - `effort`: must be one of `low|medium|high|xhigh|max`
  - `context`: if `fork`, an `agent:` field is strongly recommended (defaults to `general-purpose` otherwise)
- Flag any unknown frontmatter keys (authoritative list: `name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell`)
- Flag any agent whose `skills:` preload list references a skill with `disable-model-invocation: true` (silently skipped per official docs)

Report any SKILL.md failing these checks. `disable-model-invocation` is optional, not required — use it only when the skill should be user-invoke-only.

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

### Check 8: Rule Provenance (Ratchet Discipline)

Every rule in `plugins/behavioral-core/hooks/rules.d/*.txt` (excluding `archive/`) should declare its origin on its first non-blank line:

```
# origin: <source>
```

Accepted sources: `postmortem:<id>`, `trace:<session-id-or-slug>`, `ledger:<entry-id>`, `external:<short-reason>`.

```bash
for f in plugins/behavioral-core/hooks/rules.d/*.txt; do
  [ -f "$f" ] || continue
  first=$(grep -m1 -v '^\s*$' "$f" 2>/dev/null)
  case "$first" in
    \#\ origin:*) ;;
    *) echo "UNPROVENANCED: $f" ;;
  esac
done
```

**Rationale** (Osmani, 2026 — Agent Harness Engineering): *"Every rule must trace to a specific past failure or external constraint."* Rule bloat accumulates when constraints are brainstormed without being earned by a real failure. Advisory only — do not block.

Authors mark external-policy rules as `external:<reason>` (e.g., `external: tone preference`). The goal is traceability, not gatekeeping.

### Check 9: Tool-Menu Inflation

For each agent definition (`plugins/*/agents/*.md`) and each SKILL.md, count entries in `tools:` / `allowed-tools:` frontmatter. Warn if the count exceeds `FORGE_TOOL_MENU_MAX` (default 10).

```bash
python3 - <<'PY'
import os, glob, re
MAX = int(os.environ.get('FORGE_TOOL_MENU_MAX', '10'))
def count_tools(path, field_names):
    try:
        text = open(path).read()
    except Exception: return None
    if not text.startswith('---'):
        return None
    fm = text.split('---', 2)[1] if text.count('---') >= 2 else ''
    for field in field_names:
        # Try block list first: `field:\n  - Tool1\n  - Tool2`
        block = re.search(rf'^{field}[ \t]*:[ \t]*\n((?:[ \t]*-[ \t]+.+\n?)+)', fm, re.M)
        if block:
            return len(re.findall(r'^[ \t]*-[ \t]+\S', block.group(1), re.M))
        # Inline: `field: Tool1, Tool2` or `field: [Tool1, Tool2]`
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
PY
```

**Rationale** (Osmani, 2026): *"Ten sharp tools beat fifty overlapping ones."* Large tool menus compete for the model's working memory and degrade tool-selection accuracy. Advisory only — some agents legitimately need more tools.

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

### Check 8: Rule Provenance
**Status:** {PASS / {N} unprovenanced}
{List of rules.d/*.txt files missing an `# origin:` header}

### Check 9: Tool-Menu Inflation
**Status:** {PASS / {N} over threshold}
{List of agent/skill files declaring more than FORGE_TOOL_MENU_MAX tools}

### Proposed Fixes
{For each issue, one-line fix command or description}
```

Keep the report factual. No opinions, no suggestions beyond fixing the detected issues.
