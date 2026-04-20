# Forge Studio

**Agent = Model + Harness.** Research shows changing only the harness produces a 6x performance gap ([Meta-Harness, 2026](docs/research.md)). Forge Studio implements harness principles as composable Claude Code plugins.

12 plugins. 41 skills. 41 hooks. 4 agents. 8 behavioral rules.

---

## Install

```bash
# Add the marketplace
/plugin marketplace add ArtMin96/forge-studio

# Install by layer — pick what you need
/plugin install behavioral-core@forge-studio    # Behavioral steering (start here)
/plugin install context-engine@forge-studio      # Context window management
/plugin install memory@forge-studio              # Cross-session recall
/plugin install evaluator@forge-studio           # Quality gates & review
/plugin install workflow@forge-studio            # Orchestration patterns
/plugin install agents@forge-studio              # Multi-agent decomposition
/plugin install reference@forge-studio           # Power-user tips
/plugin install traces@forge-studio              # Execution trace collection
/plugin install diagnostics@forge-studio         # Codebase health scanning
/plugin install caveman@forge-studio             # Token-optimized output
/plugin install token-efficiency@forge-studio    # Duplicate read detection
/plugin install research-gate@forge-studio       # Read-before-edit enforcement
```

Start a new session after installing for plugins to load.

### Templates

```bash
cp templates/CLAUDE.md ./CLAUDE.md       # Lean project instructions
cp templates/settings.json ~/.claude/settings.json  # Power-user settings
```

See [docs/settings.md](docs/settings.md) for settings documentation.

---

## Plugins

| Plugin | Purpose | Hooks | Skills |
|--------|---------|-------|--------|
| **behavioral-core** | Behavioral steering via modular `rules.d/` rules, destructive command blocking, scope discipline | 5 | 3 |
| **context-engine** | Context management: progressive pressure, session handoffs, edit safety, environment bootstrap, compaction recovery, task tracking, failure escalation | 15 | 6 |
| **memory** | Three-tier memory: pointer index → topic files → searchable transcripts | 0 | 3 |
| **evaluator** | Static analysis gates (PHP/JS/TS), adversarial review, verification, test nudge, test output filtering | 8 | 7 |
| **workflow** | Daily lifecycle (morning → eod → weekly), task routing, explore/plan/implement cycle | 0 | 8 |
| **agents** | Multi-agent decomposition: planner/generator/reviewer triad with tool-isolated capability boundaries | 1 | 4 |
| **reference** | Hidden Claude Code features: thinking modes, parallel patterns, CLI piping | 0 | 3 |
| **traces** | JSONL execution traces, compiled views, failure mining, harness evolution | 5 | 4 |
| **diagnostics** | Documentation drift, registration gaps, convention violations, stale memory | 0 | 1 |
| **caveman** | Always-on compressed output (~65% token savings). Survives compaction. | 2 | 1 |
| **token-efficiency** | Duplicate read detection, session token audit | 1 | 1 |
| **research-gate** | Blocks Edit/Write on unread files + exploration depth warnings | 4 | 0 |

### Key Skills

| Skill | Plugin | What it does |
|-------|--------|-------------|
| `/morning` | workflow | Daily planning: review yesterday, check handoffs, prioritize today |
| `/plan <task>` | workflow | Create implementation plan with files, changes, risks |
| `/implement` | workflow | Execute plan step-by-step with scope checks |
| `/verify` | evaluator | Evidence-based completion check before claiming done |
| `/scope <task>` | behavioral-core | Define task boundaries and acceptance criteria |
| `/handoff [topic]` | context-engine | Generate session transfer document |
| `/resume` | context-engine | Pick up from latest handoff |
| `/explore <what>` | workflow | Subagent exploration without polluting main context |
| `/dispatch` | agents | Analyze task, recommend single-agent vs fan-out vs pipeline |
| `/trace-compile` | traces | Compile raw JSONL traces into summary and error views |
| `/trace-evolve` | traces | Mine failure patterns, propose harness improvements |
| `/healthcheck` | evaluator | Run quality pipeline (Pint + Larastan + optional tests) |
| `/audit-context` | context-engine | Analyze token overhead from CLAUDE.md, plugins, MCP servers |
| `/entropy-scan` | diagnostics | Full 6-check codebase health scan |

### Agents

| Agent | Plugin | Tools | Role |
|-------|--------|-------|------|
| planner | agents | Read, Glob, Grep, Bash | Read-only exploration + design |
| generator | agents | Read, Write, Edit, Bash, Glob, Grep | Implementation |
| reviewer | agents | Read, Grep, Glob, Bash | Read-only critique |
| adversarial-reviewer | evaluator | Read, Grep, Glob | Skeptical security/edge-case review |

---

## Active Hooks

Hooks fire automatically. No commands needed.

### Session Lifecycle
| Event | Plugin | What it does |
|-------|--------|-------------|
| SessionStart | context-engine | Environment snapshot: OS, memory, languages, tools, git state |
| SessionStart | context-engine | MCP server instruction token monitoring |
| SessionStart | caveman | Load compressed communication rules |
| SessionStart | behavioral-core | One-time check for unsafe output styles |
| PreCompact | context-engine | Guard: block compaction when uncommitted work has no handoff or tasks are in-progress |
| PreCompact | context-engine | Save scope, plan, handoff, git state to recovery file |
| PostCompact | context-engine | Re-inject scope, plan, tasks, modified files from recovery |
| PostCompact | caveman | Re-inject compressed communication rules |
| SessionEnd | traces | Write session summary to trace file |

