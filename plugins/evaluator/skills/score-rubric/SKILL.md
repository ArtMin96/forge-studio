---
name: score-rubric
description: Aggregate weighted criterion scores into a single rubric result. Reads a rubric JSON and a flat criterion-scores JSON, validates weight sum, and emits a result conforming to result.schema.json.
when_to_use: Reach for this when you have a rubric definition and a set of per-criterion raw scores and need a normalised aggregate in [0, 1] with a per-criterion breakdown. Supports scored (range-normalised), binary, and reference-based criteria. Do NOT use for SEPL-specific proposal reviews — use `/assess-proposal` instead; do NOT use for project lint — use `/healthcheck` instead.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
argument-hint: <rubric.json> <scores.json>
scheduling: rubric.json and criterion-scores.json both exist and rubric weights sum to 1.0 ± 1e-6
structural:
  - "Read rubric.json; verify required fields (name, version, criteria)"
  - "Assert abs(sum(criteria[].weight) - 1.0) < 1e-6; exit 1 on violation"
  - "Read criterion-scores.json; assert every rubric criterion id is present; exit 2 on missing id"
  - "Compute per-criterion weighted scores (scored: range-normalise; binary/reference-based: raw * weight)"
  - "Emit result JSON to stdout conforming to result.schema.json"
logical: weighted aggregate score in [0, 1] plus per-criterion breakdown emitted as JSON to stdout; exit 0 on success
---

# /score-rubric — Rubric Aggregator

Generic runner that converts per-criterion raw scores into a normalised weighted aggregate. Designed to compose with A/B variant declarations and single-run evaluation workflows.

## Inputs

Two positional arguments:

1. `<rubric.json>` — a rubric definition conforming to `plugins/evaluator/templates/rubric.schema.json`
2. `<scores.json>` — a flat JSON object mapping each criterion id to a raw score: `{"<id>": <number>, ...}`

Optional flag: `--variant control|treatment` — when set, `variantLabel` in the result is populated (used by a future comparator skill).

## Process

```bash
python3 plugins/evaluator/skills/score-rubric/scripts/score.py <rubric.json> <scores.json> [--variant control|treatment]
```

The script:

1. Loads and structurally validates the rubric (required keys present, criteria is a non-empty array).
2. Checks `abs(sum(criteria[].weight) - 1.0) < 1e-6`. Fails with exit 1 on violation.
3. Checks every rubric criterion id appears in the scores file. Fails with exit 2 on any missing id.
4. For each criterion:
   - `scored`: clamps raw to `[scale.min, scale.max]`; normalises to `(raw - min) / (max - min) * weight`.
   - `binary`: raw must be 0 or 1; contribution is `raw * weight`.
   - `reference-based`: raw must be 0 or 1 (matches reference); contribution is `raw * weight`.
5. Emits result JSON to stdout.

## Output

```json
{
  "rubricId": "summary-quality",
  "rubricVersion": "1.0.0",
  "score": 0.76,
  "perCriterion": [
    {"id": "accuracy",  "raw": 8, "weighted": 0.32},
    {"id": "brevity",   "raw": 6, "weighted": 0.24},
    {"id": "has-tl-dr", "raw": 1, "weighted": 0.20}
  ],
  "variantLabel": null,
  "winner": null,
  "delta": null,
  "confidence": null,
  "pValue": null
}
```

Single-run results set `variantLabel`, `winner`, `delta`, `confidence`, and `pValue` to null. A future comparator skill populates the A/B fields when diffing two variant results.

## Schema reference

- Rubric definition: `plugins/evaluator/templates/rubric.schema.json`
- Scoring result: `plugins/evaluator/templates/result.schema.json`
- A/B variant declaration: `plugins/evaluator/templates/variant.schema.json`

## Examples

### Example 1: three-criterion rubric, single run

Input (`rubric.json`):
```json
{
  "name": "summary-quality",
  "version": "1.0.0",
  "criteria": [
    {"id": "accuracy",  "type": "scored", "scale": {"min": 0, "max": 10}, "weight": 0.4},
    {"id": "brevity",   "type": "scored", "scale": {"min": 0, "max": 10}, "weight": 0.4},
    {"id": "has-tl-dr", "type": "binary",                                  "weight": 0.2}
  ]
}
```

Input (`scores.json`):
```json
{"accuracy": 8, "brevity": 6, "has-tl-dr": 1}
```

Output:
```json
{
  "rubricId": "summary-quality",
  "rubricVersion": "1.0.0",
  "score": 0.76,
  "perCriterion": [
    {"id": "accuracy",  "raw": 8, "weighted": 0.32},
    {"id": "brevity",   "raw": 6, "weighted": 0.24},
    {"id": "has-tl-dr", "raw": 1, "weighted": 0.20}
  ],
  "variantLabel": null,
  "winner": null,
  "delta": null,
  "confidence": null,
  "pValue": null
}
```

## Known Failure Modes

- **Weight sum not equal to 1.0** — `score.py` exits 1 with `WEIGHT_SUM_FAIL: <actual>` on stderr. Fix the rubric weights before re-running.
- **Missing criterion id** — if the scores file omits any id present in the rubric, `score.py` exits 2 with `INPUT_ERROR: missing criterion id '<id>'`. Add the missing entry to the scores file.
- **Wrong type for binary/reference-based** — raw score must be exactly 0 or 1. A float like 0.8 is rejected with `INPUT_ERROR` and exit 2. Use a `scored` criterion with an appropriate scale for partial-credit cases.
