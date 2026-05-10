---
name: validate-marketplace
description: Pre-commit mechanical validator — checks plugin registration, SKILL.md frontmatter, hook executability, and token budget. Focuses on correctness; complements `/entropy-scan` which focuses on drift.
when_to_use: Reach for this before committing any change to `plugins/`, after editing `marketplace.json` or a SKILL.md frontmatter, before bumping a plugin version, or when `/entropy-scan` reports a registration gap and you want a focused pass. Do NOT use for documentation-vs-reality drift (counts, stale README) — that's `/entropy-scan`; validate-marketplace answers "will the install succeed?".
paths:
  - ".claude-plugin/marketplace.json"
  - "plugins/**/marketplace.json"
  - "plugins/**/SKILL.md"
  - "plugins/**/hooks.json"
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

Run the checks below. Stop at the first check that returns `FAIL` if time-constrained; otherwise run all and produce a structured report.

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

### Check 8 — Plugin Version Sync

Each `plugins/<name>/.claude-plugin/plugin.json` `version` must equal the corresponding `.claude-plugin/marketplace.json` entry. A mismatch ships a wrong version label to users.

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-version-sync.py
```

### Check 9 — Bash Syntax

Every shell script under `plugins/*/hooks/`, `plugins/*/skills/*/scripts/`, and `plugins/*/lib/` must pass `bash -n`. Catches syntax breakage before a hook fires at runtime.

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-bash-syntax.py
```

### Check 10 — Registry Budget

The `<available_skills>` block injected into the LLM context at runtime has a 15 000-byte ceiling. Only auto-loadable skills (those without `disable-model-invocation: true`) occupy this block; skills with that flag appear only in the user-facing `/` menu and are excluded from the count. This check sums `description+when_to_use` UTF-8 bytes across auto-loadable skills only.

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-registry-budget.py
```

### Check 11 — Body Line Cap

Every SKILL.md body (content after the closing `---` of frontmatter) must be under 500 lines. Longer bodies saturate the context window before the skill has finished reasoning (Source 5: Anthropic best-practices, 2026).

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-body-lines.py
```

### Check 12 — Name Shape

The `name:` field in every SKILL.md frontmatter must match `^[a-z0-9]+(-[a-z0-9]+)*$`: lowercase alphanumeric segments joined by single hyphens, no underscores, no consecutive hyphens, no leading/trailing hyphen.

```bash
python3 plugins/diagnostics/skills/validate-marketplace/scripts/check-frontmatter.py
```

## Output Format

One section per check, then a verdict.

```markdown
## Validate Marketplace Report

### Check N — <title>
Status: {OK / CLEAN / {N} failures / FAIL}
{check-specific lines: counts, file lists, deltas — only when non-clean}

### Verdict
Overall: {VALID / INVALID}
{One-line remediation per issue kind}
```

Per-check non-clean payloads:

| Check | Payload on failure |
|---|---|
| 1 marketplace parse | parser error |
| 2 registration | `Missing marketplace entry`, `Missing plugin directory`, `Source path mismatches` |
| 3 frontmatter | failing SKILL.md paths + reason |
| 4 hook exec | non-executable script paths |
| 5 hooks.json | parse-error path + line |
| 6 agents | unknown/banned fields, disabled-skill preloads |
| 7 size | `Oversized-fail (>5,000 tokens, dropped)`, `Oversized-warn (>2,000 tokens, truncation risk)` |
| 8 version sync | `(plugin, marketplace_version, plugin_json_version)` |
| 9 bash syntax | `(path, stderr)` |

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
- [ ] Ran `check-version-sync.py` — every plugin.json version matches marketplace.json
- [ ] Ran `check-bash-syntax.py` — every shell script parses
- [ ] Compiled the verdict (VALID / INVALID) and one-line remediation per failing check

## Known Failure Modes

- **YAML parse failure on backticks in `when_to_use`.** A field value that begins with a backtick (e.g. `` when_to_use: `/foo` after... ``) reads as YAML's tag indicator and rejects the file. The check reports `yaml error: ... cannot start any token`; fix by quoting the value or rewording so it starts with a letter.
- **Frontmatter delimiter mismatch.** SKILL.md missing the closing `---` reads as "no frontmatter" instead of "broken frontmatter". The reported failure looks like a missing `description` even though the field is there — check the closing delimiter first.
- **`source` path mismatch after rename.** Renaming a plugin directory without updating the `source: ./plugins/<name>` field in `marketplace.json` produces `SOURCE_PATH_MISMATCH` while every other check passes. The plugin still won't install.
- **Disabled-skill preload silently dropped.** An agent's `skills:` list referencing a SKILL.md with `disable-model-invocation: true` is silently skipped at runtime; the agent runs without the preload and the user sees no error. `check-agents.py` flags this so the misconfiguration surfaces before merge.
