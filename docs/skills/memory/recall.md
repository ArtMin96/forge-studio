# Recall

`/recall` retrieves what the memory plugin knows about a topic and brings it into the current turn. You mention a subject — a prior decision, a constraint, something you worked through before — and the skill reads `.claude/memory/index.md`, identifies the matching topic file, loads it with a staleness label, and optionally searches raw session transcripts if the index and topic file do not cover the question. It belongs to the `memory` plugin, which provides Forge Studio's three-tier persistent memory system.

---

## Install

```bash
/plugin install memory@forge-studio
```

```text
/recall staging deployment rules
```

No argument-hint is defined; you invoke the skill by describing the topic you want to retrieve.

## Why you need it

Writing a memory with `/remember` is only half the equation. At the start of a new session — or when a decision is about to be made — the stored knowledge has to find its way back into the conversation. Without `/recall`, the index sits inert on disk while the assistant works from a blank slate.

`/recall` handles retrieval in a deliberate, tier-aware way rather than loading everything at once. The index (Tier 1) is always small and fast; topic files (Tier 2) are loaded only when matched; raw transcripts (Tier 3) are grepped for specific terms only as a last resort. That tiered approach keeps retrieval cheap: a large memory store does not penalise every turn.

The retrieval-ranking and staleness protocol is the other reason to use `/recall` rather than just reading the topic file directly. Every topic file carries a `Last verified:` date and an optional `Confidence:` field (`high | medium | low`; omitted ⇒ `medium`). When multiple topics match, `/recall` orders them by a composite trust weight (`relevance × staleness_weight × confidence_weight`) and prefers the higher-trust entry when two topics conflict — surfacing the lower as superseded-but-recorded. Each retrieved entry also carries a human-facing staleness label — current knowledge, "may be outdated", or "verify before acting" — so you always know how much weight to place on a recalled fact before making a decision.

## When to use it

Reach for `/recall` when:

- You are starting a session that continues prior work, and you want to surface relevant decisions and constraints before touching anything.
- A user phrase matches a topic you know or suspect has been stored — "what did we decide about X", "are there constraints on Y".
- You are about to make an architectural or configuration decision and want to ground it in past context rather than guessing.
- `/remember` was used in a previous session and the resulting topic might be relevant to the current task.

Do not use it for writing or updating a memory — use [`/remember`](remember.md) instead. Do not use it for reviewing or cleaning up the full memory store — use [`/memory-index`](memory-index.md) for that.

## Best practices

- **Verify before acting on recalled facts.** The staleness protocol tells you how old a memory is; it does not tell you whether the underlying state changed. If a topic names a file path, check the file exists. If it names a function or flag, grep for it. "The memory says X exists" is not the same as "X exists now."
- **Use it at session start, not mid-task.** Retrieving context before you begin is cheap and prevents contradictions. Retrieving it after you have already made decisions means reconciling remembered constraints with work already done.
- **Match the right tier.** If the index entry is enough (a one-liner pointer), you may not need to load the full topic file. If the topic file is enough, do not fall through to transcript search — Tier 3 is for edge cases only.
- **Watch the staleness labels.** A topic file older than 30 days carries a "verify before acting" label for a reason. Do not silently promote stale memory to current knowledge just because it is convenient.
- **Follow up with `/memory-index` when many topics feel outdated.** If multiple recalled facts turn out to be stale, a hygiene pass with `/memory-index` will clean them up in bulk rather than one by one.

## How it improves your workflow

`/recall` closes the loop that `/remember` opens. Together they make the memory plugin a genuine continuity mechanism: decisions persist, constraints carry forward, and the assistant that resumes your work next session starts from context rather than from zero. The tiered retrieval design means this continuity scales — you can accumulate a large memory store without paying for it on every turn, because `/recall` loads only what the current question actually needs. The staleness labels mean you always know when to trust and when to verify, which keeps recalled knowledge from hardening into unquestioned assumption.

## Related

- [`/remember`](remember.md) — the write side of the write/read pair; stores new topics and updates existing ones
- [`/memory-index`](memory-index.md) — audits and cleans up the full store; use when multiple memories feel stale
- [`/session-resume`](../long-session/session-resume.md) — loads the full prior-session briefing; pairs with `/recall` at session start for complete context recovery
- [Architecture](../../architecture.md) — where memory fits in the 8-component harness model
