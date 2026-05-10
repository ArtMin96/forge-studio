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
scheduling: evals/evals.json exists at plugins/<plugin>/skills/<skill>/evals/evals.json
structural:
  - Resolve the path-or-glob argument to a list of JSON files
  - Reject any file not named evals.json; emit INVALID with expected/got message
  - Parse each file; emit INPUT_ERROR and exit 2 on malformed JSON
  - Validate top-level keys (skill_name, evals) and per-eval keys (id, prompt, files, assertions)
  - Emit INVALID with a specific reason on shape violation; continue to next file
  - On well-formed file, emit an OK checklist with declared assertions as unchecked boxes
  - Print a summary line; exit 0 if all OK, exit 1 if any INVALID
logical: all matched evals.json files are structurally valid and each emits a per-case checklist of declared assertions; non-conformant files emit specific errors and runner exits non-zero
---

# /run-evals — Eval JSON Structural Validator

Validates `evals/evals.json` fixtures against the per-skill evals convention. Does not execute the eval — emits a checklist of declared assertions that a future judge runner will tick. The `[ ]` boxes explicitly mark each assertion as "not yet executed."

## Inputs

Single positional argument: a path to `evals/evals.json` or a glob pattern (must match files named `evals.json`).

```
python3 plugins/evaluator/skills/run-evals/scripts/runner.py <evals.json-path-or-glob>
```

## Eval JSON Shape

Each `evals.json` file must be a JSON object with these top-level fields:

| Field | Type | Constraint |
|-------|------|-----------|
| `skill_name` | string | non-empty; name of the skill under test |
| `evals` | array | ≥ 1 eval case |

Each entry in `evals` must contain:

| Field | Type | Constraint |
|-------|------|-----------|
| `id` | integer | unique case identifier |
| `prompt` | string | non-empty; realistic user prompt |
| `files` | array | may be empty; each item is a string (path) or `{path: string, content: string}` |
| `assertions` | array of strings | ≥ 1 item; what the judge checks |
| `expected_output` | string | optional; reference output for literal comparison |

## Process

```bash
python3 plugins/evaluator/skills/run-evals/scripts/runner.py plugins/my-plugin/skills/my-skill/evals/evals.json
```

Or over all evals in a tree:

```bash
python3 plugins/evaluator/skills/run-evals/scripts/runner.py "plugins/*/skills/*/evals/evals.json"
```

## Output

For a well-formed file:

```
OK: plugins/diagnostics/skills/ssl-audit/evals/evals.json
  skill_name: ssl-audit
  evals: 1 case(s)
  [1] Audit SSL frontmatter coverage on a tree where one skill has no SSL fields...
    files: 1 declared
    assertions:
      [ ] validate.py exits 0 (informational, never failing)
      [ ] the report counts 1 skill scanned
      [ ] the report shows 0 skills with logical field

1 eval(s): 1 OK, 0 INVALID
```

For a non-conformant file:

```
INVALID: plugins/x/skills/y/evals/bad-name.json: expected evals.json, got bad-name.json

1 eval(s): 0 OK, 1 INVALID
```

## Convention

Eval fixtures live at:

```
plugins/<plugin>/skills/<skill>/evals/evals.json
```

One `evals.json` per skill. All eval cases for a skill are collected under the `evals` array in that file.

## Execution Checklist

- [ ] Run `runner.py` against target `evals.json` file(s)
- [ ] Confirm exit code: 0 = all OK, 1 = at least one INVALID, 2 = parse error
- [ ] Review the checklist output — each `[ ]` line is a declared assertion for the judge runner
- [ ] Fix any INVALID files before handing off to a judge runner

## Known Failure Modes

- **Wrong filename** — if the file is not named `evals.json`, the runner emits `INVALID: <path>: expected evals.json, got <basename>`. Rename the file.
- **Missing required key** — if `skill_name` or `evals` is absent at top level, or if a per-eval key (`id`, `prompt`, `files`, `assertions`) is absent, the runner emits `INVALID: <path>: missing required key '<key>'` and continues.
- **Empty `assertions`** — an empty assertions array is rejected. At least one assertion string is required per eval case.
- **Glob matches no files** — the runner prints `0 eval(s): 0 OK, 0 INVALID` and exits 0. Check the glob pattern.
