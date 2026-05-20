---
name: change-manifest
description: Write a structured change-manifest entry to `.claude/evolution/change_manifest.jsonl`. Each entry captures what changed, why, predicted impact, what was read, what assumptions were made, and how to verify the work — forming the evolution ledger that `forge-meta` reads for session digests and history views.
when_to_use: Reach for this when a generator or reviewer agent finishes a meaningful change and wants to declare predicted fixes, risk tasks, read/write sets, assumptions, or evidence for the evolution ledger. Typically called via `manifest-writer.sh` (SubagentStop hook) automatically; invoke directly only to record a change the hook could not auto-detect. Do NOT use for session-end summaries — use `/session-digest` instead.
argument-hint: --type <type> --description <desc> [--files <comma-list>] [--failure-pattern <p>] [--predicted-fixes <text>] [--risk-tasks <list>] [--constraint-level <none|soft|hard>] [--why-this-component <text>]
allowed-tools:
  - Bash
  - Read
scheduling: a generator or reviewer subagent has just finished work that modifies plugin files, hooks, or skills
structural:
  - Collect required fields (type, description) and any optional context fields
  - Declare read_set (paths Read before the edit) and write_set (paths edited)
  - Quote the verifier_obligations command that checks the work held up
  - Run manifest-writer.sh with all collected fields
  - Confirm exit 0 and that .claude/evolution/change_manifest.jsonl gained a line
logical: .claude/evolution/change_manifest.jsonl has a new well-formed JSON entry with id starting "chg-", an iso_timestamp, and at least type + description
---

# /change-manifest — Write an Evolution Ledger Entry

Records a single structured change event to `.claude/evolution/change_manifest.jsonl`. The file is append-only; one JSON object per line. The `manifest-writer.sh` SubagentStop hook writes entries automatically when it detects relevant signals. Use this skill for manual or scripted entries.

## Schema

Each entry follows an evidence-bundle pattern: envelope fields, change context, transactional state, and verifiability (from arXiv:2605.18747 §5.2.4).

### Envelope (always auto-populated)

| Field | Source |
|---|---|
| `id` | `chg-<unix-epoch>-<random6hex>` |
| `iso_timestamp` | `date -u` at write time |
| `session_id` | `--session-id` flag → `$CLAUDE_SESSION_ID` env → `"unknown"` |
| `agent_type` | `$CLAUDE_AGENT_TYPE` env → `"unknown"` |

### Change context (legacy fields, still required)

| Field | Required | Source |
|---|---|---|
| `type` | required | caller-supplied |
| `description` | required | caller-supplied |
| `files` | optional | comma-separated path list |
| `failure_pattern` | optional | pattern the change addresses |
| `predicted_fixes` | optional | what this change is expected to resolve |
| `risk_tasks` | optional | downstream tasks that may be affected |
| `constraint_level` | optional | `none`, `soft`, or `hard` |
| `why_this_component` | optional | rationale for placing the change here |

### Transactional state (new optional fields — strongly recommended for non-trivial changes)

| Field | Env var | Meaning |
|---|---|---|
| `read_set` | `MANIFEST_READ_SET` | Newline-separated paths the agent Read before editing. Allows downstream attribution to flag stale-read bugs. |
| `write_set` | `MANIFEST_WRITE_SET` | Newline-separated paths the agent wrote. Cross-check against `files`. |
| `assumptions` | `MANIFEST_ASSUMPTIONS` | Newline-separated falsifiable statements the agent relied on. State the claim precisely so it can be checked. |
| `verifier_obligations` | `MANIFEST_VERIFIER_OBLIGATIONS` | Newline-separated shell commands that must exit 0 to confirm the change held up. These are the commands `/failure-attribute` re-runs during attribution. |
| `rollback_handle` | `MANIFEST_ROLLBACK_HANDLE` | Single string — the command or `git revert <sha>` reference that reverses this change cleanly. |

### Evidence bundle (optional sub-object, strongest signal for attribution)

| Field | Env var | Meaning |
|---|---|---|
| `evidence_bundle.checks_run` | `MANIFEST_CHECKS_RUN` | Newline-separated checks that passed at write time (e.g. `json-parse`, `hook-exit-code`). |
| `evidence_bundle.assumptions_preserved` | `MANIFEST_ASSUMPTIONS_PRESERVED` | Newline-separated assumptions that were verified before writing. |
| `evidence_bundle.untested_regions` | `MANIFEST_UNTESTED_REGIONS` | Newline-separated areas of code that were changed but not tested. Explicit `[]` means fully tested. Absent means unknown — treated as suspect by `/failure-attribute`. |
| `evidence_bundle.remaining_risks` | `MANIFEST_REMAINING_RISKS` | Newline-separated risks the agent could not rule out. Surfaced by `/session-digest` and `/evolution-history`. |

**What makes an evidence bundle useful**: at minimum set `checks_run` (shows something was verified) and either `untested_regions` (explicit scope) or `remaining_risks` (honest residual concern). An empty bundle is legal but signals no verification occurred.

**Omit-empty contract**: the writer omits any field whose env var is empty. You will not see `"read_set": ""` in entries.

## Usage

### Via env vars (recommended — passes special chars safely)

```bash
MANIFEST_READ_SET=$'README.md\nCLAUDE.md' \
MANIFEST_WRITE_SET='README.md' \
MANIFEST_ASSUMPTIONS='count.sh returns stable values' \
MANIFEST_VERIFIER_OBLIGATIONS='bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh .' \
MANIFEST_CHECKS_RUN='json-parse' \
MANIFEST_UNTESTED_REGIONS='post-compact behavior' \
MANIFEST_REMAINING_RISKS='downstream skills unaware of new fields' \
MANIFEST_ROLLBACK_HANDLE='git revert HEAD' \
bash plugins/forge-meta/skills/change-manifest/scripts/manifest-writer.sh my-agent "why this change matters"
```

