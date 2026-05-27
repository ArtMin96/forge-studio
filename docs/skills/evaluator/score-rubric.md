# Score Rubric

`/score-rubric` aggregates per-criterion raw scores into a single normalized weighted result. You give it a rubric JSON defining criteria, types, scales, and weights, plus a flat scores JSON mapping each criterion id to a raw score. It validates that the rubric weights sum to exactly 1.0, that every criterion in the rubric has a corresponding score entry, computes each criterion's weighted contribution using the appropriate normalization (range-normalized for `scored` criteria, binary 0/1 for `binary` and `reference-based`), and emits a result JSON to stdout conforming to `result.schema.json`. It is a pure computation — no model calls, no file writes.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/score-rubric rubric.json scores.json
```

Two positional arguments: the rubric definition and the scores file. Optional: `--variant control|treatment` for A/B comparisons.

## Why you need it

Evaluation rubrics are only useful if the aggregation is correct and consistent. When you compute weighted scores by hand — especially across three or more criteria with different scales — errors compound: a criterion with a `0–10` scale has a different contribution to the aggregate than one with a `0–1` scale, and normalizing incorrectly produces a final score that is misleading even when the raw numbers are right.

`/score-rubric` eliminates that class of error. By declaring criterion types and scales in the rubric JSON and letting the script handle all normalization, you guarantee that a raw score of 8 on a `0–10` scale and a raw score of 0.8 on a `0–1` scale receive identical weighted contributions. The weight-sum validation catches rubric authoring mistakes before they silently distort results. The `perCriterion` breakdown in the output makes every contribution visible rather than hiding it behind a single aggregate number.

## When to use it

- When you have a rubric definition and a set of per-criterion raw scores and need a normalized aggregate score in `[0, 1]`.
- When composing evaluation workflows — for example, grading eval case outputs from `/run-evals-bench` against a quality rubric.
- When running A/B comparisons between two skill variants, using `--variant control` and `--variant treatment` on each respective run.

Do not use it for SEPL-specific proposal reviews — use `/assess-proposal` for that; do not use it for project lint — use `/healthcheck` instead.

## Best practices

- **Validate rubric weights before the first run.** The script exits 1 with `WEIGHT_SUM_FAIL` if the weights do not sum to `1.0 ± 1e-6`. Check that your rubric's criteria weights add up precisely — floating-point arithmetic can produce small errors like `0.9999999` that fail the check.
- **Use `scored` criteria for partial-credit cases.** The `binary` and `reference-based` types only accept exactly 0 or 1. If you have a criterion where partial credit makes sense — correctness on a scale of 0 to 10 — use `scored` with the appropriate `scale`.
- **Keep the rubric stable across comparisons.** The `--variant` flag is designed for comparing two runs of the same rubric. Changing criteria or weights between runs makes the comparison meaningless.
- **Read the `perCriterion` breakdown.** An aggregate score of 0.76 is less informative than knowing which criteria are pulling it up and which are pulling it down. The breakdown is where the actionable signal lives.

## How it improves your workflow

A rubric without consistent aggregation is just a list of opinions. `/score-rubric` converts it into a reproducible computation: the same inputs always produce the same output, the normalization is transparent, and the weight-sum validation catches authoring errors before they corrupt results. Combined with the A/B variant fields in the output schema, it provides a foundation for comparing skill versions, measuring description changes, and grading eval outputs with a defined quality standard.

## Related

- [`run-evals-bench.md`](run-evals-bench.md) — comparative skill benchmark; compose with score-rubric to grade benchmark outputs
- [`run-evals.md`](run-evals.md) — validates eval fixture shape; the fixtures feed the outputs that score-rubric grades
- [`assess-proposal.md`](assess-proposal.md) — SEPL proposal gate with its own four-criterion rubric; score-rubric is the generic equivalent for non-SEPL use
- [Architecture](../../architecture.md) — where evaluation fits in the 8-component harness model
