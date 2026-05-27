# Memory Index

`/memory-index` is the hygiene skill for the persistent memory store. It lists every topic file in `.claude/memory/topics/`, annotates each one with its age and freshness status, flags entries that are stale or duplicated, verifies individual memories against the current state of the repo, and removes the ones that are no longer accurate. It belongs to the `memory` plugin, which provides Forge Studio's three-tier persistent memory system.

---

## Install

```bash
/plugin install memory@forge-studio
```

```text
/memory-index
```

No arguments required. Invoke it without arguments for a full listing; describe a specific topic to verify just that one entry.

## Why you need it

A memory store that is never audited is one that silently accumulates wrong answers. File paths move, function names change, constraints get lifted, preferences evolve — and the topic files that named them do not update themselves. Left unchecked, the store that was once a source of useful context becomes a source of confident misinformation.

`/memory-index` counteracts this by making the memory store inspectable on the same terms as any other project artifact. The age-based freshness tiers — fresh under 7 days, aging 7–30 days, stale over 30 days — translate the `Last verified:` date in each topic file into a visual signal you can act on without reading every file. The duplicate detection surfaces cases where the same knowledge was captured twice in different slugs, which tend to accumulate as the store grows. The verify-specific-memory action goes further: it reads a topic file and checks every factual claim against current HEAD, not just the date.

The 50-entry limit on the index is enforced here too. A store that has grown past 50 entries is a sign that ephemeral task notes have crept in, or that topics were added without checking for existing coverage first.

## When to use it

Reach for `/memory-index` when:

- You want a periodic sanity check on what the assistant has stored — monthly or before a major project phase.
- Several recalled facts have recently turned out to be stale or wrong, suggesting broader drift in the store.
- The user asks "what do you remember about X?" and you want to see the full list before diving into a specific topic.
- The index is approaching 50 entries and you want to prune before adding more.
- `/recall` or `/remember` produces a topic slug that might already exist under a different name.

Do not use it for retrieving a specific memory for the current turn — use [`/recall`](recall.md) instead. Do not use it for writing or updating a memory — use [`/remember`](remember.md) instead.

## Best practices

- **Run it before you rely on memory for a high-stakes decision.** If you are about to act on a recalled constraint — especially one that is more than 30 days old — a quick verify pass with `/memory-index` confirms whether the underlying state still matches.
- **Delete rather than accumulate.** When an entry is stale and the underlying fact has changed, remove it. A removed memory is recoverable from git history if needed; a wrong memory that stays in the index is actively harmful.
- **Suggest consolidation for overlapping topics.** When two topic files describe the same domain from slightly different angles, the skill surfaces them as candidates for merging. Merged topics are easier to recall accurately than split ones.
- **Treat the 50-entry ceiling as a signal.** Hitting 50 entries does not mean you have 50 important things to remember — it usually means some of them are too narrow or too ephemeral for the persistent store. Use the ceiling as a prompt to reconsider scope.
- **Verify before presenting.** When another tool or skill is about to act on something recalled from memory, a verify pass here first ensures you are presenting current knowledge, not a cached snapshot.

## How it improves your workflow

`/memory-index` is what keeps the memory plugin honest over time. Without it, the write/read pair of `/remember` and `/recall` would eventually produce a store that looks authoritative but reflects a state of the project that no longer exists. By making the full store visible at a glance — with freshness labels, duplicate detection, and the ability to verify individual claims against HEAD — it turns memory hygiene from an ad-hoc chore into a deliberate, structured practice. The result is a store you can actually trust when you retrieve from it.

## Related

- [`/remember`](remember.md) — writes new topics and updates existing ones; this skill audits what remember has produced
- [`/recall`](recall.md) — retrieves individual topics on demand; use `/memory-index` first when multiple topics may be stale
- [`/lineage-audit`](lineage-audit.md) — inspects the ledger that records memory updates; complementary to memory-index for deep trust audits
- [`/entropy-scan`](../diagnostics/entropy-scan.md) — harness-wide drift detection; `/memory-index` is the memory-specific equivalent
- [Architecture](../../architecture.md) — where memory fits in the 8-component harness model
