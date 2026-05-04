---
name: entropy-scan
description: Scan the marketplace for documentation drift, registration gaps, convention violations, stale memory, and HARNESS_SPEC invariant compliance. Reports only — no writes.
when_to_use: Run weekly, before releases, after large refactors, or whenever the README header counts feel suspect — catches drift between documentation and reality. Do NOT use for pre-commit correctness checks (will the marketplace install cleanly?) — that is `/validate-marketplace`; entropy-scan is the broader drift sweep, validate-marketplace is the focused gate.
disable-model-invocation: true
effort: high
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
logical: report shows PASS / DRIFT for each of the 9 checks with concrete fix lines for any drift
---

# Entropy Scan — Codebase Health Validation

Detect drift between documentation and reality. Run periodically (weekly recommended) or before releases.

## Instructions

Run all 9 checks. Report results in the structured format below. **Do not modify any files** — report issues and propose fixes only.

### Check 1: Plugin Count Drift

Compare the README.md header line `<N> plugins. <M> skills. <H> hooks. <A> agents. <R> behavioral rules.` against actual counts:

```bash
bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh
```

Compare against the README header. Report any mismatch.

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

```text
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

### Check 9a: R.E.S.T. Audit (sub-check)

Invoke `/rest-audit` (this same plugin). Propagate its axis statuses verbatim. This is the outcome-oriented counterpart to the structural checks above — structural drift AND outcome degradation surface in one report.

### Check 9b: CLAUDE.md Structure (sub-check)

Invoke `/claude-md-structure` on `./CLAUDE.md`. Propagate its PRESENT/WEAK/MISSING statuses. Report any section missing or weak.

### Check 9: Tool-Menu Inflation

For each agent definition (`plugins/*/agents/*.md`) and each SKILL.md, count entries in `tools:` / `allowed-tools:` frontmatter. Warn if the count exceeds `FORGE_TOOL_MENU_MAX` (default 10).

```bash
python3 plugins/diagnostics/skills/entropy-scan/scripts/check-tool-menu.py
```

**Rationale** (Osmani, 2026): *"Ten sharp tools beat fifty overlapping ones."* Large tool menus compete for the model's working memory and degrade tool-selection accuracy. Advisory only — some agents legitimately need more tools.

## Output Format

```markdown
## Entropy Scan Report

**Date:** {YYYY-MM-DD}
**Overall:** {CLEAN / {N} issues found}

### Check {1..9}: <name>
**Status:** {PASS / DRIFT / GAP / {N} <issue>}
{Per-check details — counts, file lists, mismatch deltas — only when status is non-clean}

### Check 9a: R.E.S.T. Audit
**Status:** {PASS / WARN / FAIL}
Reliability / Efficiency / Security / Traceability: {status each}

### Check 9b: CLAUDE.md Structure
**Status:** {PASS / {N} sections missing or weak}

### Proposed Fixes
{For each issue: one-line fix command or description}
```

One section per check. Keep the report factual: no opinions, no suggestions beyond fixing detected issues.
