# Forge Studio Architecture

Design rationale, component model, hook mechanics. For research citations, see [research.md](research.md). For mechanical invariants, see [HARNESS_SPEC.md](../HARNESS_SPEC.md).

---

## The 7 Harness Components

**Agent = Model + Harness.** Changing only the harness produces a 6x performance gap. These are the 7 levers:

| # | Component | What It Controls | Plugin |
|---|-----------|-----------------|--------|
| 1 | System Prompts | Base behavior and personality | `behavioral-core` |
| 2 | Tool System | What actions the agent can take | `agents` (tool isolation) |
| 3 | Permission System | What the agent is allowed to do | `behavioral-core` (block-destructive) |
| 4 | Context Management | What the model sees each turn | `context-engine` |
| 5 | Memory Architecture | What persists across sessions | `memory` |
| 6 | Multi-Agent Decomposition | How work is split across agents | `agents` |
| 7 | Behavioral Steering | Ongoing course correction | `behavioral-core` (hooks) |

Cross-cutting plugins: `evaluator`, `workflow`, `reference`, `traces`, `diagnostics`, `caveman`, `token-efficiency`, `research-gate`.

---

## Three-Layer Model

```
┌─────────────────────────────────────┐
│            User / IDE               │
├─────────────────────────────────────┤
│         Harness (Forge Studio)      │
│                                     │
│  ┌─ Discipline ──┐ ┌─ Awareness ──┐│
│  │ behavioral-   │ │ context-     ││
│  │ core          │ │ engine       ││
│  │ evaluator     │ │ memory       ││
│  │ research-gate │ │ traces       ││
│  │ token-        │ │ diagnostics  ││
│  │ efficiency    │ │              ││
│  └───────────────┘ └──────────────┘│
│  ┌─ Action ──────┐ ┌─ Style ─────┐│
│  │ workflow      │ │ caveman     ││
│  │ agents        │ │ reference   ││
│  └───────────────┘ └─────────────┘│
├─────────────────────────────────────┤
│            Claude Model             │
└─────────────────────────────────────┘
```

---

## Hook Event Reference

40 hooks across 8 plugins. Hooks fire automatically on events — no commands needed.

### Session Lifecycle

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| SessionStart | context-engine | env-bootstrap.sh | OS, memory, languages, tools, git state snapshot |
| SessionStart | context-engine | mcp-instruction-monitor.sh | MCP server instruction token monitoring |
| SessionStart | caveman | caveman-init.sh | Load compressed communication rules |
| SessionStart | behavioral-core | output-style-check.sh | One-time check for unsafe output styles |
| PreCompact | context-engine | pre-compact-guard.sh | Block compaction when uncommitted work has no handoff or tasks in-progress |
| PreCompact | context-engine | pre-compact.sh | Save scope, plan, handoff, git state, tasks to recovery file |
| PostCompact | context-engine | post-compact.sh | Re-inject scope, plan, tasks, modified files from recovery |
| PostCompact | caveman | caveman-restore.sh | Re-inject compressed communication rules |
| SessionEnd | traces | session-summary.sh | Write session summary to trace file |

### Every User Message (UserPromptSubmit)

| Plugin | Hook | What It Does |
|--------|------|-------------|
| behavioral-core | behavioral-anchor.sh | Re-anchor all behavioral rules from `rules.d/` |
| context-engine | track-context-pressure.sh | 5-stage progressive context pressure warnings |
| context-engine | track-system-reminders.sh | Track system-reminder injection patterns |
| context-engine | task-guardian.sh | Remind about incomplete tasks |

### Before Tool Use (PreToolUse)

| Matcher | Plugin | Hook | What It Does |
|---------|--------|------|-------------|
| Bash | behavioral-core | block-destructive.sh | Block `rm -rf`, `git push --force`, etc. |
| Edit\|Write | behavioral-core | scope-guard.sh | Warn when editing files outside active scope |
| Edit\|Write | research-gate | require-read-before-edit.sh | **Block** edit/write if file not Read in session (exit 2) |
| Edit\|Write | research-gate | exploration-depth-gate.sh | Warn if insufficient exploration before first edit |
| Bash | evaluator | pre-commit-gate.sh | Warn if plan exists but `/verify` not run |
| Read | token-efficiency | track-duplicate-reads.sh | Warn on duplicate reads |

