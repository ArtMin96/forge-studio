---
name: failure-attribute
description: Use when a regression appears — a test that passed last week now fails, behavior changed unexpectedly, or you need to know which change introduced the problem before choosing a rollback target. Walks recent manifest entries in reverse-chronological order, re-runs each entry's declared verifier_obligations, and localizes the first entry that fails — the primary attribution candidate. Entries with no evidence bundle are flagged first as suspect-by-default.
when_to_use: Reach for this when a regression has just surfaced and the commit that introduced it is unclear. Also useful before `/rollback` when you want an evidence-grounded suggestion rather than guessing by date. Run with the optional N argument to widen the search window (default 20). Do NOT use for forward-looking risk analysis — use `/assess-proposal` instead.
argument-hint: "[N]"
disable-model-invocation: true
context: fork
allowed-tools:
  - Read
  - Bash
scheduling: a regression has just been detected and the causal manifest entry is unknown
structural:
  - Load N most-recent manifest entries from change_manifest.jsonl
  - Flag entries with absent, null, or empty evidence_bundle as suspect-by-default (priority 1)
  - For each remaining entry with verifier_obligations, run each command under a timeout; flag first failure as priority 2
  - Emit JSON report with primary_suspect and full suspects list
logical: JSON report emitted to stdout with primary_suspect identified (or null if no suspects); exit code 1 if any suspect found, 0 if clean
---

# /failure-attribute — Localize the Change That Broke Things

Attribution is mechanical when every manifest entry declares how to verify it. This skill re-runs those verifier obligations and finds the first one that fails — pointing at the change that introduced the regression.

## Background

arXiv:2605.18747 §3.5.2 describes the Evolution Agent diagnose stage: rather than relying on user memory or git bisect, the agent replays verification obligations from telemetry to localize the causal step. §5.1.1 reports that production attribution accuracy under naive approaches (Who&When, AgenTracer baselines) is only 14–53% — the gap closes when structured evidence is available. This skill closes that gap by requiring every manifest entry to carry verifier_obligations (via T2's change-manifest schema).

## Algorithm

1. **Load entries**: read the N most-recent lines from `.claude/evolution/change_manifest.jsonl` (default N=20).

2. **Empty-evidence predicate** (applied before verifier replay):
   - `evidence_bundle` key absent → suspect, reason: `no_evidence`, priority 1
   - `evidence_bundle: null` → suspect, reason: `no_evidence`, priority 1
   - `evidence_bundle: {}` → suspect, reason: `no_evidence`, priority 1
   - `evidence_bundle.checks_run` absent, null, or `[]` → suspect, reason: `no_evidence`, priority 1
   These entries are ranked above any verifier-failure suspects because they made no checkable claim.

3. **Verifier replay** (for entries with non-empty evidence_bundle and non-empty verifier_obligations):
   - Run each command via `timeout 10 bash -c <cmd>`. If exit non-zero: mark reason `verifier_failed`, capture stdout/stderr (truncated to 500 chars), add to suspects with priority 2.
   - Replay in reverse-chronological order; stop at first failure per entry (not per command).

4. **Emit report**: JSON to stdout with shape:
   ```json
   {
     "manifest_path": "...",
     "entries_examined": N,
     "suspects": [
       {
         "ts": "...", "agent": "...", "id": "...", "files": [...],
         "reason": "no_evidence|verifier_failed",
         "priority": 1,
         "evidence": {"command": "...", "exit_code": 0, "stdout_tail": "...", "stderr_tail": "..."}
       }
     ],
     "primary_suspect": "<suspects[0] if any else null>"
   }
   ```

## Execution Checklist

- [ ] Run `bash plugins/traces/skills/failure-attribute/scripts/attribute.sh [manifest-path] [N]`
- [ ] Review `primary_suspect` — if reason is `no_evidence`, flag for evidence addition and treat as the likely introduction point
- [ ] If reason is `verifier_failed`, read the `evidence.command` and `evidence.stdout_tail` fields to understand what broke
- [ ] Confirm the suspect entry's `files` field matches the area where the regression manifests
- [ ] Use the suspect `id` or `ts` to locate the corresponding git commit or `/rollback` target

## Examples

### Example 1 — Empty-evidence suspect

Input: manifest with three entries. Entry `chg-AAA` has `evidence_bundle: null`, entries `chg-BBB` and `chg-CCC` have proper evidence bundles and passing verifiers.

```bash
bash plugins/traces/skills/failure-attribute/scripts/attribute.sh .claude/evolution/change_manifest.jsonl 3
```

Output:
```json
{
  "manifest_path": ".claude/evolution/change_manifest.jsonl",
  "entries_examined": 3,
  "suspects": [
    {
      "ts": "2026-05-19T10:00:00Z",
      "agent": "generator",
      "id": "chg-AAA",
      "files": ["plugins/workflow/skills/rollback/SKILL.md"],
      "reason": "no_evidence",
      "priority": 1,
      "evidence": {"command": null, "exit_code": null, "stdout_tail": null, "stderr_tail": null}
    }
  ],
  "primary_suspect": {
    "ts": "2026-05-19T10:00:00Z",
    "agent": "generator",
    "id": "chg-AAA",
    "files": ["plugins/workflow/skills/rollback/SKILL.md"],
    "reason": "no_evidence",
    "priority": 1,
    "evidence": {"command": null, "exit_code": null, "stdout_tail": null, "stderr_tail": null}
  }
}
```

Exit: 1 (suspect found).

### Example 2 — Verifier-failure suspect

Input: manifest with entry `chg-BBB` whose `verifier_obligations` includes `test -f /nonexistent-file`. Evidence bundle is non-empty with `checks_run: ["json-parse"]`.

Output:
```json
{
  "manifest_path": ".claude/evolution/change_manifest.jsonl",
  "entries_examined": 5,
  "suspects": [
    {
      "ts": "2026-05-18T14:30:00Z",
      "agent": "agents:generator",
      "id": "chg-BBB",
      "files": ["plugins/traces/skills/trace-evolve/SKILL.md"],
      "reason": "verifier_failed",
      "priority": 2,
      "evidence": {
        "command": "test -f /nonexistent-file",
        "exit_code": 1,
        "stdout_tail": "",
        "stderr_tail": ""
      }
    }
  ],
  "primary_suspect": {
    "ts": "2026-05-18T14:30:00Z",
    "agent": "agents:generator",
    "id": "chg-BBB",
    "files": ["plugins/traces/skills/trace-evolve/SKILL.md"],
    "reason": "verifier_failed",
    "priority": 2,
    "evidence": {
      "command": "test -f /nonexistent-file",
      "exit_code": 1,
      "stdout_tail": "",
      "stderr_tail": ""
    }
  }
}
```

Exit: 1 (suspect found).

## Known Failure Modes

- **Verifier command path moved**: if a verifier_obligations command references a script that was renamed or deleted since the entry was written, the replay exits non-zero and blames the entry. The `evidence.command` field shows the exact command; confirm manually that the path still exists before accepting the attribution.
- **Verifier timeout**: commands that hang (e.g., waiting for a service) are killed after 10 seconds and treated as failures. Long-running integration tests should not be used as verifier_obligations; prefer `test -f`, `python3 -c`, or short bash assertions.
- **Manifest empty or missing**: exits 3 (no entries) or 2 (manifest not found). Check that `.claude/evolution/change_manifest.jsonl` exists and has content from recent sessions.
- **Legacy entries silently skipped**: entries without verifier_obligations (pre-T2 shape) are not blamed unless they also lack evidence_bundle. The no-evidence predicate still surfaces them, but the verifier-replay path is bypassed cleanly.
