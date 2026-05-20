---
name: belief-audit
description: Use when a long session has compacted or handed off, before any Edit, to confirm Claude's belief about file contents still matches disk. Diffs current sha256 signatures against the last-recorded snapshot in `.claude/state/belief.jsonl` for the N most-recently-edited files (default 5).
when_to_use: Reach for this after session compaction, after a handoff from another agent, or manually when returning to a file after a long absence. Also fires automatically on PostCompact. Do NOT use for runtime behavior verification — use `/verify` instead.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
scheduling: invoke after compaction, after agent handoff, or before re-editing files touched more than one session ago
structural:
  - Read .claude/state/belief.jsonl for the N most-recent unique paths
  - Re-compute sha256 for each path on disk now
  - Compare recorded signature vs current signature per path
  - Emit drift report (drifted paths + both hashes) and exit 1 if any drift found
logical: drift report emitted; exit 0 when all signatures match, exit 1 when any path has drifted
---

# /belief-audit — Belief-State Drift Detection

After compaction, Claude's internal model of what's in a file can differ from disk reality (arXiv:2605.18747 §4.3 formalizes this as `|Bk − Sk|` — the gap between the agent's belief `Bk` and the actual system state `Sk`). Every Edit/Write is snapshotted automatically; this skill compares the stored signatures against current disk to surface divergence before it causes bugs.

## Execution Checklist

- [ ] Run `bash scripts/audit.sh [N]` (default N=5) — reads `.claude/state/belief.jsonl`, takes the latest entry per unique path, limits to N most-recent unique paths
- [ ] Script re-computes sha256 of each path on disk
- [ ] Script emits drift report: drifted paths with recorded vs current hash; summary count for unchanged paths
- [ ] Check exit code: 0 = no drift, 1 = drift detected — if 1, re-read the flagged files before any further edits

## Input / Output Examples

**Example 1 — No drift**

Input:
```
.claude/state/belief.jsonl (last 5 unique paths):
{"ts":"2026-05-20T10:00:00Z","path":"plugins/context-engine/hooks/track-edits.sh","sha256":"abc123...","agent":"main","op":"post","session_id":"s-1"}
{"ts":"2026-05-20T10:01:00Z","path":"README.md","sha256":"def456...","agent":"main","op":"post","session_id":"s-1"}
```

Output:
```markdown
## Belief-State Audit (2 files checked)

All 2 files match recorded signatures.
Exit: 0 (no drift)
```

**Example 2 — Drift detected**

Input:
```
.claude/state/belief.jsonl (last 5 unique paths):
{"ts":"2026-05-20T09:00:00Z","path":"plugins/context-engine/hooks/track-edits.sh","sha256":"abc123...","agent":"main","op":"post","session_id":"s-1"}
```
(file was edited externally between sessions)

Output:
```markdown
## Belief-State Audit (1 file checked)

DRIFT DETECTED — 1 file(s) have changed since last snapshot:

| Path | Recorded sha256 | Current sha256 |
|------|-----------------|----------------|
| plugins/context-engine/hooks/track-edits.sh | abc123... | xyz789... |

Re-read these files before editing. Run /belief-audit again to confirm.
Exit: 1 (drift found)
```

## Known Failure Modes

- **File deleted between snapshot and audit**: script reports the path as missing and exits 1. Re-read or remove the stale entry.
- **sha256sum unavailable**: script exits 0 with a warning — do not interpret silence as no drift; install coreutils.
- **belief.jsonl absent (first run)**: script exits 0 with "No snapshots recorded yet." — no entries to check.
- **Race on belief.jsonl**: two concurrent agents appending simultaneously may interleave lines. Best-effort append; worst case is a duplicate entry for the same path, which the audit deduplicates by taking the latest timestamp.
