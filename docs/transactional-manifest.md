# Transactional Manifest Guide

Contributor reference for writing entries to `.claude/evolution/change_manifest.jsonl`. Audience: anyone implementing a hook or skill that produces manifest entries.

## Why these specific fields

The change manifest started as a "what changed and why" log — useful for history browsing but not for attribution or replay. The research survey arXiv:2605.18747 §5.2.4 argues for treating each agent action as a *transaction*: it should declare what state it read, what it assumed, what it changed, and how to verify the result held up. Without that declaration, a later agent diagnosing a regression has to guess which change introduced the problem and re-read the entire session context to reconstruct the evidence.

The transactional fields make the manifest *falsifiable*: `verifier_obligations` are shell commands you can re-run days later. `assumptions` are claims another agent can check. `evidence_bundle` is the record of what was actually checked before the entry was written. Together they enable the diagnose stage from the same paper's five-stage AHE cycle (observe → diagnose → propose → evaluate → promote) to work from artifacts rather than memory.

## What the schema captures

| Field | Where | Meaning |
|---|---|---|
| `id` | envelope | `chg-<epoch>-<hex>` — unique, sortable |
| `iso_timestamp` | envelope | UTC write time |
| `session_id` | envelope | Claude Code session that wrote the entry |
| `agent_type` | envelope | Which agent role wrote the entry |
| `type` | change context | Category label (e.g. `skill-edit`, `hook-edit`, `git-change`) |
| `description` | change context | One-sentence summary of the change |
| `files` | change context | Comma-separated paths affected (legacy field) |
| `failure_pattern` | change context | Pattern the change addresses |
| `predicted_fixes` | change context | What is expected to improve |
| `risk_tasks` | change context | Downstream tasks that may be affected |
| `constraint_level` | change context | `none`, `soft`, or `hard` |
| `why_this_component` | change context | Rationale for placing the change here |
| `read_set` | transactional | Paths the agent Read before editing — enables stale-read detection |
| `write_set` | transactional | Paths actually written — cross-check against `files` |
| `assumptions` | transactional | Falsifiable claims relied on during the edit |
| `verifier_obligations` | transactional | Shell commands that confirm the change is still correct |
| `rollback_handle` | transactional | Command or git ref that reverses this change cleanly |
| `evidence_bundle.checks_run` | evidence | Checks that passed at write time |
| `evidence_bundle.assumptions_preserved` | evidence | Subset of `assumptions` that were actively verified |
| `evidence_bundle.untested_regions` | evidence | Areas changed but not tested; `[]` = fully tested; absent = unknown |
| `evidence_bundle.remaining_risks` | evidence | Risks not ruled out — surfaced by `/session-digest` |

## Migration: legacy entries still readable

Entries written before the transactional fields existed parse fine alongside new ones. The writer omits any field whose source env var is empty — there are no `"field": null` placeholders. Any reader iterating entries with `obj.get("read_set", [])` gets an empty list for legacy entries and the real list for new ones. No migration step needed.

```python
# Safe reader pattern — works for both legacy and v2 entries
import json

with open(".claude/evolution/change_manifest.jsonl") as f:
    for line in f:
        entry = json.loads(line)
        read_set = entry.get("read_set", [])           # [] for legacy
        bundle   = entry.get("evidence_bundle", {})    # {} for legacy
        risks    = bundle.get("remaining_risks", [])   # [] for legacy
```

## How to declare read_set

`read_set` should list every file path the agent Read before making the edit. The rule is: if you called the `Read` tool on a path during the work that produced this manifest entry, that path belongs in `read_set`.

Set it via env var before calling the writer:

```bash
MANIFEST_READ_SET=$'plugins/forge-meta/skills/change-manifest/SKILL.md\nplugins/forge-meta/skills/change-manifest/scripts/append-manifest.sh' \
bash plugins/forge-meta/skills/change-manifest/scripts/manifest-writer.sh generator "why this change"
```

The value is newline-separated. The writer splits on newlines, strips blank lines, and stores the result as a JSON array.

**Why this matters**: if a bug is introduced and attribution is run later, the tooling can check whether the `read_set` at write time matches the file content at that timestamp. A mismatch means the agent edited based on stale context.

## How to write a falsifiable assumption

An assumption belongs in `assumptions` when another agent (or you, later) could check it with a command or a re-read. Vague intentions go in `description`, not `assumptions`.

| Do | Don't |
|---|---|
| `"count.sh returns the same number across concurrent calls"` | `"things should work fine"` |
| `"append-manifest.sh exits 0 on empty MANIFEST_READ_SET"` | `"the script handles edge cases"` |
| `"README.md hook count matches count.sh output at time of edit"` | `"counts are correct"` |

A falsifiable assumption names a specific artifact, command, or relationship. Someone reading it six sessions later should be able to write a one-liner to verify or refute it.

If you verified the assumption before writing, move it to `assumptions_preserved` in the evidence bundle. Both lists together tell the story: "here is what I relied on, and here is the subset I actually checked."

## Failure modes

**Empty evidence_bundle**: legal but treated as suspect by `/failure-attribute`. When attribution walks manifest entries re-running `verifier_obligations`, an entry with no bundle is the weakest candidate for "this was verified." If your entry has no bundle, it will be ranked lower in confidence — but not excluded.

**Mismatched read/write sets**: if `write_set` contains paths that are not in `read_set`, that signals the agent wrote a file it did not read first. The research-gate hook (PreToolUse) already blocks unread edits in most flows; a mismatch in the manifest is a scope-creep signal worth investigating during attribution.

**Missing verifier_obligations**: attribution cannot re-run a check that was never declared. Entries without `verifier_obligations` cannot be positively cleared by the attribution script — they remain as "could not verify" rather than "passed" or "failed."

**Stale rollback_handle**: `git revert HEAD` only works immediately after the commit. If you record a rollback handle, record the specific sha: `git revert abc1234`. That sha remains valid indefinitely.

## Quick reference: env vars accepted by manifest-writer.sh

```bash
MANIFEST_READ_SET            # newline-separated paths Read before the edit
MANIFEST_WRITE_SET           # newline-separated paths written
MANIFEST_ASSUMPTIONS         # newline-separated falsifiable claims
MANIFEST_VERIFIER_OBLIGATIONS  # newline-separated shell commands to re-run
MANIFEST_ROLLBACK_HANDLE     # single string: command or git ref
MANIFEST_CHECKS_RUN          # newline-separated checks that passed
MANIFEST_ASSUMPTIONS_PRESERVED  # newline-separated assumptions verified
MANIFEST_UNTESTED_REGIONS    # newline-separated untested areas
MANIFEST_REMAINING_RISKS     # newline-separated residual risks
```

All are optional. Legacy callers that set none of them produce the same entry shape as before.

## Related docs

- [`docs/self-evolution.md` § Evidence-Bundle Format](self-evolution.md#evidence-bundle-format) — worked example with a real edit
- [`docs/architecture.md` § Change-Manifest Entry Format](architecture.md#change-manifest-entry-format) — full schema reference with backward-compat note
- [`plugins/forge-meta/skills/change-manifest/SKILL.md`](../plugins/forge-meta/skills/change-manifest/SKILL.md) — user-facing skill reference
