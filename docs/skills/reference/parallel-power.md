# Parallel Power

`/parallel-power` is the reference guide for parallel execution in Claude Code. Rather than dispatching work, it surfaces the full playbook — worktrees, writer/reviewer splits, fan-out batch processing, orchestrator-worker decomposition, and session-per-concern patterns — so you can pick the right approach before committing to one. It belongs to the `reference` plugin, which provides passive, zero-cost reference content surfaced inline when you need it.

---

## Install

```bash
/plugin install reference@forge-studio
```

```text
/parallel-power
```

No arguments. Invoke it whenever you are choosing between parallel strategies or want the full pattern reference surfaced inline.

## Why you need it

Parallel execution has a decision problem: worktrees, fan-out loops, subagents, and session-per-concern all solve overlapping problems, but each has a different setup cost, isolation guarantee, and review burden. Picking the wrong one adds coordination overhead rather than removing it. `/parallel-power` makes the tradeoffs explicit for each pattern — token cost, review surface, isolation level — so the choice is deliberate rather than habitual.

It is also the fastest way to remember the exact flags and shell idioms involved, from `--worktree` invocation syntax to the `while read file` fan-out loop, without having to grep documentation or recall from memory.

## When to use it

- Before deciding whether to reach for `/dispatch`, `/fan-out`, or `/worktree-team` — use this to orient first.
- When explaining parallel patterns to another team member or documenting a decision.
- When the task involves multiple independent units of work and you want a reminder of the sweet-spot limits (for example, 3–5 parallel agents is the reviewed maximum before coordination cost overtakes throughput).

Do not use it for dispatching the actual work — use [`/dispatch`](../agents/dispatch.md) to route the work or [`/fan-out`](../agents/fan-out.md) and `/worktree-team` to execute it instead.

## Best practices

- **Orient before you dispatch.** Read the pattern descriptions once before invoking `/dispatch` or `/fan-out`. A five-second orientation prevents the wrong isolation model from causing merge conflicts or context bleed.
- **Respect the 3–5 agent ceiling.** The skill documents this limit explicitly because more parallel agents becomes harder to review than it is worth. If the work exceeds five independent units, decompose it into sequential batches.
- **Use `.worktreeinclude` for secrets.** When working in parallel worktrees, gitignored files such as `.env` are not copied automatically. The `.worktreeinclude` mechanism from the reference prevents hard-to-debug auth failures in isolated branches.
- **Separate writing and reviewing sessions.** The writer/reviewer split pattern exists because fresh context catches anchoring bias. The reference is a reminder that the review session should be new, not `--resume` on the same session that wrote the code.
- **Name sessions explicitly.** `claude -n "auth-refactor"` makes resumption and context management tractable. Unnamed sessions are hard to resume correctly.

## How it improves your workflow

`/parallel-power` removes the gap between knowing that parallel execution is possible and knowing which form of it to use. By surfacing all five patterns in one place — with concrete shell examples and explicit tradeoff notes — it converts an architectural decision into a quick scan rather than a research task. The result is that parallelism becomes a routine tool rather than an occasional heroic effort, and the patterns used across sessions are consistent and reviewable.

## Related

- [`/dispatch`](../agents/dispatch.md) — routes the work to the right execution pattern after you have chosen one
- [`/fan-out`](../agents/fan-out.md) — executes the fan-out batch pattern
- [`unix-pipe.md`](unix-pipe.md) — headless and piping patterns for automation outside interactive sessions
- [Architecture](../../architecture.md) — multi-agent decomposition in the 8-component harness model
