# Living Spec

`/living-spec` initializes `.claude/spec.md` from the latest plan's `## Contract` section, creating the shared source of truth that all subagents in a pipeline read from. It belongs to the `workflow` plugin. After initialization, the `after-subagent.sh` hook appends delta blocks to the spec as each phase completes — planner, generator, reviewer — so the document reflects both what was agreed at the start and what has actually shipped so far.

Unlike `/contract`, which re-reads static criteria to fight context decay, the living spec is continuously updated. The reviewer step compares code against the spec, not just against the original plan, which means discrepancies accumulate as visible evidence rather than getting lost in compacted context.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/living-spec
```

No arguments. The skill resolves the active plan automatically.

## Why you need it

A multi-agent pipeline involves context boundaries: the planner's reasoning is not in the generator's context, and the generator's choices are not in the reviewer's context. In a long session, even the original plan criteria can decay through compaction. The living spec solves both problems at once. It gives every agent a single file to read that contains both the original contract and the accumulated record of what has been completed — a growing diff between intent and reality that no individual agent's context needs to hold in memory.

The delta blocks appended by `after-subagent.sh` are what make the spec "living." After the generator completes, the spec shows which contract items are done and which are pending. The reviewer reads that state directly rather than trying to reconstruct it from the conversation. This reduces the chance of the reviewer blessing an incomplete implementation because the generator reported success confidently.

## When to use it

- Immediately after a plan is approved and before you dispatch the first generator — run it once to initialize the spec for that plan.
- If the plan itself changes significantly mid-sprint, run it again to reinitialize from the updated contract (you will be asked to confirm the overwrite).
- When starting a new sprint whose plan has a `## Contract` section and you want all downstream agents to share a persistent spec.

Do not use it for session progress logging — that is [`/progress-log`](../long-session/progress-log.md), which records session-to-session handoff state. The living spec records plan-execution state.

## Best practices

- **Run it before dispatching generators, not after.** The spec must exist before agents start completing tasks so that `after-subagent.sh` has a file to append deltas to. Initializing mid-pipeline means the earliest deltas are missing.
- **Do not manually edit the deltas section.** The `## Deltas` section in the spec is append-only and written by `after-subagent.sh`. Manual edits create an inconsistency between what the hook writes and what the reviewers read.
- **Pair it with `/feature-list`.** The living spec gives the narrative contract view; `/feature-list` gives the machine-checkable JSON view of the same criteria. The two complement each other: spec deltas track progress in prose, feature-list entries track it in a format `/verify` can gate against.
- **Do not confuse it with `/contract`.** `/contract` is the per-task re-read of plan criteria that the generator receives at the start of each task to prevent context decay. The living spec is the persistent document that accumulates the delta record across the whole sprint.

## How it improves your workflow

`/living-spec` is the connective tissue between planning and execution in a multi-agent sprint. By providing a file that is initialized from the contract and continuously updated as work completes, it eliminates the most common failure mode of pipeline orchestration: agents operating on different, individually-cached versions of the truth. Every agent reads the same spec, sees the same accumulated deltas, and can therefore make consistent decisions about what is done and what remains.

## Related

- [`../agents/contract.md`](../agents/contract.md) — re-reads plan criteria fresh each task turn; complements the living spec's persistent delta record
- [`/orchestrate`](orchestrate.md) — the pipeline driver that benefits from having a living spec initialized before dispatch
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — session-to-session handoff; use instead for cross-session progress state
- [`../long-session/feature-list.md`](../long-session/feature-list.md) — the machine-checkable parallel view of the same contract criteria
- [`../evaluator/verify.md`](../evaluator/verify.md) — cross-references spec deltas with features.json when gating task completion
- [Architecture](../../architecture.md) — context management and multi-agent coordination in the 8-component harness model