### Via append-manifest.sh (legacy — no new fields)

```bash
bash plugins/forge-meta/skills/change-manifest/scripts/append-manifest.sh \
  --type hook-edit \
  --description "wired SubagentStop for manifest capture" \
  --files "plugins/forge-meta/hooks/manifest-writer.sh,plugins/forge-meta/hooks/hooks.json" \
  --predicted-fixes "evolution ledger now auto-populated after generator passes" \
  --constraint-level soft
```

## Automatic Collection

`manifest-writer.sh` (SubagentStop hook) auto-populates entries when:
- An agent emits a `change_manifest: {...}` marker line on stdout, OR
- Git shows uncommitted files modified in the last 30 minutes.

To declare fields proactively from inside an agent, emit a line on stdout:
```
change_manifest: {"type":"hook-edit","description":"...","predicted_fixes":"..."}
```

For the full transactional fields, write a staging file before the hook fires:
```
.claude/state/manifest-staging-<session-id>.json
```
The hook reads this file and merges its fields into the entry, then deletes the file.

## Examples

### Example 1 — minimal legacy entry (no new fields)

Input: agent emits on stdout:
```
change_manifest: {"type":"skill-add","description":"added /auto-tune-skill","predicted_fixes":"auto-tuning now available"}
```

Output: appended to `.claude/evolution/change_manifest.jsonl`:
```json
{"id":"chg-1715600000-a3f8c1","iso_timestamp":"2026-05-13T09:00:00Z","session_id":"abc123","agent_type":"agents:generator","type":"skill-add","description":"added /auto-tune-skill","predicted_fixes":"auto-tuning now available"}
```

Legacy tools that write this shape keep working. Readers tolerate missing fields.

### Example 2 — full v2 entry with transactional state

Input: generator sets env vars and calls `manifest-writer.sh`:
```bash
MANIFEST_READ_SET=$'plugins/forge-meta/skills/change-manifest/SKILL.md\nplugins/forge-meta/skills/change-manifest/scripts/append-manifest.sh' \
MANIFEST_WRITE_SET='plugins/forge-meta/skills/change-manifest/SKILL.md' \
MANIFEST_ASSUMPTIONS='append-manifest.sh omit-empty logic works for all new fields' \
MANIFEST_VERIFIER_OBLIGATIONS='python3 -c "import json; [json.loads(l) for l in open(\".claude/evolution/change_manifest.jsonl\")]"' \
MANIFEST_CHECKS_RUN=$'json-parse\nhook-exit-code' \
MANIFEST_UNTESTED_REGIONS='post-compact behavior' \
MANIFEST_REMAINING_RISKS='downstream skills unaware of new fields' \
MANIFEST_ROLLBACK_HANDLE='git revert HEAD' \
bash plugins/forge-meta/skills/change-manifest/scripts/manifest-writer.sh generator "extend change-manifest schema with transactional fields"
```

Output: appended to `.claude/evolution/change_manifest.jsonl`:
```json
{
  "id": "chg-1747987200-b3e9f1",
  "iso_timestamp": "2026-05-20T10:00:00Z",
  "session_id": "s-xyz",
  "agent_type": "generator",
  "type": "skill-edit",
  "description": "extend change-manifest schema with transactional fields",
  "read_set": ["plugins/forge-meta/skills/change-manifest/SKILL.md", "plugins/forge-meta/skills/change-manifest/scripts/append-manifest.sh"],
  "write_set": ["plugins/forge-meta/skills/change-manifest/SKILL.md"],
  "assumptions": ["append-manifest.sh omit-empty logic works for all new fields"],
  "verifier_obligations": ["python3 -c \"import json; [json.loads(l) for l in open(\\\".claude/evolution/change_manifest.jsonl\\\")]\""],
  "evidence_bundle": {
    "checks_run": ["json-parse", "hook-exit-code"],
    "untested_regions": ["post-compact behavior"],
    "remaining_risks": ["downstream skills unaware of new fields"]
  },
  "rollback_handle": "git revert HEAD"
}
```

(The actual output is a single JSONL line, not pretty-printed.)

## Execution Checklist

- [ ] Declare `read_set` (paths Read before the edit) via `MANIFEST_READ_SET`
- [ ] Declare `write_set` (paths edited) via `MANIFEST_WRITE_SET`
- [ ] Quote `verifier_obligations` — the shell command that checks the work held up — via `MANIFEST_VERIFIER_OBLIGATIONS`
- [ ] Emit `evidence_bundle` with at least `checks_run` and one of: explicit `untested_regions` or `remaining_risks`
- [ ] Confirm exit 0 and that `.claude/evolution/change_manifest.jsonl` gained a line
- [ ] Validate the new line: `python3 -c "import json; [json.loads(l) for l in open('.claude/evolution/change_manifest.jsonl')]"`

## Known Failure Modes

- **`jq` absent**: `manifest-writer.sh` parses the `change_manifest:` marker with `python3 -c` to avoid `jq` dependency. If Python 3 is absent the hook silently skips the entry (exit 0 — observability, not a gate).
- **Non-UTF-8 descriptions**: `python3 json.dumps` handles escaping; passing raw shell variables into `jq --arg` can fail with special chars. Always pass through the Python writer.
- **Empty evidence_bundle**: legal but signals no verification occurred. `/failure-attribute` treats entries with no `evidence_bundle` as suspect when attributing regressions.
- **Mismatched read/write sets**: if `write_set` contains files not in `read_set`, that signals the agent wrote without reading first — a scope-creep pattern worth investigating.
