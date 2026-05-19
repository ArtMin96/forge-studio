---
name: policy-audit
description: Report policy-gateway activity — secret/injection blocks and sensitive-op audits — pulled from the lineage ledger. Also scans the working tree for secrets that pre-date the plugin.
when_to_use: Reach for this on periodic security checkup, before releases, or when `/rest-audit`'s Security axis flags an issue and a focused replay is needed. Do NOT use for real-time blocking — that's the `scan-secrets.sh` and `scan-injection.sh` PreToolUse hooks; policy-audit is the after-the-fact audit and live-tree backstop.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
logical: report counts policy-block ledger entries by label and lists secret-pattern findings as <file>:<line>
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

```text
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

## Execution Checklist

- [ ] Pass 1.1 — read `.claude/lineage/ledger.jsonl` (if present)
- [ ] Pass 1.2 — filter entries where `operator ∈ {policy-block, sensitive-op-audit}`
- [ ] Pass 1.3 — summarize by `evidence` label (`secret-detected:<label>`, `pattern:<rule>`, `sensitive-op-audit`)
- [ ] Pass 1.4 — emit top-line counts
- [ ] Pass 2.1 — load patterns from `rules.d/secrets.txt` (same source as `scan-secrets.sh`)
- [ ] Pass 2.2 — `grep -rEn -I --exclude-dir={.git,node_modules,vendor,.venv,dist,build}` for each pattern
- [ ] Pass 2.3 — print `<file>:<line> <label>` per match (never the matched string)
- [ ] Pass 2.4 — emit the POLICY AUDIT report combining ledger + live-scan findings

## Examples

Input: `.claude/lineage/ledger.jsonl` contains 3 `policy-block` entries (2 `secret-detected:aws-access-key`, 1 injection-rule match from `rules.d/injection.txt:5`) and 8 `sensitive-op-audit` entries. Live scan finds 1 match in `src/config.php:42` and 1 in `.env.backup:8`.

Output:
```text
POLICY AUDIT — 2026-05-19T09:42:11Z
=============================================

Ledger (last 30 days):
  secret-detected:aws-access-key  ×2
  pattern:system-prompt-override  ×1
  sensitive-op-audit  ×8  (distinct files: 5)

Live scan:
  src/config.php:42   aws-access-key
  .env.backup:8       api-key-sk

Recommendations:
  - Rotate the 2 secrets found in the working tree
  - Add .env.backup to .gitignore
```

Input: fresh project — no `.claude/lineage/ledger.jsonl`, working tree clean.

Output:
```text
POLICY AUDIT — 2026-05-19T09:42:11Z
=============================================

Ledger (last 30 days):
  no blocks recorded

Live scan:
  (no matches)
```

## Integration

- **Readers:** `/rest-audit` Security axis invokes this skill for deep dive.
- **Writers (ledger):** `scan-secrets.sh`, `scan-injection.sh`, `audit-sensitive-ops.sh`.
- **Evolves via SEPL:** `/evolve` can propose new rows for `rules.d/secrets.txt` or `rules.d/injection.txt`; each addition is a versioned resource.

## Known Failure Modes

- **No ledger file.** Pass 1 reports `no blocks recorded`. Expected on a fresh project — not an error.
- **Rules file missing.** Pass 2 is skipped with a warning, not failed. The audit downgrades gracefully so a misconfigured plugin can't block all reporting.
- **`grep` not available.** Fallback uses `find` + a manual shell loop. Slower; output identical.
- **High-entropy false positives.** Long random-looking IDs (UUIDs, content hashes, fixture data) trip the entropy heuristic. The skill reports them; the human triages — never auto-redact.
- **Secret hidden inside a base64-encoded blob.** The regex layer misses it because the raw bytes aren't visible. Detection requires either a decoder pre-pass or a separate semgrep policy; flag it as `LIMITATION` in the report rather than a clean pass.
- **Audit run *during* an active block.** If `safe-mode` is on, the audit can read but not stage rule updates. Resolve the active failure first, then re-run.

## Do NOT

- Do not print matched secret values. File:line + label only.
- Do not auto-rotate / auto-redact. That's the user's decision; a false positive could destroy legitimate data.
