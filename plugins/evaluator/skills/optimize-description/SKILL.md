---
name: optimize-description
description: Run a 5-iteration description-optimization loop for a skill. Splits a query corpus 60/40 train/val, measures trigger rates, refines the description toward higher validation pass rate, and emits a proposal with the best-iteration result.
when_to_use: Reach for this when a skill's description causes false-positive or false-negative trigger rates — you have a representative query corpus and want a data-driven improved description. Do NOT use for rubric scoring — use /score-rubric instead; do NOT use for benchmarking skill impact on outputs — use /run-evals-bench instead.
disable-model-invocation: true
argument-hint: --skill <path> --corpus <queries.json> [--iterations N] [--seed S] [--mock] [--out <dir>]
scheduling: target SKILL.md exists and a corpus JSON with ≥8 positive and ≥8 negative queries is available
structural:
  - Validate corpus has positive array (min 8) and negative array (min 8)
  - Split corpus 60/40 train/val by seed for reproducibility
  - For each iteration 1..N, run trigger-rate queries and compute train/val pass rates
  - Identify failure patterns (false negatives → broaden; false positives → narrow)
  - Generate one revised description per iteration via sub-Claude call with failure hints
  - Pick the iteration with the highest val_pass_rate (not the last — overfitting guard)
  - Write result.json with best_iteration, best_val_pass_rate, proposed_description, sanity_check_required
logical: result.json exists with best_iteration in [1..N] and best_val_pass_rate in [0,1]; best is chosen by max val_pass_rate, not last iteration
---

# /optimize-description — Description Optimization Loop

Iteratively refines a skill's `description` field using a query corpus, selecting the best revision by validation pass rate (not the last iteration, which may overfit to training queries).

**Cost note:** Default run is 3 calls × 20 queries × 5 iterations × 1 description-revision call/iter ≈ 305 sub-Claude calls. Run on one skill at a time, not in batch.

## Inputs

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `--skill <path>` | yes | — | Path to skill directory (e.g. `plugins/evaluator/skills/run-evals`) |
| `--corpus <queries.json>` | yes | — | Path to corpus JSON with `positive` and `negative` arrays (≥8 each) |
| `--iterations N` | no | 5 | Optimization iterations (default 5) |
| `--seed S` | no | 0 | Random seed for 60/40 split reproducibility |
| `--mock` | no | off | Synthetic mode — skips real sub-Claude calls (dev/CI) |
| `--out <dir>` | no | `/tmp/<skill>-optimize-<ts>/` | Output workspace |

```bash
python3 plugins/evaluator/skills/optimize-description/scripts/optimize.py \
  --skill plugins/evaluator/skills/run-evals \
  --corpus corpus/run-evals-queries.json \
  --iterations 5 \
  --seed 42
```

## Corpus Format

See `templates/corpus.schema.json` for the JSON Schema. Short form:

```json
{
  "positive": ["query that should trigger the skill", ...],
  "negative": ["query that must not trigger the skill", ...]
}
```

Each array requires ≥ 8 entries.

## Workspace Layout

```
<out>/
├── iteration-1/
│   ├── description.txt       candidate description for this iteration
│   ├── train_failures.json   {false_positives: [...], false_negatives: [...]}
│   └── val_pass_rate.json    {val_pass_rate: float, train_pass_rate: float}
├── iteration-2/
│   └── ...
└── result.json               best iteration selected by val_pass_rate
```

## result.json Schema

```json
{
  "best_iteration": 2,
  "best_val_pass_rate": 0.85,
  "current_val_pass_rate": 0.60,
  "proposed_description": "...",
  "sanity_check_required": true
}
```

`sanity_check_required` is `true` when `best_val_pass_rate < 0.80` — the proposed description improved but still needs human review before landing.

## Execution Checklist

- [ ] Prepare corpus JSON with ≥8 positive and ≥8 negative queries
- [ ] Run `optimize.py --skill <path> --corpus <file> --seed <N>`
- [ ] Inspect `result.json` — review `proposed_description` and `best_val_pass_rate`
- [ ] If `sanity_check_required: true`, manually review before using `/commit-proposal`
- [ ] Feed `result.json` into `/commit-proposal` (description-proposal input) for landing

## Known Failure Modes

- **Corpus too small** — if `positive` or `negative` has < 8 entries, script exits 1 with `corpus must have ≥8 positive and ≥8 negative queries`.
- **Mock mode is for dev/CI only** — `--mock` assigns deterministic trigger rates without calling the model. Results are not meaningful as optimization evidence.
- **Overfitting** — the script guards against picking the last iteration by tracking val pass rate separately. If all iterations produce the same val rate, `best_iteration=1` is chosen (first is safest).
- **Sub-Claude unavailable** — if `claude` binary is not in PATH, script exits 1. Use `--mock` for offline testing.
- **Cost explosion** — with `--iterations 10` and a 40-query corpus, expect ~1,240 sub-Claude calls. Keep iterations ≤ 5 and corpus ≤ 20 queries per session.
