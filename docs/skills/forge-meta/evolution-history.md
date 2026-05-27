# Evolution History

`/evolution-history` renders the project's change manifest as a reverse-chronological Markdown timeline grouped by date, capped at the last 200 entries. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/evolution-history
```

No arguments. The skill reads `.claude/evolution/change_manifest.jsonl` and writes the rendered timeline to stdout.

## Why you need it

The evolution ledger grows entry by entry across sessions and sprints. Reading raw JSONL to understand what changed and when is tedious and easy to misread. `/evolution-history` solves that by turning the append-only file into a dated, human-readable audit trail: each entry shows its agent, session ID, the files it touched, and — when present — the failure pattern it addressed, untested regions it left open, and remaining risks it declared.

The timeline respects both legacy entries (no transactional fields) and newer entries with full evidence bundles. Missing fields are silently omitted rather than shown as dashes, so old entries render cleanly alongside new ones.

## When to use it

- After a sprint or series of generator and reviewer passes, when you want to review what agents changed, which files they touched, and what failure patterns they recorded.
- When you need a human-readable audit trail to bring into a retrospective, share with a reviewer, or use as context for the next session.
- When you want to verify that a specific change landed in the ledger at the expected time.

Do not use it for live session output or single-session rollups — use [`/session-digest`](session-digest.md) instead.

## Best practices

- **Browse before you analyze.** `/evolution-history` is the chronological view; it lets you spot patterns visually. Once you know which failure patterns recur most, switch to [`/manifest-analyze`](manifest-analyze.md) for aggregate frequency tables.
- **Cross-reference with session digests.** If a timeline entry looks surprising, the session ID on each entry links it to the digest at `.claude/sessions/<session-id>-digest.md`, which has richer context about that session's assumptions and risk tasks.
- **Watch for untested regions.** Entries that declare `untested_regions` are honest about their coverage gaps. These are the areas most worth checking when something breaks later.
- **Remember the 200-entry cap.** On a long-running project the ledger may exceed 200 entries; the oldest entries are not shown. To analyze the full history including rotated archives, use [`/manifest-analyze`](manifest-analyze.md) with `--include-archive`.

## How it improves your workflow

`/evolution-history` turns the evolution ledger from a machine-readable JSONL file into a navigable record of what happened and why. When a regression surfaces, the timeline tells you which agent touched the affected files, what failure pattern they were addressing, and what risks they declared as unresolved. That context makes attribution faster and post-sprint retrospectives more grounded than "what does git log show?"

## Related

- [`/change-manifest`](change-manifest.md) — writes the entries this skill renders; the ledger's source of truth
- [`/session-digest`](session-digest.md) — per-session rollup; use for a single session's view
- [`/manifest-analyze`](manifest-analyze.md) — frequency analysis across the full ledger; use after browsing the timeline to understand patterns quantitatively
- [Architecture](../../architecture.md) — execution traces and memory in the 8-component harness model
