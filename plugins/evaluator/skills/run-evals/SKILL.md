---
name: run-evals
description: Validate eval JSON files for structural conformance against the per-skill evals/ convention. Parses each file, checks required fields and types, and emits a human-readable checklist of declared expectations.
when_to_use: Reach for this when you want to confirm that eval fixtures are well-formed before handing them off to a judge runner, or when adding a new evals/ case and verifying its shape. Do NOT use for project lint or test execution — use `/healthcheck` instead; do NOT use for criterion-weighted scoring — use `/score-rubric` instead.
argument-hint: <eval-file-or-glob>
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
scheduling: eval JSON file(s) exist at plugins/<plugin>/skills/<skill>/evals/<case>.json
structural:
  - Resolve the path-or-glob argument to a list of JSON files
  - Parse each file; emit INPUT_ERROR and exit 2 on malformed JSON
  - Validate required fields (skills, query, files, expected_behavior) and their types
  - Emit INVALID with a specific reason on shape violation; continue to next file
  - On well-formed file, emit an OK checklist with declared expectations as unchecked boxes
  - Print a summary line; exit 0 if all OK, exit 1 if any INVALID
logical: all matched eval files are structurally valid and each emits a checklist of declared expectations; non-conformant files emit specific errors and runner exits non-zero
---

# /run-evals — Eval JSON Structural Validator

Validates eval fixture files against the per-skill `evals/` convention. Does not execute the eval — emits a checklist of declared expectations that a future judge runner will tick. The `[ ]` boxes explicitly mark each expectation as "not yet executed."

## Inputs

Single positional argument: a path to an eval JSON file or a glob pattern.

```
python3 plugins/evaluator/skills/run-evals/scripts/runner.py <eval-file-or-glob>
```

## Eval JSON Shape

Each eval file must be a JSON object with these four fields:

| Field | Type | Constraint |
|-------|------|-----------|
| `skills` | array of strings | ≥ 1 item |
| `query` | string | non-empty |
| `files` | array | may be empty; each item is a string (path) or `{path: string, content: string}` |
| `expected_behavior` | array of strings | ≥ 1 item |

## Process

```bash
python3 plugins/evaluator/skills/run-evals/scripts/runner.py plugins/my-plugin/skills/my-skill/evals/my-case.json
```

Or over all evals in a tree:

```bash
python3 plugins/evaluator/skills/run-evals/scripts/runner.py "plugins/*/skills/*/evals/*.json"
```

## Output

For a well-formed file:

```
OK: plugins/diagnostics/skills/ssl-audit/evals/no-ssl.json
  skills: ssl-audit
  query: "Audit SSL frontmatter coverage on a tree where one skill has no SSL fields..."
  files: 1 declared
  expected_behavior:
    [ ] validate.py exits 0 (informational, never failing)
    [ ] the report counts 1 skill scanned
    [ ] the report shows 0 skills with logical field

1 eval(s): 1 OK, 0 INVALID
```

For a non-conformant file:

```
INVALID: plugins/x/skills/y/evals/bad.json: missing required key 'expected_behavior'

1 eval(s): 0 OK, 1 INVALID
```

## Convention

Eval fixtures live at:

```
plugins/<plugin>/skills/<skill>/evals/<case>.json
```

Each case file is self-contained: it declares the skill(s) under test, a realistic query a user would type, any synthesized files needed, and the expected behaviors to assert. A single skill may have multiple case files (e.g. `no-ssl.json`, `partial-ssl.json`).

## Execution Checklist

- [ ] Run `runner.py` against target eval file(s)
- [ ] Confirm exit code: 0 = all OK, 1 = at least one INVALID, 2 = parse error
- [ ] Review the checklist output — each `[ ]` line is a declared expectation for the judge runner
- [ ] Fix any INVALID files before handing off to a judge runner

## Known Failure Modes

- **Missing required key** — if `skills`, `query`, `files`, or `expected_behavior` is absent, the runner emits `INVALID: <path>: missing required key '<key>'` and continues. Fix by adding the missing field.
- **Wrong type on `skills`** — `skills` must be a list of strings. A bare string like `"ssl-audit"` is rejected with `'skills' must be a non-empty list of strings`. Wrap in `[]`.
- **Empty `expected_behavior`** — an empty array is rejected. At least one assertion string is required.
- **Glob matches no files** — the runner prints `0 eval(s): 0 OK, 0 INVALID` and exits 0. Check the glob pattern.
