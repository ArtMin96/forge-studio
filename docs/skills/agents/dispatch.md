# Dispatch

`/dispatch` is a task decomposition router. You describe a task; it analyzes the scope, file count, interdependence, and risk level, then recommends exactly one execution route: handle it solo, run a [`/fan-out`](fan-out.md) for parallel batch work, or run a full planner→generator→reviewer pipeline via [`/worktree-team`](worktree-team.md). When a pipeline route is chosen, it also decides how many parallel reviewers to spawn based on the number of independent files the planner enumerated. It belongs to the `agents` plugin, which provides multi-agent orchestration infrastructure for Forge Studio.

---

## Install

```bash
/plugin install agents@forge-studio
```

```text
/dispatch
```

`/dispatch` is invoked after you have described a task that may warrant more than direct execution. It reads the task description and emits a `DISPATCH RECOMMENDATION` block with route, reason, estimated scope, and risk level. When the pipeline route is chosen and the planner has finished, it also emits a `REVIEWER POOL` block and logs the pool decision to `.claude/handoffs.jsonl`.

## Why you need it

Every multi-step task involves an implicit routing decision: should one agent handle this sequentially, or should the work be parallelized or staged across specialized agents? Made intuitively, that decision is invisible — you cannot review it, audit it, or learn from it when something goes wrong. Made poorly, it burns tokens on pipeline overhead for a two-line fix, or skips review entirely for an architectural change that deserved it.

`/dispatch` makes the routing decision explicit and auditable. It applies a decision matrix — files touched, operation type, interdependence, risk — and emits a one-line reason alongside the route classification. The recorded entry in `.claude/handoffs.jsonl` means you can look back at any run and see exactly why the pipeline was chosen, which files were enumerated as independent, and how the reviewer pool was sized. That audit trail turns a judgment call into a traceable process step.

## When to use it

- Before starting any task that may touch 5 or more files, has independent sub-tasks worth parallelizing, or carries enough architectural risk to warrant separated planning and review.
- After a planner subagent finishes its output, to decide how many parallel reviewers to dispatch based on the explicitly enumerated independent files.
- When you are unsure whether a task warrants the overhead of a pipeline or can be done directly.

Do not use it for executing the dispatched pattern — once the route is chosen, `/fan-out` handles parallel batches and `/worktree-team` handles full pipelines. Do not use it for one-line fixes or small bugs touching two files or fewer; the routing overhead is not earned there. Do not spawn a reviewer pool for mutually coupled files where a single reviewer must consider all files together.

## Best practices

- **Check interdependence before file count.** The decision matrix uses files touched as a signal, but file count alone is a weak proxy. Five files with shared mutable state belong to a pipeline, not a fan-out; three files with completely independent changes may warrant fan-out. Assess how the changes relate before locking a route.
- **Take the pool decision seriously.** The adaptive reviewer pool scales the number of parallel reviewers to match the planner's enumerated independent files, capped at 5. If the planner described work in prose without a file list, the pool defaults to a single reviewer — ask the planner to re-emit a `FILES:` block if pooling matters.
- **Log every pipeline route.** The `.claude/handoffs.jsonl` entry is not optional for pipeline routes. An undocumented routing decision is unreviewable; the one-line classification with reason is the audit trail.
- **Watch for fan-out with shared state.** Two parallel subagents editing the same file will race — the second overwrites the first. Refuse fan-out when the file list overlaps, regardless of what the file count says.
- **Trust the TDD-Loop route when requirements are clear.** A clear requirement is exactly when TDD is cheapest — the test writes itself. Skipping it for speed forfeits the artifact that proves the requirement was met.

## How it improves your workflow

Without `/dispatch`, every task begins with an unexamined routing decision buried in the agent's implicit behavior. With it, the decision is surfaced, graded against a matrix, recorded, and handed off with a reason. Over time the handoff log becomes a record of how work was decomposed — which tasks went to pipeline, which to fan-out, which were done solo, and why. That record is what makes a multi-agent workflow auditable rather than opaque, and reviewable rather than a black box.

## Related

- [`fan-out.md`](fan-out.md) — the parallel batch execution pattern; `/dispatch` routes here for same-operation-on-many-files work
- [`worktree-team.md`](worktree-team.md) — the physically-isolated pipeline; `/dispatch` routes here for new-feature and architectural-change work
- [`contract.md`](contract.md) — the generator's entry gate inside the pipeline; invoked after `/dispatch` chooses the Pipeline route
- [`../evaluator/verify.md`](../evaluator/verify.md) — the evidence gate at the end of each pipeline task; `/dispatch` passes aggregator findings to it
- [`../workflow/orchestrate.md`](../workflow/orchestrate.md) — the top-level orchestration skill that invokes `/dispatch` as part of the pipeline loop
- [Architecture](../../architecture.md) — multi-agent decomposition in the 8-component harness model