### After Tool Use (PostToolUse)

| Matcher | Plugin | Hook | What It Does |
|---------|--------|------|-------------|
| Write\|Edit | behavioral-core | self-review-nudge.sh | "Does this change do ONLY what was asked?" |
| Read | context-engine | check-large-file.sh | Warn on files >500 lines |
| Bash\|Grep | context-engine | warn-tool-truncation.sh | Warn on large output or near-truncation |
| Edit\|Read | context-engine | track-edits.sh | Track edits per file; warn after 3 without re-reading |
| Edit | context-engine | detect-thrashing.sh | Detect thrashing (5+ edits same file, oscillating regions) |
| EnterPlanMode | context-engine | plan-mode-enter.sh | Inject plugin-aware plan mode guidance |
| Write\|Edit (.php) | evaluator | php-static-analysis.sh | Run PHPStan on changed file |
| Write\|Edit (.js/.ts) | evaluator | js-static-analysis.sh | Run tsc + ESLint on changed file |
| Edit\|Write | evaluator | test-nudge.sh | Nudge to run tests after every 3rd edit |
| Bash | evaluator | test-nudge-reset.sh | Reset test-nudge counter when tests detected |
| Write\|Edit | traces | collect-file-trace.sh | Log file change to session trace |
| Bash | traces | collect-bash-trace.sh | Log command, exit code, output to session trace |
| Read | research-gate | track-file-reads.sh | Record file read for edit gate |
| Read\|Grep\|Glob | research-gate | track-exploration.sh | Track exploration depth |

### Task Lifecycle

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| TaskCreated | context-engine | task-guardian-log.sh | Log task for progress guardian |

### Turn Completion & Task Events

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| TaskCompleted | evaluator | task-completion-gate.sh | Warn if task marked done without verification evidence |

---

## Background Monitors (v2.1.105)

Monitors are persistent background processes declared in a plugin manifest. Unlike hooks (event-driven, fire per action), monitors are long-running watchers that emit notifications via stdout.

| Aspect | Hooks | Monitors |
|--------|-------|----------|
| Trigger | Lifecycle events (PreToolUse, SessionStart, etc.) | Stream-based — each stdout line is a notification |
| Duration | Fire once per event, then exit | Run for session lifetime or until stopped |
| Blocking | Can block actions (exit 2) | Non-blocking background only |
| Activation | Event-driven, automatic | Auto-arm at session start or skill invoke |

### Manifest Format

Declared via a top-level `monitors` key in the plugin manifest:

```json
{
  "hooks": { ... },
  "monitors": [
    {
      "description": "Watch for external file changes",
      "command": "inotifywait -m -e modify src/",
      "timeout_ms": 3600000,
      "persistent": true
    }
  ]
}
```

### When to Use Monitors vs Hooks

| Use Case | Mechanism | Why |
|----------|-----------|-----|
| React to Claude's actions | Hooks | Hooks fire at decision points |
| Watch external processes (builds, CI, logs) | Monitors | Long-running, stream-based |
| Enforce rules before tool execution | Hooks (PreToolUse) | Monitors can't block |
| Detect external file modifications | Monitors | Persistent filesystem watching |

### Forge Studio Status

Forge Studio currently uses hooks for all event-driven behavior. Monitors are documented here for plugins that need persistent background watching — e.g., watching for external file changes, monitoring CI status, or tracking error rates in trace files.

---

## Hook Handler Types

Claude Code supports four hook handler types. Forge Studio uses `command` type for all hooks.

| Type | Execution | Blocking | Use Case |
|------|-----------|----------|----------|
| `command` | Shell script | Yes (exit 2) | Deterministic checks, file tracking, linting |
| `prompt` | LLM evaluation | No | Semantic analysis at decision points |
| `agent` | Agent delegation | No | Complex evaluation requiring multi-step reasoning |
| `http` | Webhook POST | No | External integrations, audit logging |

