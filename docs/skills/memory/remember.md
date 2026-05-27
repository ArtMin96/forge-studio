# Remember

`/remember` is how you teach the assistant things that need to outlast the current session. You give it a fact, a decision, a preference, or a constraint; it writes a topic file in `.claude/memory/topics/`, registers a one-line pointer in `.claude/memory/index.md`, and — when updating an existing topic — snapshots the prior version to the lineage ledger so every change is reversible. It belongs to the `memory` plugin, which provides Forge Studio's three-tier persistent memory system.

---

## Install

```bash
/plugin install memory@forge-studio
```

```text
/remember we never enable SAML on staging — auth team owns that toggle
```

No argument-hint is defined; you invoke the skill in natural language and it derives the topic slug and content from what you tell it.

## Why you need it

Claude Code's context window resets between sessions. Without a persistent store, every constraint you've negotiated, every architectural decision you've made, and every "always do it this way" rule lives only in the conversation that produced it. The next session starts blind.

`/remember` solves this by externalising knowledge into files your project already tracks. The three-tier layout it maintains — a tiny index always loaded, topic files loaded on demand, raw transcripts searchable by grep — means the overhead of a large memory store stays proportional to what a given task actually needs. You pay only for what you retrieve.

Updates are versioned. When you refine a stored fact, `/remember` takes a snapshot of the old version before overwriting, then records the change in the lineage ledger. That means you can roll back a memory the same way you roll back any other harness resource — the history is on disk, not just in your head.

## When to use it

Reach for `/remember` when:

- The user says "remember that…" or "always do it this way" — explicit capture requests.
- A hard-won insight emerges from a debugging session: the kind of thing that took three attempts to discover and would take three attempts again without a record.
- A constraint is too subtle or project-specific to live only in `CLAUDE.md` — compliance requirements, team ownership boundaries, environment restrictions.
- An architectural decision has been made and the rationale should survive compaction.
- You discover a user preference that should shape every future session (formatting style, tool choices, naming conventions).

Do not use it for retrieving a stored memory — use [`/recall`](recall.md) instead. Do not use it for ephemeral session notes (current task progress, scratch notes) — those belong in `/progress-log` or task files, not in the persistent memory store.

## Best practices

- **Check for an existing topic first.** Before creating a new file, scan `.claude/memory/index.md` for a related entry. Updating an existing topic keeps memory coherent; adding a duplicate creates a split that `/recall` will have to reconcile later.
- **Include the why, not just the what.** A topic file that says "never enable SAML on staging" is useful; one that adds "auth team owns that toggle and we'd break their test fixtures" is actionable. Future sessions can reason about exceptions; bare rules cannot.
- **Keep topics under 50 lines.** The limit is there because memory is hints, not documentation. If the content is growing past 50 lines, the topic is trying to be two things — split it into subtopics.
- **Don't store what is derivable from code or git.** If something is immediately visible from reading the file or running `git log`, it does not need to live in memory. Store the things that are invisible without context: the decision behind the code, not the code itself.
- **Pair it with `/recall` at session start.** Writing a memory is only useful if future sessions load it. When you start work that continues prior context, open with `/recall` to surface what was stored.

## How it improves your workflow

`/remember` turns the memory plugin into an active partner rather than a passive scratchpad. By enforcing a versioned, indexed structure — and by wiring updates to the lineage ledger — it makes the memory store auditable the same way the rest of the harness is auditable. You can inspect what was stored, when it changed, and what the previous version said. The result is that hard-won project knowledge compounds across sessions instead of evaporating at context reset, and constraints you have negotiated once do not have to be re-negotiated every time.

## Related

- [`/recall`](recall.md) — the read side of the write/read pair; retrieves stored topics into the current turn
- [`/memory-index`](memory-index.md) — periodic hygiene audit; lists all topics, flags stale entries, cleans up duplicates
- [`/lineage-audit`](lineage-audit.md) — inspects the ledger that `/remember` writes to on every topic update
- [`/progress-log`](../long-session/progress-log.md) — for ephemeral session notes that should not persist beyond the task
- [Architecture](../../architecture.md) — where memory fits in the 8-component harness model
