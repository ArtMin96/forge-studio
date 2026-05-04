---
name: validate-marketplace
description: Pre-commit mechanical validator — checks plugin registration, SKILL.md frontmatter, hook executability, and token budget. Focuses on correctness; complements `/entropy-scan` which focuses on drift.
when_to_use: Reach for this before committing any change to `plugins/`, after editing `marketplace.json` or a SKILL.md frontmatter, before bumping a plugin version, or when `/entropy-scan` reports a registration gap and you want a focused pass. Do NOT use for documentation-vs-reality drift (counts, stale README) — that's `/entropy-scan`; validate-marketplace answers "will the install succeed?".
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
logical: report shows OK / FAIL per check; returns CLEAN when every check passes
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
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-parses.py
```

### Check 2 — Directory / Registration Equality

Every `plugins/*/` directory must have a marketplace entry whose `name` matches the directory and whose `source` points to `./plugins/<name>`. And vice versa.

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-registration.py
```

### Check 3 — SKILL.md Frontmatter Schema

Every SKILL.md must have `description`. Only the 2026 official fields are allowed; unknown keys are flagged.

Allowed fields (per code.claude.com/docs/en/skills, 2026 schema):
`name`, `description`, `when_to_use`, `argument-hint`, `arguments`,
`disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`,
`effort`, `context`, `agent`, `hooks`, `paths`, `shell`.

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-frontmatter.py
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
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-hooks-json.py
```

### Check 6 — Agent Schema + Skill Preload Coherence

Every agent `.md` in `plugins/*/agents/` must have valid frontmatter and any skill it preloads
must NOT have `disable-model-invocation: true` (per official docs: disabled skills cannot be
preloaded into a subagent — Claude Code silently skips them).

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-agents.py
```

### Check 7 — Skill Size Budget

Skills should stay under the compaction survival budget.

| Band | Character count | Approx tokens | Status |
|---|---|---|---|
| Ideal | ≤ 8,000 | ≤ 2,000 | OK |
| Warn | 8,001–20,000 | 2,000–5,000 | truncation risk after compaction |
| Fail | > 20,000 | > 5,000 | will be dropped after compaction |

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-skill-size.py
```

## Output Format

```markdown
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

## Execution Checklist

- [ ] Ran `check-parses.py` — `marketplace.json` parses, plugin count looks sane
- [ ] Ran `check-registration.py` — no missing entries, no missing dirs, no source-path mismatches
- [ ] Ran `check-frontmatter.py` — every SKILL.md frontmatter is valid YAML and within schema
- [ ] Ran the `find ! -perm -u+x` hook-executability check — clean
- [ ] Ran `check-hooks-json.py` — every `hooks.json` parses
- [ ] Ran `check-agents.py` — no banned fields, no disabled-skill preloads
- [ ] Ran `check-skill-size.py` — no file over the compaction-fail threshold
- [ ] Compiled the verdict (VALID / INVALID) and one-line remediation per failing check

## Known Failure Modes

- **YAML parse failure on backticks in `when_to_use`.** A field value that begins with a backtick (e.g. `` when_to_use: `/foo` after... ``) reads as YAML's tag indicator and rejects the file. The check reports `yaml error: ... cannot start any token`; fix by quoting the value or rewording so it starts with a letter.
- **Frontmatter delimiter mismatch.** SKILL.md missing the closing `---` reads as "no frontmatter" instead of "broken frontmatter". The reported failure looks like a missing `description` even though the field is there — check the closing delimiter first.
- **`source` path mismatch after rename.** Renaming a plugin directory without updating the `source: ./plugins/<name>` field in `marketplace.json` produces `SOURCE_PATH_MISMATCH` while every other check passes. The plugin still won't install.
- **Disabled-skill preload silently dropped.** An agent's `skills:` list referencing a SKILL.md with `disable-model-invocation: true` is silently skipped at runtime; the agent runs without the preload and the user sees no error. `check-agents.py` flags this so the misconfiguration surfaces before merge.
