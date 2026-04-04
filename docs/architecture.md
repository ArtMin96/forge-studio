# Forge Studio Architecture

## Core Thesis

```
Agent = Model + Harness
```

The **harness** is everything in an AI agent except the model: the code that determines what to store, retrieve, and present to the model at each turn. Research shows that changing only the harness — with the same underlying model — can produce a **6x performance gap** (Meta-Harness, 2026).

Forge Studio implements harness principles as composable Claude Code plugins.

## The 7 Harness Components

| # | Component | What It Controls | Forge Studio Plugin |
|---|-----------|-----------------|---------------------|
| 1 | System Prompts | Base behavior and personality | `behavioral-core` |
| 2 | Tool System | What actions the agent can take | `agents` (tool isolation) |
| 3 | Permission System | What the agent is allowed to do | `behavioral-core` (block-destructive) |
| 4 | Context Management | What the model sees each turn | `context-engine` |
| 5 | Memory Architecture | What persists across sessions | `memory` |
| 6 | Multi-Agent Decomposition | How work is split across agents | `agents` |
| 7 | Behavioral Steering | Ongoing course correction | `behavioral-core` (hooks) |

Cross-cutting: `evaluator` (quality gates), `workflow` (orchestration), `reference` (advanced patterns), `traces` (execution diagnostics).

## Three-Layer Model

```
┌─────────────────────────────────────┐
│            User / IDE               │
├─────────────────────────────────────┤
│         Harness (Forge Studio)      │
│  ┌───────────┐  ┌────────────────┐  │
│  │ Behavioral│  │   Context      │  │
│  │ Steering  │  │   Engine       │  │
│  ├───────────┤  ├────────────────┤  │
│  │ Evaluator │  │   Memory       │  │
│  ├───────────┤  ├────────────────┤  │
│  │ Workflow  │  │   Agents       │  │
│  ├───────────┤  ├────────────────┤  │
│  │ Reference │  │                │  │
│  └───────────┘  └────────────────┘  │
├─────────────────────────────────────┤
│            Claude Model             │
└─────────────────────────────────────┘
```

## Why Hooks Beat Instructions

System prompt instructions achieve ~80% compliance. They get diluted in long conversations as the model's attention drifts.

Hooks achieve ~100% compliance because they're **event-driven** — they fire at decision points (every user message, every tool use) and inject fresh reminders directly into the context. The model can't "forget" a hook because it's re-injected each time.

Forge Studio uses hooks for:
- **Behavioral anchoring** (`UserPromptSubmit`): Re-inject behavioral rules every message
- **Destructive command blocking** (`PreToolUse:Bash`): Intercept dangerous commands before execution
- **Quality gates** (`PostToolUse:Write|Edit`): Run static analysis after every code change
- **Context pressure** (`UserPromptSubmit`): Track and warn about context window exhaustion
- **Edit safety** (`PostToolUse:Edit|Read`): Track file reads/edits to detect stale-context edits

## Behavioral Rules (`rules.d/`)

The `behavioral-core` plugin uses a modular rule system at `plugins/behavioral-core/hooks/rules.d/`. Each `.txt` file is a single behavioral rule — one line of instruction.

### How it works

```
User sends message
  → UserPromptSubmit event fires
    → behavioral-anchor.sh runs
      → reads every *.txt file in rules.d/ (sorted by filename)
        → outputs all rules as a system-reminder
          → model sees "BEHAVIORAL RULES (enforced every message):" + bullet list
```

The rules are re-injected on **every user message**. This is the core mechanism that prevents behavioral drift in long conversations — the model can't "forget" rules because they're re-delivered each turn.

### File naming convention

Files are numbered for sort order. Lower numbers fire first:

| File | Rule |
|------|------|
| `10-no-sycophancy.txt` | No filler agreement phrases |
| `20-no-filler.txt` | No apologies, no preamble, no trailing summaries |
| `25-numeric-anchors.txt` | Word count targets (25 between tools, 100 final) |
| `30-be-critical.txt` | Challenge own work before presenting |
| `40-admit-uncertainty.txt` | Say "I don't know" when uncertain |
| `50-verify-before-done.txt` | Evidence before assertions |
| `55-no-false-claims.txt` | Never fabricate test results or claim work is done when it isn't |
| `60-output-style-safety.txt` | Warn about keepCodingInstructions: false |

### Adding or removing rules

Drop a `.txt` file in the directory. It's picked up on the next message. No hook registration needed — `behavioral-anchor.sh` reads the directory dynamically.

To disable a rule temporarily, rename it (e.g., `55-no-false-claims.txt.disabled`). The `*.txt` glob won't match it.

### Token cost

Each rule is ~10-30 tokens. The full set (~8 rules) costs ~150-200 tokens per message. This is the price of ~100% behavioral compliance vs ~80% from static system prompt instructions.

### Scope-aware rules

If `$CLAUDE_SESSION_SCOPE` is set and points to a scope file, `behavioral-anchor.sh` appends an additional rule: "SCOPE ACTIVE: Respect boundaries defined in {scope file}." This integrates with the `/scope` skill.

## Progressive Context Management

Context is the bottleneck. The Meta-Harness paper found that full execution traces (10 MTok/iteration) massively outperform summaries. But within a single session, context is finite.

Forge Studio implements 5-stage progressive warnings:

| Stage | ~Context Used | Action |
|-------|--------------|--------|
| Notice | ~50% | Re-read files before editing |
| Moderate | ~65% | Consider /compact |
| Elevated | ~75% | Recommend compacting now |
| High | ~85% | Strongly recommend /handoff |
| Critical | ~92% | /handoff now or risk incoherent output |

## Three-Tier Memory Architecture

