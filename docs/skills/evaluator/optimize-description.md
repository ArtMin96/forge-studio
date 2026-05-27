# Optimize Description

`/optimize-description` runs a data-driven optimization loop to improve a skill's `description` field. You supply a skill path and a query corpus — at least eight positive queries (prompts that should trigger the skill) and eight negative ones (prompts that must not) — and the skill runs up to five iterations of train/validate refinement. Each iteration measures trigger rates, identifies false positives and false negatives, and generates a revised description via a sub-Claude call. The iteration with the highest validation pass rate is chosen as the winner — not the last iteration, which would risk overfitting. Results land in `result.json` alongside per-iteration workspaces.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/optimize-description --skill plugins/evaluator/skills/run-evals --corpus corpus/run-evals-queries.json
```

Required arguments: `--skill <path>` and `--corpus <queries.json>`. Optional: `--iterations N` (default 5), `--seed S` (default 0), `--mock` (dev/CI mode), `--out <dir>`.

## Why you need it

A skill's `description` field is its activation signal — it determines when Claude reaches for the skill versus ignoring it. A description that is too broad causes false positives (the skill fires when it shouldn't); one that is too narrow causes false negatives (the skill is never invoked when it should be). Both degrade the user experience, and neither is obvious from reading the description in isolation.

The only reliable way to tune a description is to measure it against real queries. `/optimize-description` does that systematically: it splits your corpus into training and validation sets for reproducibility, measures failure patterns at each iteration, and uses those patterns to guide the next revision — broadening when there are too many false negatives, narrowing when there are too many false positives. The result is a proposed description with a quantified improvement over the baseline, not a guess.

## When to use it

- When a skill has a measurable false-positive or false-negative trigger rate and you have a representative set of queries that demonstrate the problem.
- Before publishing a new skill, to confirm the description activates on the right prompts.
- After a description change, to measure whether the change actually improved or regressed trigger accuracy.

Do not use it for rubric scoring — use `/score-rubric` for that; and do not use it for benchmarking skill impact on outputs — use `/run-evals-bench` for that.

## Best practices

- **Build a corpus first.** The minimum of eight positive and eight negative queries is a hard requirement; the script exits immediately if either array is smaller. More realistic queries produce more useful results — aim for twenty or more per side if you can.
- **Keep iterations at five or fewer.** The default of five iterations with twenty queries per side already runs roughly three hundred sub-Claude calls. Higher iteration counts with larger corpora can reach into the thousands. Do not run this in batch across multiple skills in the same session.
- **Check `sanity_check_required`.** When the best validation pass rate is below 0.80, the result file sets `sanity_check_required: true`. That flag means the description improved but still needs human review before landing — do not feed it to `/commit-proposal` without reading it first.
- **Never publish mock-mode results.** The `--mock` flag skips real model calls and produces deterministic synthetic outputs for CI testing. Mock results are not meaningful as optimization evidence.

## How it improves your workflow

A poorly tuned description is a silent bug: the skill exists, the user needs it, but it never fires or fires at the wrong time. `/optimize-description` makes the description quality measurable and improvable. Instead of iterating manually — edit, observe, edit again — you get a systematic search over the description space with a quantified best result and a full audit trail of what was tried, what failed, and why. The validation pass rate in `result.json` is the evidence you need to justify the change before it lands.

## Related

- [`run-evals.md`](run-evals.md) — validates eval fixture shape before benchmarking
- [`run-evals-bench.md`](run-evals-bench.md) — measures skill output quality with vs. without injection; optimize-description tunes the trigger, bench measures the effect
- [`score-rubric.md`](score-rubric.md) — weighted criterion scoring; a different evaluation axis than trigger-rate optimization
- [Architecture](../../architecture.md) — where evaluation fits in the 8-component harness model
