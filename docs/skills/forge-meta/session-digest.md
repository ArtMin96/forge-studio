# Session Digest

`/session-digest` produces a compact Markdown rollup of the current session's evolution activity, organized by AHE's three pillars: Component, Experience, and Decision. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/session-digest
/session-digest --session-id abc123
```

Without an argument, the skill reads `CLAUDE_SESSION_ID` from the environment. Pass `--session-id` explicitly when running after a session has ended or when targeting a specific session from the current environment.

## Why you need it

A session that runs multiple agents, fires dozens of hooks, and writes several manifest entries produces a lot of state — but none of it is human-readable at a glance. The raw JSONL files are accurate but dense. `/session-digest` filters the change manifest down to the current session's entries, counts handoff events from `handoffs.jsonl`, aggregates predicted fixes, risk tasks, and assumptions, and writes it all into a single ≤10KB Markdown file at `.claude/sessions/<session-id>-digest.md`.

The 10KB cap is intentional: it keeps digests context-friendly for the next session to load. If content exceeds the limit, the file is truncated with a clear marker rather than silently cut off.

The skill also appends a Harness Metrics section. When `.claude/metrics/` has a prior-day file, it shows a per-dimension delta — for example, `verification_strength: 30% → 45% (+15pp)` — making improvement or regression immediately visible without running `/harness-metrics` manually.

## When to use it

- At the end of any session where agents have made meaningful changes and written manifest entries, to get a compact human-readable rollup.
- Mid-session to snapshot progress before a context compact or `/clear`.
- As a manual trigger when the `session-end-digest.sh` hook did not fire (for example, in a session that ended abruptly).

Do not use it for browsing entries across multiple sessions — use [`/evolution-history`](evolution-history.md) for a full cross-session timeline instead.

## Best practices

- **Run before `/clear` or context compact.** The digest captures the session's activity into a persistent file that the next session can load without re-reading the full manifest. It is the cleanest way to carry state forward across compaction.
- **Check the Decision section for remaining risks.** The Decision section aggregates `remaining_risks` from all manifest entries in the session. These are the honest residual concerns declared during the session — worth reading before signing off.
- **Use the Harness Metrics delta as a progress signal.** Dimensions that moved by 5+ percentage points are flagged with `(+)` or `(-)`. A flat or declining `verification_strength` after a heavy sprint is a signal to improve evidence-bundle coverage in the next round of changes.
- **Look at assumption counts.** The Decision section shows how many `assumptions` were declared in total. A high assumption count with low `verification_strength` is a risk pattern worth addressing before the next sprint.

## How it improves your workflow

`/session-digest` is the closing bracket on a session's work. It converts the session's accumulated state into a file you can carry into the next session, share with a reviewer, or reference when something breaks later. The three-section structure — Component (what fired), Experience (what happened), Decision (what changed and at what risk) — mirrors how AHE describes a session's arc, giving you a conceptually complete summary rather than a raw log dump.

## Related

- [`/change-manifest`](change-manifest.md) — the entries this skill reads and rolls up; the session's source of truth
- [`/evolution-history`](evolution-history.md) — full cross-session timeline; use when you need more than the current session's view
- [`/harness-metrics`](harness-metrics.md) — the scorecard appended to the digest; run directly for a standalone metrics view
- [`/manifest-analyze`](manifest-analyze.md) — aggregate analysis across the full ledger; use to quantify patterns beyond a single session
- [Architecture](../../architecture.md) — context management and memory in the 8-component harness model
