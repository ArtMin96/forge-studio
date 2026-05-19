---
name: evolution-history
description: Use when you want to review the project's evolution ledger — renders the append-only change manifest as a reverse-chronological Markdown timeline grouped by date (newest first), capped at the last 200 entries.
when_to_use: "Reach for this after a sprint or series of generator/reviewer passes when you want a human-readable audit trail of what changed, what agents touched which files, and what failure patterns were recorded. Do NOT use for live session output — use /session-digest instead."
allowed-tools:
  - Bash
  - Read
---

Renders `.claude/evolution/change_manifest.jsonl` as a dated Markdown timeline.

## Usage

```
/evolution-history
```

Then run:

```
bash scripts/render.sh
```

The script writes the timeline to stdout. Pipe or redirect as needed.

## What the output looks like

```
# Evolution History

_<N> manifest entries, last 200 shown._

## 2026-05-13

### 2026-05-13T11:00:00Z — skill-edit: added evolution-history
- **id**: <uuid>
- **agent**: generator (session: <session-id>)
- **files**: plugins/forge-meta/skills/evolution-history/SKILL.md
```

Groups are sorted newest-date first. Within a date, entries are sorted newest-timestamp first. Fields `files`, `failure_pattern`, `predicted_fixes`, `risk_tasks`, `constraint_level`, and `why_this_component` are omitted from the output when they are absent or empty in the manifest entry.

## Examples

Input: `.claude/evolution/change_manifest.jsonl` does not exist (fresh project, no generator/reviewer pass yet).

Output:
```
# Evolution History

_No manifest yet._
```

Input: manifest has 2 entries — one on 2026-05-18 (skill-edit by generator), one on 2026-05-19 (hook-edit by reviewer).

Output:
```
# Evolution History

_2 manifest entries._

## 2026-05-19

### 2026-05-19T08:22:03Z — hook-edit: doom-loop moved PreToolUse
- **id**: 4a1c-…
- **agent**: reviewer (session: s-9f2)
- **files**: plugins/diagnostics/hooks/doom-loop.sh

## 2026-05-18

### 2026-05-18T14:11:09Z — skill-edit: added Input/Output pairs
- **id**: 7bd2-…
- **agent**: generator (session: s-9f1)
- **files**: plugins/traces/skills/trace-evolve/SKILL.md
```

## Execution Checklist

- [ ] Run `bash scripts/render.sh`
- [ ] Review the timeline, noting failure patterns and predicted fixes
- [ ] Cross-reference with `/session-digest` for session-scoped rollups

## Known Failure Modes

- **Missing manifest** — if `.claude/evolution/change_manifest.jsonl` does not exist yet (no generator/reviewer pass has completed), the script prints a placeholder message and exits 0. This is expected on a fresh project.
- **Malformed lines** — silently skipped; the rest of the entries render normally.
