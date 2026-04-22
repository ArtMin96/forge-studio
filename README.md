# Forge Studio

**Agent = Model + Harness.** Research shows changing only the harness produces a 6x performance gap ([Meta-Harness, 2026](docs/research.md)). Forge Studio implements harness principles as composable Claude Code plugins.

14 plugins. 47 skills. 51 hooks. 4 agents. 8 behavioral rules.

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
/plugin install rtk-optimizer@forge-studio       # Auto-installs rtk binary + registers global hook
/plugin install code-graph@forge-studio          # Auto-installs code-review-graph + registers MCP for Tree-sitter code graph
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
| **memory** | Three-tier memory: pointer index → topic files → searchable transcripts, version-aware updates, ledger audit | 0 | 4 |
| **evaluator** | Static analysis gates (PHP/JS/TS), adversarial review, verification, test nudge, self-evolution assessment | 8 | 8 |
| **workflow** | Hook-driven agentic orchestrator: auto-routing (shell/hybrid/LLM), sprint-contract enforcement, TDD loop, handoff nudges, self-evolution loop (propose→assess→commit→rollback) | 5 | 9 |
| **agents** | Multi-agent decomposition: planner/generator/reviewer triad with tool-isolated capability boundaries, worktree-team orchestration, directory-ownership + output-schema checks | 3 | 5 |
| **reference** | Hidden Claude Code features: thinking modes, parallel patterns, CLI piping | 0 | 3 |
| **traces** | JSONL execution traces, compiled views, failure mining, harness evolution | 5 | 4 |
| **diagnostics** | Documentation drift (`/entropy-scan`), pre-commit mechanical correctness (`/validate-marketplace`), project docs QA (`/docs-maintenance`) | 0 | 3 |
| **caveman** | Always-on compressed output (~65% token savings). Survives compaction. | 2 | 1 |
| **token-efficiency** | Duplicate read detection, session token audit | 1 | 1 |
| **research-gate** | Blocks Edit/Write on unread files + exploration depth warnings | 4 | 0 |
| **rtk-optimizer** | Auto-installs [rtk-ai/rtk](https://github.com/rtk-ai/rtk) on first session and runs `rtk init -g`. 60-90% token reduction on shell commands. Opt-out: `FORGE_RTK_DISABLED=1`. | 1 | 0 |
| **code-graph** | Auto-installs [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph). Registers a Tree-sitter MCP graph per repo so Claude Code queries structural context instead of re-reading files. Claude Code only. Opt-out: `FORGE_CODE_GRAPH_DISABLED=1`. | 2 | 0 |

### Key Skills

| Skill | Plugin | What it does |
|-------|--------|-------------|
| `/orchestrate [pattern]` | workflow | Manually dispatch agentic pattern (single/pipeline/fan-out/tdd/auto) |
| `/tdd-loop <desc>` | workflow | RED→GREEN→REFACTOR with real-command completion gates |
| `/status` | workflow | Snapshot of plan, handoff, traces, context pressure, router stats |
| `/verify` | evaluator | Evidence-based completion check before claiming done |
| `/scope <task>` | behavioral-core | Define task boundaries and acceptance criteria |
| `/handoff [topic]` | context-engine | Generate session transfer document |
| `/resume` | context-engine | Pick up from latest handoff |
| `/dispatch` | agents | Analyze task, recommend single-agent vs fan-out vs pipeline |
| `/trace-compile` | traces | Compile raw JSONL traces into summary and error views |
| `/trace-evolve` | traces | Mine failure patterns, propose harness improvements |
| `/healthcheck` | evaluator | Run quality pipeline (Pint + Larastan + optional tests) |
| `/audit-context` | context-engine | Analyze token overhead from CLAUDE.md, plugins, MCP servers |
| `/entropy-scan` | diagnostics | Full 6-check codebase health scan |
| `/validate-marketplace` | diagnostics | Pre-commit validator: marketplace JSON, SKILL.md schema (2026 fields), hook exec, agent preload coherence, skill size |
| `/docs-maintenance [mode]` | diagnostics | Project docs QA: audit freshness, validate links/images, enforce style, optimize structure. Modes: `--audit`, `--validate`, `--optimize`, `--update`, `--comprehensive` |
| `/lineage-audit` | memory | Audit `.claude/lineage/ledger.jsonl` for protocol invariants |
| `/worktree-team <roles>` | agents | Bootstrap N parallel agents in git worktrees with role-scoped CLAUDE.md |
| `/evolve` | workflow | Self-evolution cycle: propose → assess → user approval → commit (Autogenesis protocol) |
| `/assess-proposal` | evaluator | Adversarial 4-criteria review of a self-evolution proposal |
| `/commit-proposal` | workflow | Apply an approved proposal; snapshot prior version to `.claude/lineage/` |
| `/rollback` | workflow | Reverse a commit; restore prior snapshot; logged append-only |
| `/reflect` | workflow | Three-line Reflect-Memorize insight after TDD loop → memory |
| `/router-tune` | workflow | Analyze router miss-fires, emit threshold/regex proposals |

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
| SessionStart | workflow | Surface latest handoff + unchecked plan items (agentic workflow bootstrap) |
| SessionStart | rtk-optimizer | First session: install `rtk` binary + run `rtk init -g`. Subsequent sessions: no-op. |
| SessionStart | code-graph | Install `code-review-graph` and register its MCP server for the current repo on first run. Subsequent sessions: no-op. |
| PreCompact | context-engine | Guard: block compaction when uncommitted work has no handoff or tasks are in-progress |
| PreCompact | context-engine | Save scope, plan, handoff, git state to recovery file |
| PreCompact | workflow | Advisory nudge to run `/handoff` before auto-compaction |
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
| UserPromptSubmit | workflow | Agentic router: classify prompt (shell/hybrid/LLM), nudge pattern |

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
| PostToolUse:Bash | code-graph | Refresh the graph after `git commit`/`merge`/`rebase`/`pull`/`checkout`/`reset`/`cherry-pick`. |
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
| SubagentStop | agents | Warn if generator finished without producing artifacts declared in plan Contract/Output Schema |
| PreToolUse:Edit\|Write | agents | Directory-ownership guard for worktree-team (opt-in: `FORGE_DIRECTORY_OWNERSHIP=1`) |
| SubagentStop | workflow | Nudge next phase in planner→generator→reviewer→/verify chain |

### Turn Completion

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| Stop | workflow | turn-gate.sh | Every N turns: remind about unchecked plan items and context pressure |
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
- **Disable rtk auto-install**: Set `FORGE_RTK_DISABLED` to `"1"` (see [rtk-optimizer docs](docs/rtk-optimizer.md)).
- **Disable code-graph auto-install**: Set `FORGE_CODE_GRAPH_DISABLED` to `"1"` (see [code-graph docs](docs/code-graph.md)).
- **Enable directory-ownership guard**: Set `FORGE_DIRECTORY_OWNERSHIP` to `"1"` (activates only inside a worktree-team session with an `active-roles.json` registry).
- **Disable a plugin**: `/plugin disable {name}@forge-studio`

---

## Docs

| Doc | Purpose |
|-----|---------|
| [Architecture](docs/architecture.md) | Design rationale, 8-component model, hook mechanics |
| [2026 Improvement Report](docs/research/2026-marketplace-improvement-report.md) | Marketplace gap analysis + recommendations synthesized from Claude Code research |
| [Research](docs/research.md) | Research papers and findings backing each design decision |
| [Harness Spec](HARNESS_SPEC.md) | Mechanical invariants, architectural primitives, protocols |
| [Settings](docs/settings.md) | settings.json best practices |
| [Token Optimization](docs/token-optimization.md) | Where tokens go and how to reduce spend |
| [Execution Traces](docs/traces.md) | Trace collection, analysis, harness evolution |
| [Research Gate](docs/research-gate.md) | Read-before-edit enforcement design and data |
| [RTK Optimizer](docs/rtk-optimizer.md) | Auto-bundled rtk-ai/rtk: bootstrap flow, verification, uninstall |
| [Code Graph](docs/code-graph.md) | Auto-bundled tirth8205/code-review-graph: MCP registration, Tree-sitter graph, update cadence |
| [Agentic Workflow](docs/agentic-workflow.md) | Workflow plugin usage, configuration, skills, worked examples |
| [Workflow Lifecycle](plugins/workflow/LIFECYCLE.md) | Event → hook → composed-plugin map |
