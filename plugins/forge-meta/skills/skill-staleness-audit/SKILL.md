---
name: skill-staleness-audit
description: Score every SKILL.md in the marketplace against staleness signals (last-edit age, eval coverage, citation freshness, frontmatter compliance) and emit a ranked report. Read-only — never modifies a skill.
when_to_use: Reach for this when planning maintenance, before running /auto-tune-skill on an unfamiliar surface, or after a quarterly review per Anthropic's "configuration written for older models becomes overhead." Do NOT use for one-off skill edits — use /ssl-audit instead for single-skill validation.
argument-hint: "[--format=human|json] [--threshold-stale=0.5] [--threshold-aging=0.75]"
disable-model-invocation: true
context: fork
allowed-tools:
  - Read
  - Bash
  - Glob
paths:
  - "plugins/**/SKILL.md"
logical: Markdown or JSON report listing every SKILL.md with a 0.0–1.0 staleness score, classified into stale/aging/fresh tiers, with sub-signal breakdown
---

# /skill-staleness-audit — Staleness scoring for SKILL.md

Composable read-only audit. Pure scoring; never edits a SKILL.md. Output feeds `/auto-tune-skill` as a candidate selector — pipe the JSON form through `jq '.skills | map(select(.score < 0.5)) | .[].path'` to get the prioritized rewrite list.

## Run

```bash
bash plugins/forge-meta/skills/skill-staleness-audit/scripts/score.sh --format=human   # default
bash plugins/forge-meta/skills/skill-staleness-audit/scripts/score.sh --format=json
```

## Scoring signals

Each signal contributes a sub-score in `[0.0, 1.0]`. Total score is a weighted sum.

| Signal | Weight | Computation |
|---|---|---|
| Edit recency | 0.25 | `git log -1 --format=%ct` against the SKILL.md. `1.0` if ≤30 days, linear decay to `0.0` at 365 days, then `0.0`. |
| Eval coverage | 0.20 | `1.0` if a sibling `evals/evals.json` exists, else `0.0`. |
| SSL overlay | 0.15 | `(present_fields)/3` for `scheduling`, `structural`, `logical` in frontmatter (arXiv:2604.24026). |
| Citation freshness | 0.15 | Most recent `arXiv:NNNN.NNNNN` in body. `1.0` if ≤18 months old, `0.5` if ≤36 months, `0.0` otherwise. Skills with no citation get `0.5` (neutral). |
| Description budget | 0.10 | `description + when_to_use` total chars vs 1536 cap. `1.0` if ≤1280, linear decay to `0.0` at 1536. |
| Exclusion clause | 0.10 | `1.0` if `when_to_use` contains `Do NOT use for` (per CLAUDE.md frontmatter rule), else `0.0`. |
| Helper extraction | 0.05 | `1.0` if no inline ≥10-line code block in SKILL.md body (long helpers should live in `scripts/`). |

Tiers (defaults; override via flags):
- `stale` — score < 0.50
- `aging` — 0.50 ≤ score < 0.75
- `fresh` — score ≥ 0.75

## Output (human form)

```
SKILL STALENESS AUDIT — 75 skills, run at 2026-05-15T12:00:00Z

STALE (<0.50): N skills
  0.34  plugins/x/skills/y/SKILL.md  age:412d evals:no  ssl:0/3  cite:none
  ...
AGING (0.50–0.75): N skills
  ...
FRESH (>=0.75): N skills
```

JSON form: `{"runs_at":"…","totals":{"stale":N,"aging":N,"fresh":N},"skills":[{"path":"…","score":0.34,"tier":"stale","signals":{…}}…]}`. Stable schema for piping into `/auto-tune-skill`.

## Composes with

- `/auto-tune-skill` — feed `--format=json | jq` to surface stale candidates.
- `/ssl-audit` — single-skill SSL frontmatter validation (this skill aggregates across the marketplace).

## Known Failure Modes

- **Stale `git` mtime.** A freshly-cloned worktree resets file mtimes; the script reads commit time, not stat mtime, so this is not a problem in CI but can mislead on a `cp -a` mirror. Document the source repo if running outside the original clone.
- **No citation present.** A skill with no `arXiv:` reference scores `0.5` on freshness (neutral). Real skills without academic backing aren't penalized; skills with intentionally-stale citations are flagged.
