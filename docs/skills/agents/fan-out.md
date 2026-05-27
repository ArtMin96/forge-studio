# Fan-Out

`/fan-out` runs the same operation across many independent files simultaneously by dispatching one subagent per batch and collecting the results. You give it an operation, a file list, and any constraints; it validates that the files are independent, groups them into batches of three to five, launches each batch as its own isolated subagent, then surfaces a unified summary with any conflicts. It belongs to the `agents` plugin, which provides the multi-agent orchestration harness for Forge Studio.

---

## Install

```bash
/plugin install agents@forge-studio
```

```text
/fan-out
```

Invoke `/fan-out` after [`/dispatch`](dispatch.md) has classified the task as a batch operation. You describe the operation as an `Operation / Files / Constraints` template; the skill handles batching, subagent dispatch, and result synthesis from there. For write operations, pass `isolation: worktree` to prevent subagents from racing on the same file.

## Why you need it

Applying the same change to a dozen files sequentially is slow and wastes the main context window with repetitive work that does not build on itself. Doing it in a single agent turn is even worse: the context fills with file after file and quality degrades before you reach the last one. The tempting shortcut — having one agent read all twelve files and edit them in sequence — is exactly the pattern that produces inconsistent results across the batch, because each edit builds on an increasingly crowded context.

`/fan-out` solves this by giving each batch its own isolated context. A subagent handling files four through six has no knowledge of what the agent handling files one through three did, and it does not need to — independence is the precondition for fan-out in the first place. Each batch gets a clean context, the same operation template, and its own result block. The synthesis step at the end catches any conflicts between batches. The result is consistent, reviewable output across the full file list without the quality degradation of a single-agent sequential pass.

## When to use it

- Adding the same middleware, annotation, or import to many controllers, modules, or components.
- Bulk migration across a codebase — updating import paths, renaming a constant, swapping a deprecated API call.
- Parallel exploration of unrelated subsystems when you want a structured summary from each without the subsystems interfering with each other's context.

Do not use it for sequential pipelines where each step depends on the previous result — use [`/dispatch`](dispatch.md) to route to [`/worktree-team`](worktree-team.md) instead. Do not use it when files share mutable state; parallel subagents will race and the second will silently overwrite the first.

## Best practices

- **Validate independence before dispatching.** The independence check is step two of the protocol for a reason. Before spawning subagents, confirm that each file can be modified without knowledge of the other files in the batch and that the operation is the same for each target (parameterized, not custom).
- **Keep batch size between three and five.** Smaller batches mean more subagents and more overhead; larger batches push each agent toward the context quality degradation the skill exists to avoid. Three to five is the empirically validated sweet spot.
- **Use `isolation: worktree` for write operations.** Read-only exploration agents can share a worktree safely; write agents cannot. Without worktree isolation, two agents editing files that happen to share a dependency can produce a corrupt intermediate state.
- **Verify one result manually before trusting the batch.** The synthesis step catches structural conflicts, but it does not substitute for spot-checking. Pick one result from the batch and confirm it matches your expectations before accepting the rest.
- **Cap at five parallel agents.** More than five is hard to review and the coordination overhead begins to outweigh the parallelism benefit. If the file list is longer, run multiple fan-out passes rather than raising the cap.

## How it improves your workflow

Batch work is one of the highest-leverage uses of multi-agent orchestration: the task is inherently parallel, the output of each unit is independent, and the main agent is free to do other work while the batch runs. `/fan-out` makes that leverage routine by handling the batching logic, the isolation decision, and the result synthesis automatically. Instead of a long sequential pass that degrades over time, you get a set of clean parallel runs with a unified report — and the synthesis step ensures that any inconsistency across the batch surfaces immediately rather than being discovered during code review.

## Related

- [`dispatch.md`](dispatch.md) — routes tasks to `/fan-out` after classifying them as batch operations
- [`worktree-team.md`](worktree-team.md) — use instead when batches share state or when physical isolation between roles is required
- [`lean-agents.md`](lean-agents.md) — reduces per-subagent token overhead when running large fan-out batches
- [Architecture](../../architecture.md) — multi-agent decomposition in the 8-component harness model