| Tier | Storage | Loaded | Size |
|------|---------|--------|------|
| 1: Pointers | `.claude/memory/index.md` | Always | ~50 lines |
| 2: Topics | `.claude/memory/topics/*.md` | On demand | ~50 lines each |
| 3: Transcripts | Session files | Never whole (grep only) | Unbounded |

Key principle: memory is hints, not ground truth. Every recalled memory includes a `Last verified:` date and is presented as "Previously noted (may be outdated)."

**Auto-memory race condition:** Claude Code's `executeExtractMemories()` fires-and-forgets after each turn (`src/query/stopHooks.ts:149`). If the user sends the next message before extraction completes, the model reads stale memory. Forge Studio's 3-tier design mitigates this — the Tier 1 index is small and rarely changes mid-session. Don't rely on auto-memory being immediately available after the turn that triggered it.

## Planner/Generator/Reviewer Triad

Multi-agent decomposition with **tool isolation**:

| Agent | Tools | Capability | Isolation Purpose |
|-------|-------|-----------|------------------|
| Planner | Read, Glob, Grep, Bash | Read-only exploration | Can't accidentally modify code during planning |
| Generator | Read, Write, Edit, Bash, Glob, Grep | Full implementation | Has write access but follows planner's output |
| Reviewer | Read, Grep, Glob, Bash | Read-only critique | Can't rubber-stamp by editing — must honestly evaluate |

This mirrors the Meta-Harness finding that capability isolation prevents error propagation between phases.

## Execution Trace Collection

The Meta-Harness paper's ablation (Table 3) proves that full execution trace access produces a 43% relative improvement over compressed summaries (50.0 vs 34.9 median accuracy). The `traces` plugin implements this by collecting structured JSONL traces across sessions:

- **PostToolUse:Bash** — logs command, exit code, output preview
- **PostToolUse:Write|Edit** — logs file path and change type
- **SessionEnd** — writes session summary (commands, errors, files modified)

Traces stored in `~/.claude/traces/` are grep-searchable and analyzable via `/trace-review` and `/trace-stats` skills. This bridges the gap between Forge Studio's static harness and the paper's dynamic diagnostic feedback loop.

## Context Preservation Across Compaction

The `PreCompact` and `PostCompact` hooks in context-engine save and restore critical state (active scope, plan, handoff, git state) across compaction events. This prevents the model from losing track of what it was doing when context gets compressed.

## Environment Bootstrapping

Based on the Meta-Harness TerminalBench-2 finding (+1.7% from environment snapshot), the `SessionStart` hook gathers OS info, available memory, available languages, package managers, project type, and git state. This eliminates 2-4 wasted turns agents typically spend discovering their environment.

## Prompt Cache Architecture

Claude Code splits the system prompt at a `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` marker (`src/constants/prompts.ts:114`):

| Segment | Cache Scope | Content | Token Cost |
|---------|------------|---------|------------|
| Before boundary | `global` (cross-user, 1-hour TTL) | Static instructions: intro, system, tasks, actions, tools, tone, efficiency | ~3,500 |
| After boundary | `ephemeral` (session-specific) | Dynamic: session guidance, memory, env info, language, output style, MCP instructions | ~1,000-2,000 |

**What busts the cache:**
- MCP instructions — explicitly marked `DANGEROUS_uncachedSystemPromptSection`. Every MCP server connect/disconnect recomputes and invalidates.
- CLAUDE.md changes — content is in the pre-boundary static section. Any edit busts the global cache for all subsequent turns.
- Git status / current date — injected as system context, creates unique cache keys per session.

**Implication for Forge Studio:** Hook outputs inject via `<system-reminder>` tags in user messages, which are after the boundary — this is correct by design and doesn't bust the static cache. Keep CLAUDE.md stable; use hooks for volatile behavioral rules.

## Minimal Mode for Subagents

Claude Code has an undocumented `CLAUDE_CODE_SIMPLE=1` environment variable (`src/constants/prompts.ts:450-453`) that reduces the entire system prompt to ~50 tokens:

```
You are Claude Code, Anthropic's official CLI for Claude.
CWD: /path/to/project
Date: 2026-04-03
```

This strips all behavioral guidance, tool usage instructions, and output style. Useful for subagents that only need to search or read — they don't need 60K tokens of instructions to run a grep.

**Trade-off:** The subagent loses all Forge Studio behavioral steering. Only use for bulk mechanical tasks where behavioral compliance doesn't matter.

## Function Result Clearing

Under context pressure, Claude Code silently clears old tool results from the conversation (`getFunctionResultClearingSection` in `src/constants/prompts.ts`). The model is told this may happen, but the user isn't notified.

This means file reads from 10+ turns ago may no longer be in context — the model has to re-read files to see their content again. Forge Studio's `track-edits` hook already mitigates by warning after 3 edits without re-reading, but this is the underlying mechanism that makes re-reading essential: it's not just about staleness, it's about actual context eviction.

## Design Principles

1. **Zero-cost until invoked**: All skills use `disable-model-invocation: true`. No tokens spent loading unused capabilities.
2. **Hooks for enforcement, skills for guidance**: Hooks are mandatory (fire on events). Skills are opt-in (invoked by name).
3. **Fork for read-only**: Expensive analysis skills use `context: fork` to avoid polluting the main conversation.
4. **Exit codes as signals**: `exit 0` = info injected, `exit 1` = warning, `exit 2` = block the action.
5. **Filesystem as substrate**: Memory, session state, and configuration all live in files — they survive context compaction.
6. **Prefer additive changes**: The Meta-Harness TerminalBench-2 search (Appendix A.2) proved that purely additive modifications succeed where "fixing" fragile existing code fails. Six consecutive iterations modifying completion flow all regressed; the winning change was purely additive (environment bootstrapping). When extending harness behavior, add new hooks and skills rather than rewriting existing ones.
