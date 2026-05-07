# diagnostics

Read-only health scanners for the marketplace and the projects you ship. No writes, no mutations — every skill reports.

## What it does

Documentation drifts. Plugins forget to register. SKILL.md frontmatter rots. This plugin runs the audits that catch those problems before they ship — entropy, registration gaps, convention violations, stale memory, hook timing, policy registry coverage.

## When to use

- Before tagging a release
- When a plugin "doesn't work" and you suspect a registration gap
- After several SEPL commits, to confirm docs and registry stayed in sync
- When session-open feels slow and you want per-hook latency

## How it works

Each skill is a self-contained audit. They run on demand, read everything, write nothing.

## Skills

| Skill | Purpose |
|---|---|
| `/entropy-scan` | Drift across docs / registry / hooks / memory / HARNESS_SPEC. Detects rot, not correctness |
| `/validate-marketplace` | Mechanical correctness — plugin registration, frontmatter, hook executability, token budget |
| `/policies-list` | Print every enforcement point — id, verdict, plugin, hook, severity — grouped by verdict |
| `/rest-audit` | R.E.S.T. cross-cut — Reliability, Efficiency, Security, Traceability. Single PASS/WARN/FAIL table |
| `/ssl-audit` | SKILL.md SSL overlay (scheduling/structural/logical) — flag skills missing measurable success criteria |
| `/claude-md-structure` | Karpathy 4-section audit on a CLAUDE.md (Think Before Coding · Simplicity First · Surgical Changes · Goal-Driven Execution) |
| `/docs-maintenance` | Documentation freshness, link validation, image checks, style consistency across all `*.md` / `*.mdx` |
| `/startup-profile` | Per-hook SessionStart latency + cold-vs-warm split |

## When to reach for which

| Symptom | Skill |
|---|---|
| "Did I forget to register a plugin?" | `/validate-marketplace` |
| "Is the architecture diagram still accurate?" | `/entropy-scan` |
| "Why is session start slow?" | `/startup-profile` |
| "Does this skill have measurable success criteria?" | `/ssl-audit` |
| "What does the harness actually block at runtime?" | `/policies-list` |
| "Are my project's docs current?" | `/docs-maintenance` |

## Hooks

Project-agnostic enforcement that fires on every project, not just this marketplace.

| Event | Hook | Effect |
|---|---|---|
| `PostToolUse` (`Edit\|Write`) | changelog-leak | Warn when written content has Sprint/Phase/changelog markers |
| `Stop` | stop-clean-tree | Block end-of-turn if staged or unstaged changes still contain Sprint/Phase markers |
| `Stop` | stop-docs-touched | Nudge when N+ code files changed but no canonical doc surface (README / CHANGELOG / docs/ / ADR / CLAUDE.md) was touched. Threshold env: `FORGE_DOCS_TOUCHED_THRESHOLD` (default 3) |

## Disable

`/plugin disable diagnostics@forge-studio`. Audits become unavailable; nothing else breaks.
