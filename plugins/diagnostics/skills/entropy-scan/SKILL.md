---
name: entropy-scan
description: Scan the marketplace for documentation drift, registration gaps, convention violations, stale memory, and HARNESS_SPEC invariant compliance. Reports only — no writes.
when_to_use: Run weekly, before releases, after large refactors, or whenever the README header counts feel suspect — catches drift between documentation and reality. Do NOT use for pre-commit correctness checks (will the marketplace install cleanly?) — that is `/validate-marketplace`; entropy-scan is the broader drift sweep, validate-marketplace is the focused gate.
paths:
  - "plugins/**/SKILL.md"
  - "plugins/**/hooks.json"
  - ".claude-plugin/marketplace.json"
  - "README.md"
disable-model-invocation: true
effort: high
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
logical: report shows PASS / DRIFT for each of the 14 checks with concrete fix lines for any drift
---

# Entropy Scan — Codebase Health Validation

Detect drift between documentation and reality. Run periodically (weekly recommended) or before releases.

## Instructions

Run all 14 checks (1–8, 9a, 9b, 10–14). Report results in the structured format below. **Do not modify any files** — report issues and propose fixes only.

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
- Verify `description:` field exists.
- If `effort:` is set, value must be `low|medium|high|xhigh|max`.
- If `context: fork`, an `agent:` field is strongly recommended.
- Flag unknown frontmatter keys. Authoritative list: `name, description, when_to_use, argument-hint, arguments, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks, paths, shell, scheduling, structural, logical, compatibility, license, metadata, mode`.
- Flag any agent whose `skills:` preload list references a skill with `disable-model-invocation: true` (silently skipped per official docs).

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

```bash
bash plugins/diagnostics/skills/entropy-scan/scripts/check-skill-size-quick.sh
```

Approximates tokens as `chars / 4` and flags any SKILL.md over 2000 tokens. Thresholds:
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
bash plugins/diagnostics/skills/entropy-scan/scripts/check-rule-provenance.sh
```

Advisory only — do not block. Rationale: Osmani, 2026 (Agent Harness Engineering) — every rule must trace to a specific past failure or external constraint, else rule bloat accumulates. Mark external-policy rules as `external:<reason>` (e.g. `external: tone preference`). Traceability, not gatekeeping.

### Check 9: Sub-audits

- **9a — R.E.S.T.**: invoke `/rest-audit`; propagate its Reliability/Efficiency/Security/Traceability statuses verbatim. Outcome-oriented counterpart to the structural checks above.
- **9b — CLAUDE.md structure**: invoke `/md-structure` on `./CLAUDE.md`; propagate PRESENT/WEAK/MISSING statuses.

### Check 10: Tool-Menu Inflation

For each agent definition (`plugins/*/agents/*.md`) and each SKILL.md, count entries in `tools:` / `allowed-tools:` frontmatter. Warn if the count exceeds `FORGE_TOOL_MENU_MAX` (default 10).

```bash
python3 plugins/diagnostics/skills/entropy-scan/scripts/check-tool-menu.py
```

Advisory only. Rationale: Osmani, 2026 — large tool menus compete for working memory and degrade selection accuracy.

### Check 11: Sibling Reference Resolution

Every `Do NOT use for X — use \`/sibling\` instead` line in a SKILL.md `when_to_use` field must point to a skill that exists somewhere in `plugins/*/skills/`. Broken references produce dead routing advice that drifts as skills are renamed or removed.

```bash
python3 plugins/diagnostics/skills/entropy-scan/scripts/check-sibling-refs.py
```

### Check 12: SKILL.md Description Budget

Per `CLAUDE.md`, `description` + `when_to_use` combined must stay under 1536 characters. Past that, the skill description gets truncated when surfaced in the skill picker, which degrades model-side skill matching.

```bash
python3 plugins/diagnostics/skills/entropy-scan/scripts/check-desc-length.py
```

### Check 13: Policy Registry Drift

The cross-plugin policy index at `plugins/diagnostics/registry/policies.json` must stay in sync with the enforcement scripts on disk: every registered FS-id's `implementation` path must exist, and every enforcement script under `behavioral-core/hooks/`, `policy-gateway/hooks/`, `research-gate/hooks/` (excluding bootstrap and healthcheck files) must appear in the registry. Drift either way produces silent inconsistency between `/policies-list` and reality.

```bash
python3 plugins/diagnostics/skills/entropy-scan/scripts/check-policy-registry.py
```

### Check 14: Sprawl / Mystery-House Signals

Periodic measurement catches Mystery-House drift early — when machine-speed plugin/skill growth outpaces a sole maintainer's coordination capacity (Breunig 2026-03-26, Lesson 7).

```bash
bash plugins/diagnostics/skills/entropy-scan/scripts/sprawl.sh .
```

Reports four metrics with WARN / ALARM thresholds: total plugin count, max skills-per-plugin, top hook-event collision count, cross-plugin string references. Exit 1 on any WARN or ALARM. Report results verbatim — do not interpret beyond surfacing the verdict.

When two events tie for top collision count (Counter ordering), the script reports only one — note both in any output if a second event is also at the same count. Cross-plugin references that originate predominantly from `diagnostics/` are structural (diagnostics enumerates plugins as its job) and not a sign of sprawl per se; surface the WARN but contextualize.

## Output Format

```markdown
## Entropy Scan Report

**Date:** {YYYY-MM-DD}
**Overall:** {CLEAN / {N} issues found}

### Check {1..8, 10..13}: <name>
**Status:** {PASS / DRIFT / GAP / {N} <issue>}
{Per-check details — counts, file lists, mismatch deltas — only when status is non-clean}

### Check 9: Sub-audits
- 9a R.E.S.T. — Reliability/Efficiency/Security/Traceability statuses
- 9b CLAUDE.md structure — PRESENT/WEAK/MISSING per section

### Proposed Fixes
{For each issue: one-line fix command or description}
```

One section per check. Keep the report factual: no opinions, no suggestions beyond fixing detected issues.