Forge Studio uses `command` hooks exclusively — deterministic, fast, cheap. The `prompt` and `agent` types enable inferential hooks but cost tokens on every firing. Reserve these for periodic deep analysis, not per-tool checks.

---

## Why Hooks Beat Instructions

| Mechanism | Compliance | Why |
|-----------|-----------|-----|
| CLAUDE.md instructions | ~70% | Diluted over long conversations as attention drifts |
| Hooks (event-driven) | ~100% | Re-injected at decision points; model can't "forget" |

Forge Studio uses hooks for enforcement, skills for guidance. Anything that must always happen goes in a hook. Anything opt-in goes in a skill.

---

## Behavioral Rules (`rules.d/`)

8 rules in `plugins/behavioral-core/hooks/rules.d/`. Each `.txt` file = one behavioral rule. Re-injected every message via `behavioral-anchor.sh`.

| # | Rule | Purpose |
|---|------|---------|
| 10 | tone | No sycophancy, no filler, lead with substance |
| 25 | brevity | 25 words between tools, 100 word responses |
| 30 | intellectual-honesty | Challenge own work, admit uncertainty |
| 50 | faithful-reporting | Report outcomes accurately, no false claims |
| 60 | minimal-changes | Fix the bug only, no scope creep |
| 70 | follow-plans | Execute approved plans exactly |
| 80 | no-redundant-exploration | Reasonable defaults, vary search terms |
| 90 | single-variable-changes | Change one thing, verify, proceed |

**Adding rules**: Drop a `.txt` in the directory. Picked up on next message. Rename to `.txt.disabled` to disable.

**Token cost**: ~200-300 tokens/message for the full set. The price of ~100% compliance.

---

## Feedforward vs Feedback Controls

| Type | Execution | Examples | When |
|------|-----------|----------|------|
| Feedforward (Guide) | Computational | CLAUDE.md, .editorconfig, skills | Before action |
| Feedforward (Guide) | Inferential | Plans, architecture specs | Before action |
| Feedback (Sensor) | Computational | Linters, hooks, tests | After action |
| Feedback (Sensor) | Inferential | Adversarial reviewer, code review | After action |

**Strategy**: Lean on computational controls (cheap, deterministic) for continuous feedback. Reserve inferential controls (expensive, non-deterministic) for periodic deeper analysis.

---

## Agent Tool Boundaries

Capability isolation prevents error propagation between phases:

| Agent | Tools | Role | Plugin |
|-------|-------|------|--------|
| planner | Read, Glob, Grep, Bash | Read-only exploration + design | agents |
| generator | Read, Write, Edit, Bash, Glob, Grep | Implementation | agents |
| reviewer | Read, Grep, Glob, Bash | Read-only critique | agents |
| adversarial-reviewer | Read, Grep, Glob | Skeptical security/edge-case review | evaluator |

Self-evaluation is unreliable — agents confidently praise their own work. Separate agents with separate tool sets prevent this.

---

## Progressive Context Management

5-stage warnings as context fills:

| Stage | Action |
|-------|--------|
| Notice (~50%) | Re-read files before editing |
| Moderate (~65%) | Consider /compact |
| Elevated (~75%) | Recommend compacting now |
| High (~85%) | Strongly recommend /handoff |
| Critical (~92%) | /handoff now or risk incoherent output |

Configurable via `FORGE_CONTEXT_STAGE1`-`STAGE5` (message counts) or `FORGE_CONTEXT_PCT1`-`PCT5` (percentages).

---

## Context Preservation Across Compaction

`PreCompact` saves, `PostCompact` restores:
- Active scope and plan
- Handoff state
- Git branch and uncommitted files
- Active task list (from task guardian)
- Files modified in session (from trace data)

---

## Three-Tier Memory

| Tier | Storage | Loaded | Size |
|------|---------|--------|------|
| 1: Pointers | `.claude/memory/index.md` | Always | ~50 lines |
| 2: Topics | `.claude/memory/topics/*.md` | On demand | ~50 lines each |
| 3: Transcripts | Session files | Grep only | Unbounded |

