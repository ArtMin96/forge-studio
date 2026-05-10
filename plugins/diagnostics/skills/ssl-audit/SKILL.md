---
name: ssl-audit
description: Audit forge-studio SKILL.md frontmatter for the SSL overlay (scheduling / structural / logical). Reports skills missing a measurable success criterion. Read-only.
when_to_use: Reach for this when planning to harden skill discovery, before promoting a plugin to a "production" tier, or when `/entropy-scan` flags skill quality concerns. Do NOT use for marketplace registration or hooks-executable checks — that's `/validate-marketplace` and `/entropy-scan`; this skill scrutinises only frontmatter SSL fields.
paths:
  - "**/SKILL.md"
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
scheduling: skills/*/SKILL.md frontmatter exists and reflects current behavior
structural:
  - Walk plugins/*/skills/*/SKILL.md
  - Parse YAML frontmatter
  - Bucket each skill by which SSL field is present / absent
  - Print summary counts + a per-skill table for missing-logical
logical: returns a non-zero count of skills missing 'logical:' field, or 0 with a CLEAN summary
---

# /ssl-audit — SSL Frontmatter Coverage Report

Background: paper *Scheduling-Structural-Logical Representation for Agent Skills* (arXiv:2604.24026) separates a skill's preconditions (scheduling), decomposition (structural), and success criteria (logical) so an LLM can match-and-execute precisely. Forge's existing `description + when_to_use` carries scheduling and a hint of logic. The SSL overlay is additive, optional, and ships with this skill as the audit gate.

## Inputs

No arguments. The helper script walks `plugins/*/skills/*/SKILL.md` from the repo root.

## Process

Two tools are available. Use `audit.sh` for a quick presence count; use `validate.py` for typed shape and source-grounding checks.

**Presence count (lightweight):**
```bash
bash plugins/diagnostics/skills/ssl-audit/scripts/audit.sh
```

**Typed validator (deeper):**
```bash
python3 plugins/diagnostics/skills/ssl-audit/scripts/validate.py [root]
```

`root` defaults to `.`. Both tools write a markdown report to stdout.

## Output Format

```markdown
## SSL Audit
Skills scanned: N
With scheduling field: A
With structural field: B
With logical field: C
Missing logical (no measurable success criterion): D

### Skills missing `logical:`
- skills/<plugin>/<skill>
- ...
```

A non-zero "Missing logical" count is not a failure — most skills have not yet been retrofitted. Both `audit.sh` and `validate.py` are informational; neither causes a non-zero exit on findings.

## Schema

The typed vocabulary is defined in `plugins/diagnostics/skills/ssl-audit/schema/ssl.schema.json` (JSON Schema draft 2020-12, version `0.1-draft`).

The `0.1-draft` version tag signals that closed-vocabulary enums (`actions`, `resources`, `effects`) are seeds, not enforced contracts. Mismatches against them are emitted as `INFO`, not `WARN`. Future versions may tighten this. Consumers should check `version` before hardening against the enums.

## Execution Checklist

- [ ] Ran `bash plugins/diagnostics/skills/ssl-audit/scripts/audit.sh` from repo root
- [ ] Inspected the missing-logical list for high-traffic skills
- [ ] If a high-traffic skill is missing `logical`, opened a SEPL proposal to add it (slug: `skills/<plugin>/<skill>`)

## Examples

### Example 1: report on a tree with no SSL adoption

Input: a forge-studio checkout where no SKILL.md uses the SSL overlay.

Output:
```markdown
## SSL Audit
Skills scanned: N
With scheduling field: 0
With structural field: 0
With logical field: 0
Missing logical (no measurable success criterion): N

### Skills missing `logical:`
- skills/<plugin>/<skill>
- ...
```

### Example 2: report after partial adoption

Input: K high-traffic skills retrofitted with SSL fields.

Output:
```markdown
## SSL Audit
Skills scanned: N
With scheduling field: K
With structural field: K
With logical field: K
Missing logical (no measurable success criterion): N - K
...
```

## Known Failure Modes

- **Frontmatter without closing `---`** — the parser bails on the SKILL.md and counts it as missing all SSL fields. Surfaces as a noisy report rather than a crash.
- **Multi-document YAML** — not supported; treat the first frontmatter block as authoritative.
