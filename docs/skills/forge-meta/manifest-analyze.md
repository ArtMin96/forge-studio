# Manifest Analyze

`/manifest-analyze` produces a structured five-section report over the full change manifest — failure-pattern frequencies, risk-task distribution, constraint-level split, and component pressure clusters. It belongs to the `forge-meta` plugin, which manages Forge Studio's self-evolution boundary.

---

## Install

```bash
/plugin install forge-meta@forge-studio
```

```text
/manifest-analyze
/manifest-analyze --include-archive
```

Pass `--include-archive` to fold in rotated archive files from `.claude/evolution/archive/` alongside the live manifest. Without the flag, only the current `.claude/evolution/change_manifest.jsonl` is read.

## Why you need it

The evolution ledger accumulates entries from every sprint, but individual entries are hard to reason about in aggregate. What failure patterns keep recurring? Which components attract the most evolution pressure? Are hard constraints being hit more often than soft ones? `/manifest-analyze` answers those questions by grouping and ranking across the full manifest rather than showing entries one by one.

The report is deterministic: for a given manifest file, output is identical across invocations, and ties are broken alphabetically so rankings never shift between runs. This makes it safe to track in a document or diff between sprints.

## When to use it

- After a sprint or extended tuning run, to understand which failure patterns dominated and which risk tasks recurred most.
- When you want to know which components have accumulated the most evolution pressure — the `why_this_component` clusters reveal where the harness is structurally fragile.
- When you need a quantitative summary to bring into a planning session, deciding which skills or hooks to prioritize next.

Do not use it for browsing individual entries chronologically — use [`/evolution-history`](evolution-history.md) instead. The two skills are siblings: `/evolution-history` shows the timeline entry by entry; `/manifest-analyze` aggregates across all entries into frequency tables.

## Best practices

- **Browse the timeline first, then analyze.** [`/evolution-history`](evolution-history.md) gives context for individual entries before you collapse them into frequency counts. Understanding what a failure pattern string actually refers to in practice makes the analysis more actionable.
- **Run with `--include-archive` for long-running projects.** If the live manifest has been rotated, the top failure patterns may be split between the live file and archived ones. The combined view gives a more accurate picture of what the harness has been fighting.
- **Treat `why_this_component` clusters as architectural signals.** A component that appears in ten entries under the same rationale is telling you the design has a recurring pressure point. That is a better signal than line coverage for deciding where to spend structural effort.
- **Use the failure-pattern frequency table to feed `/auto-tune-skill`.** If `premature-edit` or `stale-import` appears in the top three patterns repeatedly, the skill whose evals exercise those behaviors is the highest-leverage tuning target.

## How it improves your workflow

`/manifest-analyze` converts the evolution ledger from a log into intelligence. A sprint that produces 40 manifest entries is hard to reason about entry by entry; the five-section report turns those 40 entries into ranked lists that point directly at what to fix next. Paired with [`/evolution-history`](evolution-history.md) for browsing and [`/session-digest`](session-digest.md) for per-session rollups, it completes the read path over the ledger that [`/change-manifest`](change-manifest.md) writes.

## Related

- [`/change-manifest`](change-manifest.md) — writes the entries this skill analyzes; the ledger's source of truth
- [`/evolution-history`](evolution-history.md) — chronological browser for individual entries; use to browse, then switch here to quantify
- [`/session-digest`](session-digest.md) — per-session rollup; complements the cross-session view this skill produces
- [Architecture](../../architecture.md) — execution traces and memory in the 8-component harness model
