# agents

Multi-agent decomposition for Claude Code. When a task is too large for a single context window, or when you want a critic that cannot be primed by the implementer, this plugin splits the work into three role-isolated subagents: **planner** (read-only research, produces a plan), **generator** (writes the code, one task at a time), and **reviewer** (adversarial critique of the diff). A contract-reread mechanism ensures each subagent sees the current sprint criteria from disk — not a potentially compacted or stale in-context copy.

## When to use

- A task touches **5+ files** or has clear research → design → build → review phases
- You want a critic separate from the implementer
- You're applying the **same operation to many independent files** (use `/fan-out`)
- Two streams of work must not interleave edits (use `/worktree-team`)

For simple single-file changes, direct work is faster — the subagent overhead is only worth it when isolation buys you something.

## Subagent types

The three roles are defined in `plugins/agents/agents/`. You dispatch them via the Agent tool's `subagent_type` parameter, or through the `/dispatch` and `/orchestrate pipeline` skills.

| Role | Capabilities | What it does |
|------|-------------|--------------|
| `agents:planner` | Read, Grep, Glob, Bash (no Edit/Write) | Explores the codebase and produces a plan with a `## Contract` section and `#### T<n>` task headings |
| `agents:generator` | Read, Write, Edit, Bash | Implements one task from the plan; one task per dispatch |
| `agents:reviewer` | Read, Grep, Glob, Bash (no Edit/Write) | Adversarial critique of the generator's diff; verifies contract compliance |

The planner cannot write code. The reviewer cannot change code. The generator cannot publish a plan. Capability isolation is schema-level, not instruction-level.

## How it works

```text
            ┌─────────┐    plan     ┌──────────┐    diff    ┌──────────┐
 user ───►  │ planner │   ───►      │generator │   ───►     │ reviewer │  ───► verdict
            └─────────┘             └──────────┘            └──────────┘
        Read/Glob/Grep/Bash     Read/Write/Edit/Bash    Read/Glob/Grep/Bash
                                /Glob/Grep              (no Write/Edit)
```

`/dispatch` recommends which pattern fits the task. `/fan-out` runs the same prompt over many files in parallel. `/worktree-team` boots N agents into isolated git worktrees with optional path ownership.

## Skills

| Skill | Command | What it does | When to use |
|-------|---------|-------------|-------------|
| contract | `/contract` | Re-reads the sprint contract verbatim from the most recent plan file in `.claude/plans/`, then confirms each success criterion before generating | At the start of every non-trivial generation step; prevents context-decay from silently corrupting the criteria |
| dispatch | `/dispatch` | Routing recommendation: solo agent, `/fan-out`, or planner→generator→reviewer pipeline; calls `inject-contract.sh` before each subagent prompt to prepend the active sprint contract | Before starting any task that may touch 5+ files or has independent sub-tasks; produces a reasoned route choice |
| fan-out | `/fan-out` | Dispatches one subagent per file with a shared prompt template, then collects results | When the same operation applies to many independent files and results don't depend on each other |
| worktree-team | `/worktree-team <roles>` | Bootstraps N (max 5) parallel agents in isolated git worktrees, each with a role-scoped CLAUDE.md and optional path ownership | When parallel streams of work must not share the same file tree; prevents merge conflicts mid-sprint |
| lean-agents | `/lean-agents` | Recommends a 4-layer isolation profile (model, maxTurns, allowed-tools, CLAUDE_CODE_SIMPLE) that drops subagent overhead from ~50K to ~5K tokens per turn | Before launching a heavy fan-out or multi-stage pipeline when token budget is a concern |

## Hooks

| Hook | Event | Matcher | When it fires | What it does |
|------|-------|---------|--------------|-------------|
| `contract-reread.sh` | `SubagentStart` | (none — fires for every subagent) | Before every subagent dispatch | Finds the most-recently modified `.claude/plans/*.md`, extracts the `## Contract` section (anchored to the exact heading so it doesn't bleed into adjacent headings), and writes the result to `.claude/state/active-contract.md`. The dispatched subagent reads a fresh copy from disk rather than relying on context memory. Exits 1 (warning, never blocks) if no plan exists or no Contract section is found. Output consumed by `inject-contract.sh` during dispatch |
| `contract-check.sh` | `SubagentStop` | (none; filters internally on `*review*` agent types) | After a reviewer subagent finishes | Warns when the reviewer's output does not mention "contract", signaling a missed verification step. Silent when there is no active plan |
| `output-schema-check.sh` | `SubagentStop` | (none; filters internally on `generator` agent type) | After a generator subagent finishes | Warns when the generator did not produce artifacts declared in the plan's Contract / Output Schema section. Parses the plan for file paths and checks that each exists on disk |
| `directory-ownership.sh` | `PreToolUse` | `Edit\|Write` | On every Edit or Write when `FORGE_DIRECTORY_OWNERSHIP=1` | When `$CLAUDE_AGENT_ROLE` is set and matches an entry in `.claude/agents/active-roles.json`, blocks edits outside that role's declared owned-directory list. Useful in `/worktree-team` mode to prevent one agent from touching another agent's subtree. Silently passes when the env var is not set |

## How to use it

**Typical flow via workflow plugin:**
Type `/orchestrate pipeline` with an active plan — the dispatch chain in this plugin handles the planner→generator→reviewer transitions automatically.

**Direct dispatch:**
Use the Agent tool with `subagent_type: agents:generator` (or `agents:planner` / `agents:reviewer`). The `contract-reread.sh` hook fires automatically before the subagent starts, so the active contract is always fresh.

**Manual routing decision:**
Run `/dispatch` first. It will tell you whether the task warrants a pipeline, a fan-out, or direct solo work — with the reasoning spelled out.

## Agents

`generator.md`, `planner.md`, `reviewer.md` — the three role definitions, each with capability-isolated tool lists.

## Disable

`/plugin disable agents@forge-studio`. The subagent roles and contract hooks become unavailable; single-agent work is unaffected.
