---
name: aggregate-results
description: Use after a /federated-fan-out run to collect per-repo result.json files, de-duplicate identical summaries by content hash, and emit a per-repo verdict matrix and aggregated.json summary into the workspace.
when_to_use: Reach for this when a fan-out run has completed (or partially completed) and you want a unified report. Do NOT use for dispatching work across repos — use `/federated-fan-out` instead. Do NOT use for scoring a single run against a rubric — use `/score-rubric` instead.
disable-model-invocation: true
scheduling: a /federated-fan-out run completed (or partially completed) and the user wants a unified report across the per-repo result.json files
structural:
  - Resolve ~/.forge-cross-repo/<run-id>/ workspace; exit 1 if it does not exist
  - Read each <repo>/result.json; collect status, summary, and artifact list
  - De-duplicate identical summaries by content-hash and report cluster size
  - Emit a per-repo verdict matrix (PASS, FAIL, SKIPPED) to stdout
  - Write aggregated.json to the workspace with one entry per repo
  - Append an aggregate_complete ledger entry to ledger.jsonl
logical: aggregated.json contains one entry per repo with verdict and summary_cluster_id; verdict matrix prints to stdout; ledger gets a final aggregate_complete line
---

# /aggregate-results — Cross-Repo Result Aggregation

Collect per-repo `result.json` files from a `/federated-fan-out` run, de-duplicate identical summaries, and emit a verdict matrix.

## Invocation

```bash
python3 plugins/cross-repo/skills/aggregate-results/scripts/aggregate.py --run-id <id>
```

## Output

Prints a per-repo verdict matrix to stdout:

```
repo                  verdict     cluster  summary
------------------------------------------------------------
repo-a                PASS        c1       applied patch ok
repo-b                PASS        c1       applied patch ok
repo-c                FAIL        c2       exit code 1: ...
```

Writes `~/.forge-cross-repo/<run-id>/aggregated.json`:

```json
{
  "run_id": "my-run",
  "repos": [
    {"repo": "repo-a", "verdict": "PASS", "summary": "...", "summary_cluster_id": "c1"},
    {"repo": "repo-b", "verdict": "PASS", "summary": "...", "summary_cluster_id": "c1"},
    {"repo": "repo-c", "verdict": "FAIL", "summary": "...", "summary_cluster_id": "c2"}
  ]
}
```

## Input/Output examples

**Input:** `--run-id my-audit` (workspace has r1, r2, r3 subdirs each with result.json)

**Output:** aggregated.json with three entries; two sharing a cluster_id if their summaries matched.

---

**Input:** `--run-id missing-run`

**Output:** exit 1 with `workspace ~/.forge-cross-repo/missing-run/ does not exist`.

## Known Failure Modes

- A repo subdir with no `result.json` is reported as `SKIPPED`.
- If the workspace has zero repo subdirs with result.json, aggregated.json has an empty `repos` list.
