---
name: sync-discovery
description: Use when you want to know whether a code pattern present in one repo also exists in another — shared utilities, copy-pasted blocks, or divergent implementations of the same convention. Searches both repos and emits a discovery.json classifying matches as only-in-a, only-in-b, or in-both (with a content-hash divergence flag).
when_to_use: Reach for this when comparing two repos for a specific pattern (regex). Do NOT use for dispatching work to multiple repos — use `/federated-fan-out` instead; do NOT use to aggregate results from a completed fan-out run — use `/aggregate-results` instead.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Write
scheduling: user wants to know whether a code pattern present in repo-a also exists in repo-b (e.g., shared utility, copy-pasted block, divergent implementation of the same convention)
structural:
  - Resolve absolute paths for repo-a and repo-b; validate both directories exist
  - Search repo-a for the pattern using git grep -nE (respects .gitignore)
  - Search repo-b for the same pattern using git grep -nE
  - Compute SHA-256 hash of each matched line's bytes for the in-both classification
  - Classify matches as only_in_a, only_in_b, or in_both (with divergent flag when hashes differ)
  - Emit discovery.json to --out path with the three sets
logical: discovery.json contains three keys (only_in_a, only_in_b, in_both) with lists; a match is in_both when the same line content appears in both repos; divergent is true when the matched-line bytes differ
---

# /sync-discovery — Cross-Repo Pattern Discovery

Compare a regex pattern across two repos. Classify every match as repo-A only, repo-B only, or present in both (with a divergence flag when the content hash differs).

## Invocation

```bash
python3 plugins/cross-repo/skills/sync-discovery/scripts/discover.py \
  --repo-a /path/to/repo-a \
  --repo-b /path/to/repo-b \
  --pattern 'def process_' \
  --out /tmp/discovery.json
```

## Output schema

```json
{
  "only_in_a": [{"file": "src/util.py", "line": 12, "hash": "abc123"}],
  "only_in_b": [],
  "in_both": [{"file_a": "src/util.py", "file_b": "lib/util.py", "hash_a": "abc123", "hash_b": "abc123", "divergent": false}]
}
```

See `templates/discovery.schema.json` for the full schema.

## Input/Output examples

**Input:** `--repo-a /code/api --repo-b /code/worker --pattern 'class AuthMiddleware'`

**Output:** `discovery.json` with `in_both: [{file_a: "middleware/auth.py", file_b: "src/auth.py", hash_a: "...", hash_b: "...", divergent: false}]`

---

**Input:** `--repo-a /code/api --repo-b /code/worker --pattern 'DEPRECATED'`

**Output:** `discovery.json` with all three lists populated based on which repo contains the pattern.

## Known Failure Modes

- `git grep` requires the path to be a git repository; non-git directories exit 1 with a clear message.
- Binary files are skipped by `git grep` automatically.
- The divergence hash compares matched-line bytes only, not surrounding context.
