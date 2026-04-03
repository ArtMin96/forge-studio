# Forge Studio

**Agent = Model + Harness.** The harness is everything except the model: behavioral steering, context management, memory, evaluation, orchestration, and multi-agent decomposition. Research shows changing only the harness can produce a 6x performance gap.

Forge Studio implements harness principles as composable Claude Code plugins.

7 plugins. 30 skills. 11 hooks. 4 agents.

---

## Install

```bash
# Add the marketplace
/plugin marketplace add ArtMin96/forge-studio

# Install by layer — pick what you need

# Behavioral Steering (recommended: start here)
/plugin install behavioral-core@forge-studio

# Context Management
/plugin install context-engine@forge-studio

# Memory Architecture
/plugin install memory@forge-studio

# Evaluation & Quality Gates
/plugin install evaluator@forge-studio

# Orchestration
/plugin install workflow@forge-studio

# Multi-Agent Decomposition
/plugin install agents@forge-studio

# Reference & Tips
/plugin install reference@forge-studio
```

After installing, start a new session for plugins to load.

### Recommended CLAUDE.md

A lean CLAUDE.md template is included at `templates/CLAUDE.md`. Designed to work with forge-studio plugins — covers personality, judgment, context management, self-evaluation, and project config without repeating what hooks enforce.

```bash
cp templates/CLAUDE.md ./CLAUDE.md
# Edit the Project Config and Conventions sections for your project
```

### Recommended settings.json

A power-user settings.json template is included at `templates/settings.json`. Enables extended thinking, maximum effort, LSP tools, and bypass permissions with a deny list for destructive commands.

```bash
# Copy to your global Claude Code config
cp templates/settings.json ~/.claude/settings.json
```

Key choices:
- **Bypass permissions + deny list** — allows everything except destructive commands. Two safety layers: the deny list here and behavioral-core hooks.
- **No co-authored-by** — removes the "Co-Authored-By: Claude" trailer from commits
- **Always thinking + high effort** — maximizes reasoning quality at the cost of more tokens
- **LSP + tool search** — enables IDE-level code navigation and on-demand tool loading
- **Auto-compact at 75%** — compacts context earlier than the default 95%, preventing quality decay
- **90-day transcript retention** — extends the default 30-day cleanup period

