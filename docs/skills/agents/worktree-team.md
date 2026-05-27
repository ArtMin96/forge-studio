# Worktree Team

`/worktree-team` bootstraps a set of parallel agents — up to five — each in its own isolated git worktree with a role-scoped `CLAUDE.md` and optional path ownership restrictions. Unlike [`/fan-out`](fan-out.md), which runs batches inside a single session, `/worktree-team` gives each role a physically separate checkout of the repository, its own write scope, and its own behavioral configuration. When the skill finishes, it emits the launch commands for each worktree session and writes an active-roles registry that the `directory-ownership` hook uses to enforce write boundaries. It belongs to the `agents` plugin, which provides the multi-agent orchestration harness for Forge Studio.

---

## Install

```bash
/plugin install agents@forge-studio
```

```text
/worktree-team planner,generator,reviewer
/worktree-team planner,generator,reviewer --owned generator:src/api/,reviewer:
```

The argument is a comma-separated list of role names. The optional `--owned` flag binds each role to the directory paths it may write to. If roles are omitted, the skill defaults to `planner`, `generator`, `reviewer`.

## Why you need it

Fan-out and pipeline patterns both run inside one session. That works well when the operations are independent or when the phases are short enough that context from an earlier phase does not contaminate a later one. But for long-running work — a multi-day feature branch, a research stream running alongside implementation, a code review experiment where you want multiple agents to attack the same problem in isolation and compare results — a single session is not enough separation.

When two streams interleave edits in the same checkout, they race. When a planner's exploratory reads are in the same context as the generator's implementation, the generator's decisions are colored by the planner's framing in ways that are hard to untangle. When a reviewer can write files, the boundary between "reviewing" and "implementing" collapses. `/worktree-team` enforces separation at the level of the filesystem: each role gets its own working tree, its own CLAUDE.md that describes its responsibility and the directories it may touch, and its own session. Roles coordinate through the shared plan file and the ledger, not through shared context.

## When to use it

- Two or more streams that must not interleave edits — for example, one agent working on `src/api/` and another on `src/ui/` simultaneously.
- Long-running research alongside implementation, where neither should block on the other's context and the research results need to survive compaction.
- Code review experiments where you want multiple agents to independently evaluate the same implementation and compare findings without one review influencing another.
- Any time previous attempts to coordinate via a single session produced merge conflicts or context contamination.

Do not use it for in-session batch work where files are truly independent — [`/fan-out`](fan-out.md) is cheaper there. Do not use it for a straightforward linear planner→generator→reviewer pass — [`/dispatch`](dispatch.md) handles that without the overhead of separate worktrees. Do not use it when roles need to share intermediate state; worktrees hurt coordination when the data that must pass between roles is not expressible as a file.

## Best practices

- **Start with a clean working tree.** Uncommitted changes in the main checkout propagate into every worktree when it is created. Commit or stash before bootstrapping, or accept that each role inherits those changes and plan accordingly.
- **Use `--owned` when roles have clear boundaries.** Without explicit owned-directory declarations, the `directory-ownership` hook stays silent and roles can write anywhere. The enforcement is only as strong as the `--owned` specification. If the role boundaries matter, declare them.
- **Keep the active-roles registry current.** `.claude/agents/active-roles.json` is what the `directory-ownership` hook reads to decide whether a write is in scope. Remove or update it as soon as a team is disbanded — a stale registry enforces stale scope, which will block legitimate writes.
- **Clean up worktrees explicitly.** After each role finishes and its branch is merged, run `git worktree remove .claude/worktrees/<role>-<sha>`. Stale worktrees left from a crashed run will cause path-exists collisions the next time you bootstrap the same role names at the same commit.
- **Never exceed five roles.** `/worktree-team` enforces a hard cap of five roles. Beyond that, token burn and coordination overhead grow faster than the parallelism benefit. If you genuinely need more roles, consider whether the task should be decomposed into two sequential team runs rather than one large parallel one.

## How it improves your workflow

The worktree-team pattern solves the fundamental tension in multi-agent work between isolation and coordination. Pure isolation — separate repositories, separate projects — makes coordination hard. Pure coordination — one session, one context — makes isolation impossible. Git worktrees are the middle ground: each role has its own working tree and its own behavioral envelope, but all roles share the same commit history, the same plan file, and the same ledger. Changes flow between roles through commits and file-based handoffs, not through shared context. The result is a team of agents that are independently auditable, separately reviewable, and collectively coherent — without any of the merge conflicts that come from having multiple agents write to the same checkout simultaneously.

## Related

- [`dispatch.md`](dispatch.md) — routes tasks to `/worktree-team` for new-feature and architectural-change work; the linear pipeline alternative to physical worktree isolation
- [`fan-out.md`](fan-out.md) — use instead for in-session batch work where physical isolation between roles is not required
- [`contract.md`](contract.md) — each generator role invokes `/contract` at the start of its worktree turn to re-read the plan criteria from disk
- [`lean-agents.md`](lean-agents.md) — reduces per-role token overhead by narrowing tools and compressing results in each worktree session
- [Architecture](../../architecture.md) — multi-agent decomposition and execution traces in the 8-component harness model
