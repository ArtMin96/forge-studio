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

After the missing-logical list, `audit.sh` prints a second subsection:

```markdown
### Routing/dispatch skills missing `logical:`
(none — all routing/dispatch skills have a logical post-condition)
```

An empty list in this subsection is the healthy, expected result — it means every routing/dispatch skill already carries a post-condition. Do not mistake an empty subsection for a broken check.

## Schema

The typed vocabulary is defined in `plugins/diagnostics/skills/ssl-audit/schema/ssl.schema.json` (JSON Schema draft 2020-12, version `0.1-draft`).

The `0.1-draft` version tag signals that closed-vocabulary enums (`actions`, `resources`, `effects`) are seeds, not enforced contracts. Mismatches against them are emitted as `INFO`, not `WARN`. Future versions may tighten this. Consumers should check `version` before hardening against the enums.

## Routing-skill post-conditions

Routing and dispatch skills are recognized by `audit.sh` as those whose `name` or `description` field matches `rout(e|ing)|dispatch|orchestrate`. These skills occupy the decision-making junctions of multi-agent workflows: they determine which subagent runs, which branch executes, and which goal gets delegated.

The paper *From Model Scaling to System Scaling* (arXiv:2605.26112 §4.3) explains why this matters: the S⊥G coupling (strategy–goal independence) is the point where routing errors compound fastest. A routing skill without a `logical` post-condition has no verifiable success criterion, so an incorrect dispatch decision propagates silently through downstream agents. This is why any routing skill missing `logical` is called out as higher-priority than a non-routing gap of the same kind.

`audit.sh` prints a `### Routing/dispatch skills missing logical:` subsection after the general missing-logical list. An empty subsection — `(none — all routing/dispatch skills have a logical post-condition)` — is the healthy, expected result, not a sign that the check is broken. The six routing/dispatch skills currently in the tree (`workflow/orchestrate`, `workflow/router-tune`, `workflow/tdd-loop`, `workflow/evolve`, `agents/dispatch`, `agents/fan-out`) all carry `logical` fields.

## Execution Checklist

- [ ] Ran `bash plugins/diagnostics/skills/ssl-audit/scripts/audit.sh` from repo root
- [ ] Inspected the missing-logical list for high-traffic skills
- [ ] Cross-referenced the missing-`logical` list against routing/dispatch skill names; flagged any intersection as high-priority (the `### Routing/dispatch skills missing logical:` subsection does this automatically)
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
