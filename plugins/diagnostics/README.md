# diagnostics

Drift-detection, audit, and runtime safety for the harness. Most diagnostics skills are user-invoked slash commands that report without writing anything. The one exception is `doom-loop.sh` — a runtime guard, added as the first active hook in this plugin, that detects when Claude is repeating the same tool call in a tight loop and escalates from warning to block.

## What it does

Documentation drifts. Plugins forget to register. SKILL.md frontmatter rots. Claude can loop. This plugin covers all four: the audit skills catch problems before they ship; the doom-loop hook catches runaway behavior at runtime before it exhausts the token budget.

## When to use

- Before tagging a release: run `/entropy-scan` + `/validate-marketplace`
- When a plugin "doesn't work" and you suspect a registration gap: `/validate-marketplace`
- After several plugin edits, to confirm docs and registry stayed in sync: `/entropy-scan`
- When session startup is slow: `/startup-profile`
- To see everything the harness blocks at runtime: `/policies-list`
- The doom-loop hook is passive — you do not invoke it; it fires automatically

## Skills

| Skill | Command | What it does | When to use |
|-------|---------|-------------|-------------|
| entropy-scan | `/entropy-scan` | Scans the marketplace for documentation drift, registration gaps, convention violations, stale memory, and HARNESS_SPEC invariant compliance. Reports only — no writes | Weekly, before releases, after large refactors, or when README header counts feel suspect |
| validate-marketplace | `/validate-marketplace` | Pre-commit mechanical validator: checks plugin registration, SKILL.md frontmatter correctness, hook executability, token budget, and registry budget. Answers "will the install succeed?" | Before committing any change to `plugins/`, after editing `marketplace.json` or a SKILL.md frontmatter |
| rest-audit | `/rest-audit` | Audits against the R.E.S.T. framework (Reliability, Efficiency, Security, Traceability) — reads ledger entries, hook state, and artifact presence across multiple plugins. Single PASS/WARN/FAIL table | Periodic checkup, before releases, or when investigating a multi-plugin regression |
| ssl-audit | `/ssl-audit` | Audits SKILL.md frontmatter for the SSL overlay fields (`scheduling`, `structural`, `logical`). Reports skills missing a measurable success criterion | Before promoting a plugin, or when `/entropy-scan` flags skill quality concerns |
| md-structure | `/md-structure [path]` | Audits a CLAUDE.md against the Karpathy 4-section structure (Think Before Coding · Simplicity First · Surgical Changes · Goal-Driven Execution) | When authoring a fresh CLAUDE.md or reviewing one for structural completeness |
| docs-maintenance | `/docs-maintenance` | Comprehensive documentation audit: freshness, link validation, image checks, style consistency across `*.md` / `*.mdx` files | Before a release, after major content changes, or when investigating doc drift and broken links |
| policies-list | `/policies-list` | Prints every policy enforcement point from `plugins/diagnostics/registry/policies.json` — id, verdict, plugin, hook event, severity, bypass — grouped by verdict | Onboarding, or before turning off a plugin and wanting to know what enforcement disappears |
| startup-profile | `/startup-profile` | Reads the SessionStart timing log and reports per-hook duration plus cold-vs-warm split across recent sessions | When session startup feels slow, or after adding a SessionStart hook to verify it stays within budget |

## When to reach for which

| Symptom | Skill |
|---------|-------|
| "Did I forget to register a plugin?" | `/validate-marketplace` |
| "Is the architecture diagram still accurate?" | `/entropy-scan` |
| "Why is session start slow?" | `/startup-profile` |
| "Does this skill have measurable success criteria?" | `/ssl-audit` |
| "What does the harness actually block at runtime?" | `/policies-list` |
| "Are my project's docs current?" | `/docs-maintenance` |

## Hooks

| Hook | Event | Matcher | When it fires | What it does |
|------|-------|---------|--------------|-------------|
| `doom-loop.sh` | `PostToolUse` | (none — fires after every tool call) | After every tool use | Runtime guard against repeated identical tool calls. Fingerprints each call as `<tool_name>\t<md5(tool_input)>` and keeps a sliding window of the last 20 fingerprints in `/tmp/forge-doom-<session>`. When the same fingerprint appears ≥3 times in the window: exits 1 (warning on stderr). ≥5 times: exits 2, blocking the next tool call until you delete the state file. Based on Terminal-Agents 2603.05344 p.15–16 Algorithm 1. Without this hook, there is no runtime defense against the agent reading the same file 20 times in a tight loop |

## How to use it

Run `/entropy-scan` to verify drift between README counts and on-disk state. Run `/ssl-audit` to check SKILL.md frontmatter coverage. Run `/validate-marketplace` before any `git commit` that touches plugin files.

The doom-loop hook is passive — it fires automatically after every tool call. You will see a stderr warning if looping starts. If it escalates to a block (≥5 identical calls), delete `/tmp/forge-doom-<CLAUDE_SESSION_ID>` to clear the state and resume.

## Disable

`/plugin disable diagnostics@forge-studio`. Audits become unavailable; the doom-loop runtime guard also stops firing. Nothing else breaks.
