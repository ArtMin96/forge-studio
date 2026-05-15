# forge-meta — local conventions

Read together with: ./README.md and ./POLICY.md

## What this plugin owns

The self-evolution boundary. Every harness change that proposes/applies/rolls back a skill, hook, or env var passes through here: change-manifest writer, evolution-history ledger, session-digest, auto-tune-skill outer loop, manifest-analyze reporter.

## Non-obvious invariants

- **Controllability.** `POLICY.md` defines paths the SEPL loop may not modify (originates from AHE 2604.25850 p.5 — the evolution agent must not disable its own oversight). New skills here must not write to those paths.
- **Manifest is append-only.** `change-manifest/scripts/append-manifest.sh` writes JSONL. Never rewrite or sort prior entries — `evolution-history` and `manifest-analyze` assume monotonic order.
- **auto-tune-skill never mutates the original.** It writes proposals to `.claude/proposals/<plugin>-<skill>-<ts>.md`. The user applies manually. No silent in-place edits.

## Files to read first when changing this plugin

1. `POLICY.md` — controllability invariant
2. `skills/change-manifest/SKILL.md` — ledger schema (every other skill here reads its output)
3. `skills/auto-tune-skill/scripts/score-candidate.sh:89-105` — the flock pattern that the rest of the marketplace now mirrors via `plugins/_lib/jsonl-append.sh`

## Cross-plugin dependencies

- `evaluator:/assess-proposal` — required between `/evolve` propose and `/commit-proposal`
- `traces:/trace-evolve` — one of the proposal sources `/evolve` consumes
- `workflow:/router-tune` — the other proposal source
