---
name: session-digest
description: Produce a ≤10KB Markdown digest of the current session's evolution artifacts. Writes to `.claude/sessions/<session-id>-digest.md`. Useful after any multi-agent run to get a compact rollup without reading raw JSONL files.
when_to_use: Reach for this when you want a human-readable summary of what changed, what was attempted, and what the manifest recorded during a session. Also fires automatically on SessionEnd via the `session-end-digest.sh` hook. Do NOT use for full manifest browsing across sessions — use `/evolution-history` instead.
argument-hint: [--session-id <id>]
allowed-tools:
  - Bash
  - Read
  - Write
scheduling: a session is ending, or the user wants a rollup of the current session's activity
structural:
  - Determine the session ID (arg, env CLAUDE_SESSION_ID, or "unknown")
  - Read .claude/evolution/change_manifest.jsonl, filter entries by session_id
  - Read .claude/handoffs.jsonl if present, count handoff_open/handoff_resolved/handoff_skipped events
  - Render three sections — Component, Experience, Decision — into a Markdown file
  - Cap output at 10KB; append truncation marker if exceeded
  - Write result to .claude/sessions/<session-id>-digest.md
logical: .claude/sessions/<session-id>-digest.md exists, is ≤10KB, and contains ## Component, ## Experience, ## Decision sections
---

# /session-digest — Per-Session AHE Rollup

Generates a single Markdown file summarizing the current session's evolution activity, organized by AHE's three pillars (AHE p.4 fig 2). The hook runs this automatically on SessionEnd; you can also call it at any point mid-session to snapshot progress.

## Output location

`.claude/sessions/<session-id>-digest.md`

The file is overwritten on each invocation (idempotent). Parent directory is created if absent.

## Sections

| Section | Content |
|---|---|
| **Component** | Which plugins fired — derived from `type` values in `change_manifest.jsonl` and handoff counts from `handoffs.jsonl` |
| **Experience** | Per-task outcomes — each manifest entry for the session: type, description, files touched |
| **Decision** | Change-manifest deltas — total entry count, aggregated `predicted_fixes`, `risk_tasks`, total `assumptions` count, and any non-empty `remaining_risks` |

## Usage

```bash
# On demand with an explicit session ID
bash plugins/forge-meta/skills/session-digest/scripts/digest.sh --session-id abc123

# On demand using CLAUDE_SESSION_ID env
CLAUDE_SESSION_ID=abc123 bash plugins/forge-meta/skills/session-digest/scripts/digest.sh
```

## Examples

### Example 1: two manifest entries recorded during session "s1"

Input: two entries in `.claude/evolution/change_manifest.jsonl` with `session_id: "s1"`

Output: `.claude/sessions/s1-digest.md` with Component showing two hook-edit entries, Experience listing each with description and files, Decision showing count=2 and any predicted_fixes text.

### Example 2: no entries for the requested session

Input: manifest exists but contains no entries for the requested session ID

Output: `.claude/sessions/<id>-digest.md` with all three sections present, each showing `_no entries for this session_`.

### Example 3: session with assumptions and remaining risks

Input: two entries in `.claude/evolution/change_manifest.jsonl` with `session_id: "s2"`, both having `assumptions` lists and one having `evidence_bundle.remaining_risks`.

Output: `.claude/sessions/s2-digest.md` — Decision section shows `**Total assumptions declared: 3**` and a list under `**Remaining risks**` with the verbatim risk text from the entry that declared it.

## Truncation

If accumulated content exceeds 10240 bytes, the file is capped and ends with:

```
... (truncated to 10KB) ...
```

This preserves the file header and as many entries as fit. The 10KB bound keeps digests context-friendly when loaded into future sessions.

## Harness Metrics Delta

At the end of the digest, surface the harness scorecard for this session. Check `.claude/metrics/` for JSON files:

- If two or more date-stamped files exist, compare today's values against the most recent prior file and show a delta row for each dimension (e.g., `verification_strength: 30% → 45% (+15pp)`).
- If only one file exists, show the current values without a delta.
- If no `.claude/metrics/` files exist, run `bash plugins/forge-meta/skills/harness-metrics/scripts/score.sh` to generate the current scorecard and include it inline.

```bash
# List available metric snapshots
ls .claude/metrics/*.json 2>/dev/null | sort
```

The delta section appears after the Decision section as `## Harness Metrics`. Dimensions that moved by ≥5 percentage points are flagged with `(+)` or `(-)` for quick scanning.

## Known Failure Modes

- **Missing manifest**: if `.claude/evolution/change_manifest.jsonl` does not exist, the digest is written with empty sections rather than failing. The hook must not block session teardown.
- **Python 3 absent**: the script uses `python3` for JSON parsing. If absent, the digest will contain a single-line error note and exit 0 — never blocks.
