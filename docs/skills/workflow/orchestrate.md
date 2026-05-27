# Orchestrate

`/orchestrate` is the manual entry point into the agentic workflow pipeline in the `workflow` plugin. When the automatic `route-prompt.sh` classifier picks the wrong pattern, when you want to start a sprint from an existing plan, or when you need to re-dispatch after a failed pipeline run, this skill lets you choose the pattern explicitly — single-agent, pipeline, fan-out, or TDD loop — and drives the dispatch from there.

For the pipeline pattern specifically, it runs a per-task loop: `/contract` re-reads plan criteria fresh from disk before each task (defeating context decay), a generator subagent implements the task, a reviewer subagent evaluates the diff, and `/verify` gates the result. The pipeline stops on the first failure and waits for your decision before continuing.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/orchestrate pipeline
```

The optional argument is the pattern: `single`, `pipeline`, `fan-out`, `tdd`, or `auto` (default). With `auto`, the skill applies the same dispatch matrix that `/dispatch` uses, but reads from the active plan rather than the raw prompt.

## Why you need it

The automatic router classifies prompts based on their text. That classification is a best guess — it works well in clear cases but can misjudge complex prompts, multi-task plans, or situations where you have a plan file ready but the prompt itself does not signal that. `/orchestrate` lets you override the router's decision and drive the right pattern yourself, from a plan that is already on disk and already has a `## Contract` section.

The more important reason is the per-task contract re-read. In a long session, context compaction can cause a generator to forget criteria from the plan. `/orchestrate` prevents this by calling `/contract` (the `agents` plugin) at the start of every task, which performs an actual `Read` tool call on the plan file and re-loads the criteria into the agent's context fresh. Without this step, a generator 30 turns into a session might silently implement the wrong thing because its understanding of the contract has drifted from what the file says. The discipline of stopping at every task boundary and re-reading is what makes the pipeline reliable across long sessions.

## When to use it

- When the auto-router routed to `single-agent` but your plan has multiple tasks that need the full pipeline loop with per-task verification.
- When you want to re-dispatch a failed task without re-running the whole sprint.
- When you explicitly want the TDD pattern and prefer to name it directly rather than waiting for the router's classification.
- When you have a plan in `.claude/plans/` and want to drive it through a specific pattern.

Do not use it for pattern selection — [`/dispatch`](../agents/dispatch.md) is the right tool when you want a recommendation on which pattern fits. `/orchestrate` executes a pattern you have already chosen.

## Best practices

- **Always have a plan file with a `## Contract` section.** The skill reads the active plan before dispatching and will stop if no plan exists or if the plan has no contract. The contract is what the per-task generators and reviewers are held to.
- **Do not skip the per-task verify step.** The `## Verify` gate after each task is what makes task failures attributable and isolatable. Skipping it to save time defers the failure to the next task, where it becomes much harder to diagnose.
- **Use `pipeline` for multi-task plans, `single` for one-off narrowly-scoped work.** The pipeline pattern's per-task loop adds overhead that is only worth it when there are distinct tasks whose success criteria can be verified independently. A single-task plan does not need the loop.
- **Let the pipeline stop on failure.** When a task fails verification, the pipeline halts and waits for you. This is the correct behavior — do not add flags or workarounds to continue past a failure. Diagnose the task, fix it, and resume.
- **Use `FORGE_ACTIVE_PLAN_OVERRIDE` for out-of-band plans.** If you have a plan that does not follow the `s<N>-<slug>.md` naming convention and want to run it through the pipeline, set `FORGE_ACTIVE_PLAN_OVERRIDE=<path>` to tell `find-active-plan.sh` which plan to use.

## How it improves your workflow

`/orchestrate` is the difference between "I wrote code for this plan" and "the plan's contract was verified at every task boundary by an independent reviewer and a real test command." The pipeline pattern it drives is not just a dispatch mechanism — it is a reliability mechanism. By composing `/contract`, generator subagents, reviewer subagents, and `/verify` into a repeatable per-task loop, it makes multi-task sprints auditable, failures locatable, and progress measurable against the original contract. The result is that finishing a sprint means something: every task has evidence, every criterion was checked, and the delta from plan to done is documented.

## Related

- [`../agents/contract.md`](../agents/contract.md) — re-reads the plan's Contract section at each task boundary inside the pipeline loop
- [`../agents/dispatch.md`](../agents/dispatch.md) — the pattern classifier; use instead when you want a routing recommendation
- [`../agents/fan-out.md`](../agents/fan-out.md) — the fan-out pattern this skill delegates to when `$ARGUMENTS` is `fan-out`
- [`../evaluator/verify.md`](../evaluator/verify.md) — the per-task evidence gate at the end of each pipeline task
- [`/tdd-loop`](tdd-loop.md) — the TDD pattern this skill delegates to when `$ARGUMENTS` is `tdd`
- [`/living-spec`](living-spec.md) — initialize before dispatch to give all agents a shared spec to read from
- [Architecture](../../architecture.md) — orchestration and multi-agent decomposition in the 8-component harness model
