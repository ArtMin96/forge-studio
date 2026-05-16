---
name: change-manifest
description: Write a structured change-manifest entry to `.claude/evolution/change_manifest.jsonl`. Each entry captures what changed, why, and predicted impact — forming the evolution ledger that `forge-meta` reads for session digests and history views.
when_to_use: Reach for this when a generator or reviewer agent finishes a meaningful change and wants to declare predicted fixes, risk tasks, or constraint context for the evolution ledger. Typically called via `manifest-writer.sh` (SubagentStop hook) automatically; invoke directly only to record a change the hook could not auto-detect. Do NOT use for session-end summaries — use `/session-digest` instead.
argument-hint: --type <type> --description <desc> [--files <comma-list>] [--failure-pattern <p>] [--predicted-fixes <text>] [--risk-tasks <list>] [--constraint-level <none|soft|hard>] [--why-this-component <text>]
allowed-tools:
  - Bash
  - Read
scheduling: a generator or reviewer subagent has just finished work that modifies plugin files, hooks, or skills
structural:
  - Collect required fields (type, description) and any optional context fields
  - Run append-manifest.sh with all collected fields
  - Confirm exit 0 and that .claude/evolution/change_manifest.jsonl gained a line
logical: .claude/evolution/change_manifest.jsonl has a new well-formed JSON entry with id starting "chg-", an iso_timestamp, and at least type + description
---

# /change-manifest — Write an Evolution Ledger Entry

Records a single structured change event to `.claude/evolution/change_manifest.jsonl`. The file is append-only; one JSON object per line. The `manifest-writer.sh` SubagentStop hook writes entries automatically when it detects relevant signals. Use this skill for manual or scripted entries.

## Schema

Each entry follows AHE p.20 with an envelope:

| Field | Required | Source |
|---|---|---|
| `id` | auto | `chg-<unix-epoch>-<random6hex>` |
| `iso_timestamp` | auto | `date -u` at write time |
| `session_id` | auto | `$CLAUDE_SESSION_ID` env, else `unknown` |
| `agent_type` | auto | `$CLAUDE_AGENT_TYPE` env, else `unknown` |
| `type` | required | caller-supplied |
| `description` | required | caller-supplied |
| `files` | optional | comma-separated path list |
| `failure_pattern` | optional | pattern the change addresses |
| `predicted_fixes` | optional | what this change is expected to resolve |
| `risk_tasks` | optional | downstream tasks that may be affected |
| `constraint_level` | optional | `none`, `soft`, or `hard` |
| `why_this_component` | optional | rationale for placing the change here |

## Usage

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

## Examples

### Example 1: generator declares a change proactively

Input: agent emits on stdout: `change_manifest: {"type":"skill-add","description":"added /auto-tune-skill","predicted_fixes":"auto-tuning now available"}`

Output in `.claude/evolution/change_manifest.jsonl`:
```json
{"id":"chg-1715600000-a3f8c1","iso_timestamp":"2026-05-13T09:00:00Z","session_id":"abc123","agent_type":"agents:generator","type":"skill-add","description":"added /auto-tune-skill","predicted_fixes":"auto-tuning now available"}
```

### Example 2: direct invocation with full fields

Input: `append-manifest.sh --type hook-edit --description "add doom-loop hook" --files "plugins/diagnostics/hooks/doom-loop.sh" --constraint-level hard --why-this-component "diagnostics owns loop detection"`

Output: one JSON line appended with all supplied fields plus auto envelope.

## Known Failure Modes

- **`jq` absent**: `manifest-writer.sh` parses the `change_manifest:` marker with `python3 -c` to avoid `jq` dependency. If Python 3 is absent the hook silently skips the entry (exit 0 — observability, not a gate).
- **Non-UTF-8 descriptions**: `python3 json.dumps` handles escaping; passing raw shell variables into `jq --arg` can fail with special chars. Always pass through the Python writer.