See [Settings Best Practices](docs/settings.md) for detailed documentation.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                User / IDE                   │
├─────────────────────────────────────────────┤
│           Harness (Forge Studio)            │
│                                             │
│  behavioral-core ──── Steering & discipline │
│  context-engine ───── Context window mgmt   │
│  memory ───────────── Cross-session recall  │
│  evaluator ────────── Quality gates & review│
│  workflow ─────────── Orchestration patterns│
│  agents ───────────── Multi-agent triad     │
│  reference ────────── Power-user tips       │
│                                             │
├─────────────────────────────────────────────┤
│              Claude Model                   │
└─────────────────────────────────────────────┘
```

See [docs/architecture.md](docs/architecture.md) for the full design rationale.

---

## Plugin Reference

### behavioral-core — Behavioral Steering

Modular behavioral anchoring via `rules.d/` directory. Each rule is a separate file, priority-ordered by numeric prefix. Add, remove, or reorder rules by managing files. Hooks enforce 100% compliance where system prompt instructions degrade to ~80%.

| Skill | Purpose |
|-------|---------|
| `/rules-audit` | Audit session for sycophancy, apologies, scope creep, filler |
| `/scope <task>` | Define task boundaries and acceptance criteria |
| `/timebox [N]` | Set a message budget (default 15) for the current task |

### context-engine — Context Management

Progressive 5-stage context pressure tracking replaces fixed message-count thresholds. Warns at ~50% (re-read files), ~65% (consider compact), ~75% (recommend compact), ~85% (recommend handoff), ~92% (critical — handoff now). Automatically uses actual context percentage when Claude Code exposes it.

| Skill | Purpose |
|-------|---------|
| `/handoff [topic]` | Generate a session transfer document |
| `/resume` | Pick up from the latest handoff |
| `/checkpoint` | Mid-session drift and scope creep check |
| `/audit-context` | Analyze token overhead from CLAUDE.md, plugins, MCP servers |
| `/lean-claude-md [path]` | Trim CLAUDE.md to only lines that change behavior |
| `/context-tricks` | Guided compaction, /btw, checkpoints, @ references |

### memory — Memory Architecture

Three-tier memory: pointer index (always loaded, ~50 lines), topic files (loaded on demand), session transcripts (grep-searchable, never loaded whole). Every memory includes a `Last verified:` date. Recalled knowledge is always framed as "Previously noted (may be outdated)."

| Skill | Purpose |
|-------|---------|
| `/remember` | Store a decision, pattern, or insight to persistent memory |
| `/recall` | Search and retrieve stored memories |
| `/memory-index` | List, audit, and clean up stored memories |

### evaluator — Evaluation & Quality Gates

Implements the evaluator-optimizer pattern. Static analysis hooks run automatically on every PHP and JS/TS file write. The adversarial-reviewer agent does read-only code review with a skeptical eye — it can't modify code, only critique it.

| Skill | Purpose |
|-------|---------|
| `/challenge` | Critique your own work before presenting it |
| `/verify` | Evidence-based completion check before claiming done |
| `/devils-advocate <decision>` | Argue against a design decision to find holes |
| `/postmortem [bug]` | Structured bug autopsy: root cause, category, prevention |
| `/healthcheck [--quick\|--full]` | Run quality pipeline (auto-detects PHP and/or JS/TS) |
| `/gate-report` | Aggregate all quality warnings before committing |

### workflow — Orchestration

Connected daily development lifecycle from morning planning through weekly retrospective. Task routing based on Anthropic's agent patterns research — matches task complexity to the right workflow pattern.

| Skill | Purpose |
|-------|---------|
| `/morning` | Daily planning: review yesterday, check handoffs, prioritize today |
| `/eod` | End-of-day: capture progress, create daily log, trigger handoff |
| `/weekly` | Weekly retro: patterns, wins, blockers, tech debt |
| `/route <task>` | Pick the right workflow pattern for this task |
| `/explore <what>` | Subagent exploration without polluting main context |
| `/plan <task>` | Create implementation plan with files, changes, risks |
| `/implement` | Execute plan step-by-step with scope checks |

See [plugins/workflow/LIFECYCLE.md](plugins/workflow/LIFECYCLE.md) for the full lifecycle flow.

### agents — Multi-Agent Decomposition

Planner/Generator/Reviewer triad with tool-isolated capability boundaries. The planner can't modify code (read-only tools), the generator implements based on the planner's output, and the reviewer can't rubber-stamp by editing (read-only tools). Capability isolation prevents error propagation between phases.

| Skill | Purpose |
|-------|---------|
| `/dispatch` | Analyze task, recommend single-agent vs fan-out vs pipeline |
| `/fan-out` | Parallel batch processing with subagents |

| Agent | Tools | Purpose |
|-------|-------|---------|
| planner | Read, Glob, Grep, Bash | Read-only exploration and approach design |
| generator | Read, Write, Edit, Bash, Glob, Grep | Implementation based on planner output |
| reviewer | Read, Grep, Glob, Bash | Read-only critique and issue detection |

### reference — Power-User Tips

Reference skills for hidden Claude Code features. Knowledge you look up when needed. All `disable-model-invocation: true` — zero tokens until invoked.

| Skill | Purpose |
|-------|---------|
| `/ultrathink` | Guide to thinking modes and effort levels |
| `/unix-pipe` | Claude as CLI tool: headless mode, piping, output formats |
| `/parallel-power` | Multi-session patterns: worktrees, fan-out, writer/reviewer |

---

## Active Hooks

These fire automatically. No commands needed.

| Event | Plugin | What it does |
|-------|--------|-------------|
| Every message | behavioral-core | Re-anchors behavioral rules from `rules.d/` (modular, user-editable) |
| Every message | context-engine | 5-stage progressive context pressure warnings |
| Before Bash | behavioral-core | Blocks `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE` |
| Before any tool | behavioral-core | Reminds of active scope boundaries (if a scope exists) |
| Before `git commit` | evaluator | Reminds to run tests |
| After Write/Edit | behavioral-core | Nudges: "Does this change do ONLY what was asked?" |
| After reading >500 lines | context-engine | Warns to extract what you need before compaction |
| After writing .php | evaluator | Runs Larastan/PHPStan on the changed file |
| After writing .js/.ts | evaluator | Runs tsc --noEmit and ESLint on the changed file |
| After Bash/Grep | context-engine | Warns if tool output approaching 50K char truncation boundary |
| After Edit/Read | context-engine | Tracks edits per file; warns after 3 edits without re-reading |

---

## Usage Scenarios

### Starting your day

```
/morning
```

Reads yesterday's git log, checks for open handoffs and uncommitted changes, pulls CI status. Produces a prioritized plan. If you left a handoff from yesterday:

```
/resume
```

Picks up where you left off. Shows what was done, what's pending, any uncommitted changes.

Before diving into work, scope the first task:

```
/scope Add rate limiting to the /api/auth endpoint
```

Creates a scope document: which files change, which don't, what "done" looks like. The scope-reminder hook will gently remind you of boundaries throughout the session.

### Building a feature

Start by picking the right approach:

```
/route Add user notification preferences with email/push/sms channels
```

Claude recommends a pattern (e.g., "Orchestrator-Workers: break into independent channel handlers"). Then follow the phases:

```
/explore notification system and user preferences
```

Runs in an isolated subagent. Reads relevant files, reports patterns and dependencies without polluting your context.

```
/plan Add notification preferences
```

Creates a plan with exact files, changes per file, risks, and verification method. Edit with Ctrl+G if needed.

```
/implement
```

Executes the plan step-by-step. Checks scope after each change. Won't mark done without running verification.

```
/verify
```

Shows evidence: what changed, test output, edge case analysis. Either "VERIFIED" with proof or "UNVERIFIED" with what's needed.

### Long session management

After ~8 messages, context-engine warns about working memory shrinking. At ~15, it suggests compaction. At ~22, it recommends compacting. Check drift:

```
/checkpoint
```

Compares your work against the plan. Reports scope creep, suggests whether to continue, compact, or start fresh.

If the session is getting full but you're mid-task:

```
/compact preserve the notification preferences plan and test results
```

If you need to hand off to a fresh session:

```
/handoff notification-preferences
```

Generates a structured handoff document. Next session:

```
/resume
```

### Multi-agent pipeline

For a complex feature, use the planner/generator/reviewer pipeline:

```
/dispatch Add webhook retry system with exponential backoff
```

Recommends: "Pipeline (P/G/R) — architectural change touching 6+ files, medium-high risk." Then dispatch agents sequentially: planner explores and proposes, generator implements, reviewer challenges.

For batch operations across many files:

```
/fan-out
```

Dispatches parallel subagents (3-5 agents, each handling a batch of files) for the same operation.

### Before committing

The evaluator hooks already ran Larastan on every PHP file and tsc/ESLint on every JS/TS file you edited. Check the full picture:

```
/healthcheck --quick
```

Runs Pint + Larastan. Add `--full` to include the test suite.

```
/gate-report
```

Aggregates all warnings: static analysis issues, missing migration rollbacks, leftover `dd()` calls, new TODOs in the diff.

For important changes, challenge your own work:

```
/challenge
```

Runs in isolation. Asks: could this be simpler? What breaks? What's the weakest part? Would a staff engineer approve?

### Reviewing your discipline

After a long session, check how well Claude followed the rules:

```
/rules-audit
```

Scans for sycophancy, unnecessary apologies, scope creep, focus violations, filler language. Produces a behavioral score.

Check if your setup is lean:

```
/audit-context
```

Measures CLAUDE.md token weight, counts active plugins and MCP servers, identifies waste. Follow up with:

```
/lean-claude-md
```

Trims your CLAUDE.md to only lines that actually change Claude's behavior.

### Ending your day

```
/eod
```

Reviews today's commits and files changed. Creates a daily log. Suggests handoff if work is in progress.

```
/handoff auth-refactor
```

Captures state for tomorrow. On Friday:

```
/weekly
```

Reads the week's daily logs. Surfaces patterns, wins, blockers, and accumulated tech debt.

---

## Design Principles

**Agent = Model + Harness.** Research (Meta-Harness, 2025) shows the harness — not the model — is the primary lever for agent performance. Forge Studio structures the harness into composable layers.

**Hooks over instructions.** CLAUDE.md rules have ~80% compliance that degrades as context fills. Hooks fire deterministically at 100%. For non-negotiable behavior, use hooks.

**`exit 2` blocks, `exit 1` warns.** Hook exit codes control enforcement level. `exit 2` actually prevents execution (used by destructive command blocker).

**Zero cost until invoked.** All 30 skills use `disable-model-invocation: true`. They don't load into context until called. Installing all plugins adds near-zero overhead.

**Capability isolation.** Agents have tool-restricted boundaries. Read-only agents can't modify code. Write agents can't skip review. This prevents error propagation between phases.

**Progressive degradation.** Context pressure warnings escalate gradually, giving you time to compact or handoff before quality collapses.

**Filesystem as substrate.** Memory, session state, rules, and configuration all live in files. Files survive context compaction; your working memory does not.

**Subagent isolation.** Skills that read many files (`/explore`, `/challenge`, `/devils-advocate`) use `context: fork` to run in isolated subagents. Only summaries return to your main session.

---

## Customization

**Add/remove behavioral rules:** Edit files in `plugins/behavioral-core/hooks/rules.d/`. Rules are numbered for priority ordering (10-no-sycophancy, 20-no-filler, etc.).

**Adjust context pressure thresholds:** Edit `plugins/context-engine/hooks/track-context-pressure.sh`.

**Edit skill behavior:** Each SKILL.md is self-contained. Modify the instructions, add sections, or change the output format.

**Add your own skills:** Create `skills/{name}/SKILL.md` with YAML frontmatter in any plugin directory.

**Disable a hook:** Remove the entry from the plugin's `hooks/hooks.json`.

**Disable a plugin:** `/plugin disable {name}@forge-studio`

**Adjust the destructive command blocklist:** Edit `plugins/behavioral-core/hooks/block-destructive.sh` to add or remove patterns.

---

## Docs

- [Architecture](docs/architecture.md) — Harness design, 7 components, why hooks beat instructions, memory tiers
- [Workflow Lifecycle](plugins/workflow/LIFECYCLE.md) — Morning-to-weekly development cycle
- [Budget Window Warmup](docs/warmup.md) — Anchor your 5-hour token budget window to predictable hours
- [Settings Best Practices](docs/settings.md) — Recommended settings.json configuration, permission modes, deny rules

