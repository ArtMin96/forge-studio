# agents

Multi-agent decomposition. Splits work across **planner → generator → reviewer** so each role runs in its own subagent with isolated tools. Driven per-task by `/orchestrate pipeline` (workflow plugin). Each task gets its own subagent pair; this keeps each agent's tool-call surface small enough to fit Anthropic's `maxTurns` budget reliably.

## What it does

Claude Code can dispatch subagents, but they default to "do everything." This plugin gives them roles. The planner only reads. The generator only writes. The reviewer only critiques. Capability isolation makes a hostile change impossible — a generator cannot publish a plan, a planner cannot edit code.

## When to use

- A task touches **5+ files** or has clear research → design → build → review phases
- You want a critic separate from the implementer
- You're applying the **same operation to many independent files** (use `/fan-out`)
- Two streams of work must not interleave edits (use `/worktree-team`)

## How it works

```text
            ┌─────────┐    plan     ┌──────────┐    diff    ┌──────────┐
 user ───►  │ planner │   ───►      │generator │   ───►     │ reviewer │  ───► verdict
            └─────────┘             └──────────┘            └──────────┘
        Read/Glob/Grep/Bash     Read/Write/Edit/Bash    Read/Glob/Grep/Bash
                                /Glob/Grep              (no Write/Edit)
```

`/dispatch` decides which pattern fits the task. `/fan-out` runs the same prompt over many files in parallel. `/worktree-team` boots N agents (max 5) into isolated git worktrees with role-scoped CLAUDE.md and optional path ownership.

## Skills

| Skill | Purpose |
|---|---|
| `/dispatch` | Routing recommendation: solo vs fan-out vs pipeline |
| `/contract` | Re-read the plan's success criteria from disk before generating (prevents context decay) |
| `/fan-out` | One subagent per file with a shared prompt template |
| `/worktree-team` | Bootstrap N parallel agents in isolated git worktrees |
| `/lean-agents` | Recommend a 4-layer isolation profile to drop subagent overhead from ~50K to ~5K tokens/turn |

## Hooks

| Event | Hook | What it does |
|---|---|---|
| `PreToolUse` (`Edit\|Write`) | directory-ownership | Enforce per-role path allowlists when `/worktree-team` declared them |
| `SubagentStop` | contract-check | Re-read the plan's contract; verify the subagent honored it |
| `SubagentStop` | output-schema-check | Validate the subagent's reply against its declared schema |

## Agents

`generator.md`, `planner.md`, `reviewer.md` — the three role definitions, each with capability-isolated tool lists.

## Disable

`/plugin disable agents@forge-studio`