Memory is hints, not ground truth. Every recalled memory includes a `Last verified:` date.

---

## Execution Traces

JSONL traces collected per session:
- **PostToolUse:Bash** — command, exit code, output preview
- **PostToolUse:Write|Edit** — file path and change type
- **SessionEnd** — session summary

Traces stored in `~/.claude/traces/`. Analyzable via `/trace-compile` (structured views) and `/trace-evolve` (failure mining + harness improvement proposals).

---

## Exploration Depth Enforcement

Two-layer enforcement preventing premature editing:

| Layer | Hook | Behavior | Severity |
|-------|------|----------|----------|
| Read gate | require-read-before-edit.sh | Block edit/write if file not Read in session | **Block** (exit 2) |
| Depth gate | exploration-depth-gate.sh | Warn if total exploratory calls < threshold | Warning (exit 1) |

Default threshold: 6 exploratory calls (Read/Grep/Glob). Configurable via `FORGE_EXPLORE_DEPTH`.

---

## Prompt Cache Architecture

| Segment | Cache Scope | Content |
|---------|------------|---------|
| Before boundary | Global (cross-user, 1-hour TTL) | Static instructions (~3,500 tokens) |
| After boundary | Ephemeral (session-specific) | Dynamic: memory, env, MCP instructions |

**What busts the cache**: MCP server changes, CLAUDE.md edits, git state changes.

**Hook outputs inject via `<system-reminder>` tags** — after the boundary, so they don't bust the static cache.

---

## Design Principles

- **Zero-cost until invoked**: All skills use `disable-model-invocation: true`
- **Hooks for enforcement, skills for guidance**: Hooks are mandatory (fire on events). Skills are opt-in.
- **Fork for read-only**: Expensive analysis skills use `context: fork` to avoid polluting main conversation
- **Exit codes as signals**: 0 = info, 1 = warning, 2 = block (PreToolUse, PreCompact)
- **Filesystem as substrate**: Memory, session state, configuration all live in files — they survive context compaction
- **Prefer additive changes**: Add new hooks/skills rather than rewriting existing ones
- **Mechanical invariants over conventions**: Rules that can be validated mechanically should be (see [HARNESS_SPEC.md](../HARNESS_SPEC.md))
- **Silent on success, verbose on failure**: Hooks produce no output when conditions are normal
- **Single-variable changes**: When debugging or optimizing, change one thing at a time and verify
- **Persistent session state**: Use `${CLAUDE_PLUGIN_DATA}` for state that must survive reconnects

---

## Skill Compaction Lifecycle

Invoked skills survive context compaction with the first 5,000 tokens per skill. All invoked skills share a combined budget of 25,000 tokens after compaction. Most recently invoked skills get priority; older skills may be dropped entirely.

| Aspect | Behavior |
|--------|----------|
| Per-skill cap | First 5,000 tokens preserved |
| Shared budget | 25,000 tokens across all invoked skills |
| Priority | Most recently invoked wins |
| Dropped skills | Older skills may be fully removed if budget exhausted |
| Re-invocation | Re-invoke a skill after compaction to restore full content |

**Design implication**: Keep Forge Studio skills under 5,000 tokens. Skills exceeding this are truncated after compaction and may lose critical instructions.

---

## Glossary

| Term | Definition |
|------|-----------|
| Harness | Everything in an AI agent except the model — prompts, hooks, memory, tools, context management |
| System-reminder | `<system-reminder>` tag injected by hooks. Model treats these as authoritative context |
| Hook | Shell script firing on events. Outputs injected as system-reminders |
| Exit codes | 0 = info, 1 = warning, 2 = block (PreToolUse, PreCompact) |
| Context compaction | Claude Code compresses older messages when context fills. Information may be lost |
| JSONL | JSON Lines — one JSON object per line. Used for execution traces |
| Policy kernel | External enforcement of action classification (allow/deny/defer) |
| Context firewall | Sub-agent isolation preventing intermediate results from polluting parent |
| Sprint contract | Negotiated done-criteria between planner and evaluator before execution |
