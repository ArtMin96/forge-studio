# Checkpoint

`/checkpoint` is a fast mid-session drift check. It compares recent work against the original task statement and produces a compact report — under 150 words — that names any scope creep, lists files changed but not planned, and ends with a single actionable recommendation: keep going, refocus, compact, or start fresh. It belongs to the `context-engine` plugin, which provides context measurement, pressure management, and belief-state safety for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install context-engine@forge-studio
```

```text
/checkpoint
```

No arguments. The skill locates the active plan via the plan-finder script, gathers `git diff --stat` and recent log output, and compares the two. If no plan exists it asks you to state the current task.

## Why you need it

Long sessions drift. A debugging detour that starts as "just one quick check" becomes a thirty-turn investigation. A refactor touches three files that were never part of the plan. Context fills with work that is proportionate to the detour, not to the original goal. By the time the drift is noticeable it has already cost context budget and, sometimes, correctness.

`/checkpoint` gives you a structured way to pause and check the alignment between what you set out to do and what is actually happening, without spending ten minutes reviewing the full session yourself. The output is deliberately tiny — under 150 words — so the check itself does not add meaningful overhead to the session it is trying to protect.

## When to use it

Reach for `/checkpoint` proactively during long sessions and reactively whenever something feels off:

- Roughly every 50 turns in a session that is still going — a natural heartbeat to confirm alignment.
- After a long debugging detour, before returning to the main track.
- When the user asks "are we still on track?" — this skill is the structured answer to that question.
- Before a major edit, when you want to confirm the work so far is proportionate to the plan.

Do not use it for a full session-quality audit with rule-violation checking — that is [`/rules-audit`](../behavioral-core/rules-audit.md). Checkpoint stays small and fast; rules-audit goes deep and thorough.

## Best practices

- **Run it before committing a large batch of changes.** A checkpoint before `git commit` catches unplanned files in the diff while it is still easy to separate them into a different commit.
- **Treat "significant drift" as a hard stop.** When the recommendation says "Significant drift. Consider `/compact` to reclaim context," treat that as a genuine signal, not a suggestion to ignore. Compacting at that point costs thirty seconds; continuing into deeper drift costs much more.
- **Let the 150-word budget do its job.** The skill is intentionally terse. Resist the urge to ask follow-up questions that expand it into a full review — if you want depth, use [`/rules-audit`](../behavioral-core/rules-audit.md) or [`/audit-context`](audit-context.md) instead.
- **Pair it with `/progress-log` before a `/clear`.** If the checkpoint recommendation is "Session is heavy. Run `/progress-log` and start fresh," follow that sequence: log first, then clear. The log preserves the session state so the next session can resume cleanly.

## How it improves your workflow

`/checkpoint` is the interval-based alignment check that prevents small drifts from becoming large ones. A session that is checked every 50 turns rarely needs emergency corrective action — problems surface while they are still small. The compact output format means the check costs almost nothing in context budget; the recommendation at the end converts the analysis directly into an action. Paired with [`/audit-context`](audit-context.md) at the session start and [`/token-pipeline`](token-pipeline.md) for in-flight pressure relief, it forms the proactive half of the context-engine's session health loop.

## Related

- [`/audit-context`](audit-context.md) — pre-session overhead measurement; use before the session starts rather than during
- [`/token-pipeline`](token-pipeline.md) — in-flight pressure-relief decision when context is filling
- [`/rules-audit`](../behavioral-core/rules-audit.md) — deeper post-hoc audit with rule-violation checking; use when checkpoint signals significant drift
- [`/belief-audit`](belief-audit.md) — file-content integrity check; complements checkpoint's task-alignment check
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — session-state preservation before compacting or clearing
- [Architecture](../../architecture.md) — where context management fits in the 8-component harness model
