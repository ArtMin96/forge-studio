---
name: policy-audit
description: Report policy-gateway activity — secret/injection blocks and sensitive-op audits — pulled from the lineage ledger. Also scans the working tree for secrets that pre-date the plugin.
when_to_use: Periodic security checkup, before releases, or when /rest-audit Security axis flags issues.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# /policy-audit — Security Checkup

Two passes: ledger replay (what the plugin has blocked/audited) + live repo scan (what's sitting in the tree now).

## Pass 1 — Ledger replay

1. Read `.claude/lineage/ledger.jsonl` (if present).
2. Filter entries where `operator ∈ {policy-block, sensitive-op-audit}`.
3. Summarize by `evidence` label:
   - `secret-detected:<label>` — count per label, list resources
   - `pattern:<injection>` — count per pattern
   - `sensitive-op-audit` — count per file path
4. Emit top-line counts.

## Pass 2 — Live repo scan

1. Load the same `rules.d/secrets.txt` patterns used by `scan-secrets.sh`.
2. Run `grep -rEn -I --exclude-dir={.git,node_modules,vendor,.venv,dist,build}` over the repo for each pattern.
3. For each match, print `<file>:<line> <label>`.
4. Do NOT print the matched string itself — just file:line + label. Spilling secrets to logs is itself a leak.

## Output

```
POLICY AUDIT — <UTC>
=============================================

Ledger (last 30 days):
  secret-detected:aws-access-key  ×N
  secret-detected:github-pat      ×M
  pattern:ignore previous instructions  ×K
  sensitive-op-audit  ×P  (distinct files: Q)

Live scan:
  src/config.php:42   aws-access-key
  .env.backup:8       api-key-sk
  (no other matches)

Recommendations:
  - Rotate the 2 secrets found in the working tree
  - Add .env.backup to .gitignore
```

## Integration

- **Readers:** `/rest-audit` Security axis invokes this skill for deep dive.
- **Writers (ledger):** `scan-secrets.sh`, `scan-injection.sh`, `audit-sensitive-ops.sh`.
- **Evolves via SEPL:** `/evolve` can propose new rows for `rules.d/secrets.txt` or `rules.d/injection.txt`; each addition is a versioned resource.

## Failure Modes

- No ledger file → Pass 1 reports `no blocks recorded`.
- Rules file missing → Pass 2 skipped with a warning.
- grep not available → fallback to `find` + manual shell loop; slower but works.

## Do NOT

- Do not print matched secret values. File:line + label only.
- Do not auto-rotate / auto-redact. That's the user's decision; a false positive could destroy legitimate data.
