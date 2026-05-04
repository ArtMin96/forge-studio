---
name: ssl-audit
description: Audit forge-studio SKILL.md frontmatter for the SSL overlay (scheduling / structural / logical). Reports skills missing a measurable success criterion. Read-only.
when_to_use: Reach for this when planning to harden skill discovery, before promoting a plugin to a "production" tier, or when `/entropy-scan` flags skill quality concerns. Do NOT use for marketplace registration or hooks-executable checks — that's `/validate-marketplace` and `/entropy-scan`; this skill scrutinises only frontmatter SSL fields.
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

```bash
bash plugins/diagnostics/skills/ssl-audit/scripts/audit.sh
```

Output is a markdown report on stdout. Pipe to a file if you want to keep it.

## Output Format

```
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

A non-zero "Missing logical" count is not a failure — most skills have not yet been retrofitted. The report is informational.

## Execution Checklist

- [ ] Ran `bash plugins/diagnostics/skills/ssl-audit/scripts/audit.sh` from repo root
- [ ] Inspected the missing-logical list for high-traffic skills
- [ ] If a high-traffic skill is missing `logical`, opened a SEPL proposal to add it (slug: `skills/<plugin>/<skill>`)

## Examples

### Example 1: report on a tree with no SSL adoption

Input: a forge-studio checkout where no SKILL.md uses the SSL overlay.

Output:
```
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
```
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
