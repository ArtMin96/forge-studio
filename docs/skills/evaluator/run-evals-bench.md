# Run Evals Bench

`/run-evals-bench` measures whether a skill actually improves Claude's outputs. It runs a skill's eval cases with the skill injected and without, across N iterations each, and produces quantitative pass-rate and latency deltas per iteration. Each run writes `grading.json` with per-assertion evidence and a `benchmark.json` with mean, standard deviation, and delta across all eval cases. The result is a number you can defend when deciding whether to publish a skill or whether a description change improved or degraded performance.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/run-evals-bench --skill ssl-audit --iterations 3 --out /tmp/ssl-bench/
```

Required: `--skill <name-or-path>`. Optional: `--iterations N` (default 3), `--baseline {none,prev}`, `--out <dir>`, `--mock`.

## Why you need it

Publishing a skill without measuring its effect is an act of faith. A skill might produce better outputs in the author's mental model while producing the same or worse outputs in practice — because the description activates at the wrong times, because the instructions are ambiguous, or because the eval assertions were too weak to catch the difference. The only way to know is to run the eval cases both ways and look at the delta.

`/run-evals-bench` makes that comparison systematic and reproducible. Because it runs multiple iterations and reports standard deviation alongside mean pass rate, you can tell whether a `+0.4 delta.pass_rate` result is consistent across runs or just noise from a single lucky call. Because grading evidence must be a quoted substring of the actual output rather than a paraphrase, the pass/fail decisions are auditable after the fact.

## When to use it

- Before publishing a new skill, to confirm it produces a measurable improvement over the no-skill baseline.
- After a description change, to verify the change improved trigger accuracy and did not regress output quality.
- When comparing two versions of a skill to decide which to keep.

Do not use it for structural eval validation — use `/run-evals` to validate the `evals.json` shape first; do not use it for rubric-weighted scoring without a benchmark context — use `/score-rubric` for that.

## Best practices

- **Validate your `evals.json` with `/run-evals` first.** Bench exits immediately with `evals.json not found` if the fixture is missing or malformed. A clean `/run-evals` pass is the prerequisite.
- **Never publish mock-mode results.** The `--mock` flag produces deterministic synthetic outputs for CI use. Its grading evidence reflects synthetic strings, not real model output. Results from mock mode are not meaningful as publication evidence.
- **Watch the no-signal warning.** If an assertion passes in both `with_skill` and `without_skill` configurations, the bench emits a warning and the delta for that assertion is noise. Revise the assertion to test something the skill actually changes.
- **Budget your time.** Three iterations across two configurations with one eval case requires roughly six sub-Claude calls. With ten assertions and a slow prompt, a full bench run can take more than ten minutes. Do not run multiple skills in the same session.

## How it improves your workflow

`/run-evals-bench` converts "I believe this skill helps" into "I have measured that this skill increases pass rate by X with standard deviation Y." That shift from belief to evidence matters for every downstream decision: whether to publish, whether to keep a description change, whether to investigate why a skill's improvement is smaller than expected. The benchmark workspace persists as an audit trail — the grading evidence files let you trace exactly why each assertion passed or failed in each run.

## Related

- [`run-evals.md`](run-evals.md) — validates `evals.json` fixture shape; run before bench to confirm the fixture is well-formed
- [`optimize-description.md`](optimize-description.md) — optimizes the description field for trigger accuracy; bench measures output quality, not trigger accuracy
- [`score-rubric.md`](score-rubric.md) — weighted criterion scoring; compose with bench grading for richer per-criterion analysis
- [Architecture](../../architecture.md) — where evaluation fits in the 8-component harness model
