# Contract

`/contract` is a pre-implementation gate that mechanically re-reads the active sprint plan from disk and prints every success criterion verbatim before any code is touched. You invoke it at the start of an implementation turn; it finds the current plan file, extracts the `## Contract` section, acknowledges each criterion as UNDERSTOOD or UNCLEAR, and runs a baseline check to verify the plan's stated file-state assumptions still match what is on disk. If any criterion is unclear or any baseline assertion mismatches, it stops and refuses to proceed — no guessing, no silent deviation. It belongs to the `agents` plugin, which provides the full multi-agent orchestration harness for Forge Studio.

---

## Install

```bash
/plugin install agents@forge-studio
```

```text
/contract
```

`/contract` takes no arguments. It resolves the active plan automatically from `.claude/plans/` and reads it fresh. It is normally invoked by the orchestrator at the start of each generator turn, but you can run it yourself before any implementation step where you want a crisp read of what "done" means.

## Why you need it

In a long session — especially one that has been compacted or has run through multiple agent handoffs — the generator's memory of what the plan actually requires is unreliable. It does not matter how clearly the planner wrote the criteria ten turns ago: context windows compress, early detail fades, and the generator starts working from a hazy reconstruction rather than the authoritative text. The result is implementation that drifts from the original criteria in ways that are invisible until review catches it — or doesn't.

`/contract` closes that gap by forcing an actual `Read` tool call on the plan file at the moment implementation begins. The criteria are loaded fresh from disk, not recalled from memory. If a plan was amended after the initial read, the disk version is what the generator sees. And if the plan's baseline assertions — file line counts, empty YAML fields, expected line references — no longer match what is in the repo, the baseline check surfaces that mismatch before a single edit is made, preventing an entire class of "the plan described a different codebase" errors.

## When to use it

- At the start of every non-trivial implementation turn in a planner→generator→reviewer pipeline, before calling any Edit or Write tool.
- When a generator subagent is about to begin work from an existing plan and you want an explicit acknowledgment that the criteria are understood.
- When a long or compacted session resumes and you are uncertain whether the generator's in-context memory of the plan criteria is still accurate.
- Whenever a step claims to be "done" but has not produced an evidence link to the contract.

Do not use it for one-line edits or trivial fixes where no plan file exists — direct work is fine there. When the task itself still needs definition, use [`/scope`](../behavioral-core/scope.md) instead; `/contract` re-reads criteria from an already-written plan, it does not author a new one.

## Best practices

- **Let it block you.** When the baseline check exits with a mismatch, that is a signal to update the plan, not to proceed anyway. A plan describing a different line count than what is on disk is a stale plan — the generator implementing from it will produce wrong output.
- **Run it at the task boundary, not mid-edit.** The skill's checklist is designed to run before any Edit or Write call. Starting a `/contract` read after you have already made changes defeats the purpose of the gate.
- **Treat UNCLEAR as a real stop.** The output labels each criterion UNDERSTOOD or UNCLEAR. An UNCLEAR criterion is an ambiguity the plan author needs to resolve, not an invitation to guess. Surface it and wait.
- **Include the baseline-check stdout in your evidence.** The skill requires that you paste the baseline-check output into your reply. This creates an auditable record that the check ran and passed before implementation began.
- **Pair it with `/verify` at the end.** `/contract` is the entry gate; [`/verify`](../evaluator/verify.md) is the exit gate. Between them they bracket the implementation turn with a known-good start state and a graded end state.

## How it improves your workflow

The planner→generator→reviewer pipeline is only as reliable as the handoff between planning and implementation. Without a re-read, that handoff degrades over the course of a session: the generator works from memory, memory is selective, and subtle criteria slip. `/contract` makes the handoff lossless by anchoring every implementation turn to the canonical disk state of the plan. The baseline check adds a second layer: it confirms the repo itself matches the plan's assumptions, so the generator is not implementing against a ghost. Together, these two checks convert the pipeline from a best-effort workflow into a verifiable one — the kind you can hand to a reviewer and say, with evidence, that the generator knew exactly what it was supposed to do.

## Related

- [`/scope`](../behavioral-core/scope.md) — use when the task itself still needs a written definition; `/contract` is the alternative once a plan already exists
- [`dispatch.md`](dispatch.md) — routes tasks to the planner→generator→reviewer pipeline that `/contract` guards
- [`worktree-team.md`](worktree-team.md) — the physically-isolated pipeline variant; each generator role invokes `/contract` at the start of its worktree turn
- [`../evaluator/verify.md`](../evaluator/verify.md) — the exit gate that checks contract compliance after implementation; pairs with `/contract` to bracket each task
- [Architecture](../../architecture.md) — multi-agent orchestration in the 8-component harness model
