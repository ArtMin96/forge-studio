# Skill Staleness Audit

`/skill-staleness-audit` scores every SKILL.md in the marketplace against seven staleness signals and emits a ranked report in human-readable or JSON form. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/skill-staleness-audit
/skill-staleness-audit --format=json --threshold-stale=0.5
```

Optional flags: `--format=human|json` (default: human), `--threshold-stale=<0.0–1.0>` (default 0.50), `--threshold-aging=<0.0–1.0>` (default 0.75). JSON output is stable schema suitable for piping into `/auto-tune-skill` candidate selection.

## Why you need it

A marketplace that grows over time drifts. Skills that were accurate when written fall out of date as CLI surfaces evolve, eval suites are never created, SSL overlay fields go unpopulated, and citation recency decays. Without a systematic view, maintenance effort spreads thinly across all skills instead of concentrating where it matters most.

`/skill-staleness-audit` makes that concentration possible. Each skill receives a composite staleness score from 0.0 to 1.0 based on seven weighted signals: edit recency (how recently the SKILL.md was committed), eval coverage (whether a sibling `evals/evals.json` exists), SSL overlay completeness (how many of `scheduling`, `structural`, `logical` are populated), citation freshness (age of the most recent arXiv reference), description budget compliance (whether `description + when_to_use` stays within 1536 chars), exclusion clause presence, and helper extraction (whether long inline code blocks have been moved to `scripts/`). The result is a tiered list — stale, aging, fresh — that tells you exactly where to spend maintenance effort.

The skill is read-only and runs in an isolated fork context. It never modifies a SKILL.md.

## When to use it

- When planning a maintenance pass, to rank skills by how much attention they need.
- Before running [`/auto-tune-skill`](auto-tune-skill.md) on an unfamiliar surface, to identify the highest-leverage targets rather than guessing.
- After a quarterly review — per Anthropic's guidance that "configuration written for older models becomes overhead," staleness audits surface skills whose instructions have drifted past their useful life.

Do not use it for single-skill validation — use [`/ssl-audit`](../diagnostics/ssl-audit.md) instead, which runs the SSL frontmatter check on one skill in depth.

## Best practices

- **Start with JSON output when feeding `/auto-tune-skill`.** Pipe the JSON form through `jq '.skills | map(select(.score < 0.5)) | .[].path'` to get the stale candidate list directly. Human format is for reading; JSON format is for tooling.
- **Treat eval coverage as the highest-priority gap.** A skill with no `evals/evals.json` has a hard 0.0 on that signal regardless of everything else. Eval coverage unlocks `/auto-tune-skill` and provides the ground truth for all scoring — it is the most impactful gap to close.
- **Read sub-signal breakdowns before rewriting.** The human report shows `age:Nd evals:yes/no ssl:N/3 cite:...` per skill. A skill that scores low only on citation freshness needs a different fix than one that scores low on edit recency and eval coverage. Match the intervention to the signal.
- **Set custom thresholds when the defaults don't fit.** On a fast-moving project, 0.50 stale / 0.75 aging may classify too many skills as aging. Pass `--threshold-stale` and `--threshold-aging` to tune the tiers to your maintenance cadence.

## How it improves your workflow

`/skill-staleness-audit` turns marketplace maintenance from a vague obligation into a ranked to-do list. Instead of wondering which skills need attention, you get a scored, tiered inventory every time you run it. Combined with [`/auto-tune-skill`](auto-tune-skill.md), it forms a complete outer loop: audit surfaces the worst candidates, auto-tune proposes rewrites, you apply the best proposal, and the next audit confirms the score improved.

## Related

- [`/auto-tune-skill`](auto-tune-skill.md) — the skill that acts on this audit's output; feed stale candidates from `--format=json` directly to it
- [`../diagnostics/ssl-audit.md`](../diagnostics/ssl-audit.md) — single-skill SSL frontmatter validation; use when you want depth on one skill rather than breadth across all
- [`../evaluator/run-evals-bench.md`](../evaluator/run-evals-bench.md) — benchmark runner; the scoring backend that `/auto-tune-skill` calls after this audit identifies targets
- [Architecture](../../architecture.md) — self-evolution and quality gates in the 8-component harness model
