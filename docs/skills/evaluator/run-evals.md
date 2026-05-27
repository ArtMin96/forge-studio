# Run Evals

`/run-evals` validates `evals/evals.json` fixtures against the per-skill eval convention. It checks that every file is named `evals.json`, that the top-level `skill_name` and `evals` fields are present and non-empty, and that each eval case has the required `id`, `prompt`, `files`, and `assertions` fields with at least one assertion. For every well-formed file it emits a human-readable checklist of declared assertions — each marked `[ ]` to indicate it has not yet been executed. Non-conformant files emit a specific error naming the exact field that failed. Exit code 0 means all files passed; exit 1 means at least one was invalid.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/run-evals plugins/my-plugin/skills/my-skill/evals/evals.json
```

The argument is a path to an `evals.json` file or a glob pattern. To validate all evals in a tree:

```text
/run-evals "plugins/*/skills/*/evals/evals.json"
```

## Why you need it

A malformed eval fixture causes silent failures downstream. If `id` is a string instead of an integer, if `assertions` is empty, or if `skill_name` is missing, a judge runner or benchmark tool will either crash with a confusing error or silently skip the case — giving you the false impression that all evals passed when none were actually run. Discovering that the fixture was invalid after running a full benchmark is expensive.

`/run-evals` catches those shape errors before they reach any runner. Because it reports the specific field that failed and continues to the next file rather than halting, you get a complete picture of all conformance issues in one pass. The `[ ]` checklist output for valid files also makes it easy to see exactly what assertions a judge will be asked to evaluate — a useful review step even when the fixture is already well-formed.

## When to use it

- When adding a new `evals/evals.json` file, to confirm it conforms to the required shape before handing it off to a runner.
- Before running `/run-evals-bench`, to verify the fixture is valid and avoid a confusing bench abort.
- When auditing eval coverage across multiple plugins, to identify skills with malformed or missing fixtures.

Do not use it for project lint or test execution — use `/healthcheck` for that; do not use it for criterion-weighted scoring — use `/score-rubric`; do not use it for with-skill vs without-skill benchmarks — use `/run-evals-bench`.

## Best practices

- **Fix `INVALID` files before running a bench.** The runner reports the exact missing or wrong field; fix it, then re-run `/run-evals` to confirm the fix before proceeding.
- **Read the `[ ]` checklist as a review step.** Each unchecked box is an assertion the judge runner will evaluate. If an assertion is vague or untestable, revise it now — a weak assertion that always passes provides no signal in a benchmark.
- **Keep one `evals.json` per skill.** The convention is one file under `plugins/<plugin>/skills/<skill>/evals/evals.json`, with all cases for that skill collected in the `evals` array. Multiple files per skill are not supported.
- **Check glob matches before interpreting a clean result.** If the glob matches no files, the runner exits 0 with `0 eval(s): 0 OK, 0 INVALID`. That exit 0 is not a pass — it means the glob was wrong. Verify the path pattern first.

## How it improves your workflow

Eval fixtures are the test suite for skills. `/run-evals` is the linter for that test suite — it ensures every fixture is structurally sound before any execution happens. The cost of running it is negligible; the cost of discovering a malformed fixture after a long benchmark run is not. It belongs at the start of any eval workflow: validate the shape first, then measure the behavior.

## Related

- [`run-evals-bench.md`](run-evals-bench.md) — runs the eval cases with and without skill injection to measure impact; requires a valid `evals.json`
- [`score-rubric.md`](score-rubric.md) — weighted criterion scoring; compose with eval fixtures for richer per-criterion analysis
- [`healthcheck.md`](healthcheck.md) — full project quality pipeline; not eval-specific
- [Architecture](../../architecture.md) — where evaluation fits in the 8-component harness model