### Every Message
| Event | Plugin | What it does |
|-------|--------|-------------|
| UserPromptSubmit | behavioral-core | Re-anchor all behavioral rules from `rules.d/` |
| UserPromptSubmit | context-engine | 5-stage progressive context pressure warnings |
| UserPromptSubmit | context-engine | Track system-reminder injection patterns |
| UserPromptSubmit | context-engine | Remind about incomplete tasks |

### Before Tool Use
| Event | Plugin | What it does |
|-------|--------|-------------|
| PreToolUse:Bash | behavioral-core | Block destructive commands (`rm -rf`, `git push --force`, etc.) |
| PreToolUse:Edit\|Write | behavioral-core | Warn when editing files outside active scope |
| PreToolUse:Edit\|Write | research-gate | **Block** edit/write if file not Read in session (exit 2) |
| PreToolUse:Edit\|Write | research-gate | Warn if insufficient exploration before first edit |
| PreToolUse:Bash | evaluator | Evaluation gate: warn if plan exists but `/verify` not run |

### After Tool Use
| Event | Plugin | What it does |
|-------|--------|-------------|
| PostToolUse:Write\|Edit | behavioral-core | "Does this change do ONLY what was asked?" |
| PostToolUse:Read | context-engine | Warn on files >500 lines |
| PostToolUse:Bash\|Grep | context-engine | Warn on large output or near-truncation |
| PostToolUse:Edit\|Read | context-engine | Track edits per file; warn after 3 without re-reading |
| PostToolUse:Edit | context-engine | Detect thrashing (5+ edits to same file, oscillating regions) |
| PostToolUse:EnterPlanMode | context-engine | Inject plugin-aware plan mode guidance |
| PostToolUse:Write\|Edit (.php) | evaluator | Run PHPStan on changed file |
| PostToolUse:Write\|Edit (.js/.ts) | evaluator | Run tsc + ESLint on changed file |
| PostToolUse:Edit\|Write | evaluator | Nudge to run tests after every 3rd edit |
| PostToolUse:Bash | evaluator | Reset test-nudge counter when tests detected |
| PostToolUse:Write\|Edit | traces | Log file change to session trace |
| PostToolUse:Bash | traces | Log command, exit code, output to session trace |
| PostToolUse:Read | research-gate | Record file read for edit gate |
| PostToolUse:Read\|Grep\|Glob | research-gate | Track exploration depth |
| PostToolUse:Read | token-efficiency | Warn on duplicate reads |
| PostToolUse:Bash (.test) | evaluator | Backpressure: replace verbose passing test output with summary |
| PostToolUse:* | context-engine | Reset consecutive failure counter on success |
| PostToolUseFailure:* | traces | Log tool failures to session trace |
| PostToolUseFailure:* | context-engine | Warn after 3 consecutive tool failures |
| TaskCreated | context-engine | Log task for progress guardian |
| StopFailure | traces | Log API errors and rate limits to session trace |

### Agent Lifecycle
| Event | Plugin | What it does |
|-------|--------|-------------|
| SubagentStop | agents | Warn if sprint contract criteria not verified by reviewer |

### Turn Completion

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| TaskCompleted | evaluator | task-completion-gate.sh | Warn if task marked done without verification evidence |

---

## Customization

- **Behavioral rules**: Add/remove files in `plugins/behavioral-core/hooks/rules.d/`. Numbered for priority.
- **Context thresholds**: Set `FORGE_CONTEXT_STAGE1`-`STAGE5` in settings.json env (message counts) or `FORGE_CONTEXT_PCT1`-`PCT5` (percentages).
- **Exploration depth**: Set `FORGE_EXPLORE_DEPTH` (default 6, IDE-Bench recommends 8+).
- **Test nudge interval**: Set `FORGE_TEST_NUDGE_INTERVAL` (default 3 edits).
- **Large file warning**: Set `FORGE_LARGE_FILE_LINES` (default 500).
- **Disable traces**: Set `FORGE_TRACES_ENABLED` to `"0"`.
- **Disable evaluation gate**: Set `FORGE_EVALUATION_GATE` to `"0"`.
- **Disable research gate**: Set `FORGE_RESEARCH_GATE` to `"0"`.
- **Self-review interval**: Set `FORGE_SELF_REVIEW_INTERVAL` (default 3 edits).
- **Failure threshold**: Set `FORGE_FAILURE_THRESHOLD` (default 3 consecutive failures).
- **Disable a plugin**: `/plugin disable {name}@forge-studio`

---

## Docs

| Doc | Purpose |
|-----|---------|
| [Architecture](docs/architecture.md) | Design rationale, 7-component model, hook mechanics |
| [Research](docs/research.md) | Research papers and findings backing each design decision |
| [Harness Spec](HARNESS_SPEC.md) | Mechanical invariants, architectural primitives, protocols |
| [Settings](docs/settings.md) | settings.json best practices |
| [Token Optimization](docs/token-optimization.md) | Where tokens go and how to reduce spend |
| [Execution Traces](docs/traces.md) | Trace collection, analysis, harness evolution |
| [Research Gate](docs/research-gate.md) | Read-before-edit enforcement design and data |
| [Workflow Lifecycle](plugins/workflow/LIFECYCLE.md) | Morning-to-weekly development cycle |
