# Auto-Tune Skill

`/auto-tune-skill` runs a data-driven outer loop that iterates on a single SKILL.md body, scores each proposed rewrite using `/run-evals-bench`, and delivers the Pareto-best result as a proposal file for your review. It belongs to the `forge-meta` plugin, which handles the self-evolution boundary of Forge Studio's harness.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/auto-tune-skill diagnostics:entropy-scan
```

The argument is a `<plugin>:<skill-id>` pair. The skill reads `plugins/<plugin>/skills/<skill-id>/SKILL.md` as the starting baseline and requires a sibling `evals/evals.json` to score against.

## Why you need it

Rewriting a SKILL.md by hand is guesswork: you improve clarity in one place and accidentally introduce vagueness somewhere else, with no objective signal telling you whether the net change was an improvement. `/auto-tune-skill` replaces that guesswork with a scored search. Each iteration dispatches multiple mutation subagents in parallel, evaluates every candidate against the skill's eval suite, and selects only the candidate that dominates all others on both pass rate and token cost. The result is a proposal grounded in evidence rather than intuition.

The original SKILL.md is never touched. The proposal lands in `.claude/proposals/<plugin>-<skill>-<timestamp>.md` and waits for your manual review, diff, and apply. You are always in control of what goes to disk.

## When to use it

- A skill's eval pass rate has dropped below target and you want a systematic rewrite rather than an ad-hoc edit.
- The `when_to_use` guidance keeps misfiring — the skill is activating on the wrong prompts, or failing to activate on the right ones.
- You want a data-driven body rewrite without touching frontmatter fields like `name`, `description`, or the SSL overlay.
- Before running this on an unfamiliar surface, use [`/skill-staleness-audit`](skill-staleness-audit.md) with `--format=json` to surface the skills with the lowest staleness scores — those are the highest-leverage targets.

Do not use it for frontmatter edits or new-skill authoring — write or edit the SKILL.md directly instead.

## Best practices

- **Confirm evals exist first.** Running `run-iteration.sh` without a sibling `evals/evals.json` exits with an error immediately. Add eval cases before invoking this skill — tuning without evals is meaningless.
- **Use smoke-test mode before committing budget.** Set `FORGE_AUTO_TUNE_MOCK=1` to exercise the entire loop with synthetic scores. Candidates are still written and Pareto selection still runs; only the `claude -p` API calls are replaced with placeholders. Run smoke-test once, then run live.
- **Read the Change Contract before applying.** Every proposal includes a `## Change Contract` section with `failure_mode_targeted`, `predicted_improvement`, and a `falsifiable_by` shell command. Verify the contract fields make sense before copying the proposal over the original. If `/assess-proposal` refuses the file, the contract is incomplete — revise it before applying.
- **Apply then re-run evals.** After copying the proposal to the original path, run `/run-evals <plugin>:<skill-id>` directly to confirm the score improvement holds on HEAD.
- **Clean up orphaned backups.** If the process is forcibly killed mid-run, `score-candidate.sh`'s EXIT trap may leave `*.autotune-bak.<pid>` files in the skill directory. Run `find plugins -name '*.autotune-bak.*' -delete` to clear them.

## How it improves your workflow

`/auto-tune-skill` closes the feedback loop between a skill that misfires and a skill that works. Instead of editing by feel, you get a scored proposal with a documented pass rate and a falsifiable contract. The outer loop's Pareto frontier ensures the winning candidate doesn't just pass more evals — it also stays lean on token cost, keeping your harness efficient as skills evolve over time.

## Related

- [`/skill-staleness-audit`](skill-staleness-audit.md) — surfaces the lowest-scoring skills across the marketplace; use to choose targets before invoking this skill
- [`/run-evals-bench`](../evaluator/run-evals-bench.md) — the scorer this skill calls internally; invoke directly to benchmark a candidate manually
- [`/assess-proposal`](../evaluator/assess-proposal.md) — validates the Change Contract in the proposal before you apply it
- [`/change-manifest`](change-manifest.md) — the evolution ledger entry written when a proposal is eventually applied
- [Architecture](../../architecture.md) — self-evolution boundaries in the 8-component harness model
