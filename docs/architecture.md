# Forge Studio Architecture

## Core Thesis

```
Agent = Model + Harness
```

The **harness** is everything in an AI agent except the model: the code that determines what to store, retrieve, and present to the model at each turn. Research shows that changing only the harness — with the same underlying model — can produce a **6x performance gap** (Meta-Harness, 2025).

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

Cross-cutting: `evaluator` (quality gates), `workflow` (orchestration), `reference` (advanced patterns).

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

## Planner/Generator/Reviewer Triad

Multi-agent decomposition with **tool isolation**:

| Agent | Tools | Capability | Isolation Purpose |
|-------|-------|-----------|------------------|
| Planner | Read, Glob, Grep, Bash | Read-only exploration | Can't accidentally modify code during planning |
| Generator | Read, Write, Edit, Bash, Glob, Grep | Full implementation | Has write access but follows planner's output |
| Reviewer | Read, Grep, Glob, Bash | Read-only critique | Can't rubber-stamp by editing — must honestly evaluate |

This mirrors the Meta-Harness finding that capability isolation prevents error propagation between phases.

## Design Principles

1. **Zero-cost until invoked**: All skills use `disable-model-invocation: true`. No tokens spent loading unused capabilities.
2. **Hooks for enforcement, skills for guidance**: Hooks are mandatory (fire on events). Skills are opt-in (invoked by name).
3. **Fork for read-only**: Expensive analysis skills use `context: fork` to avoid polluting the main conversation.
4. **Exit codes as signals**: `exit 0` = info injected, `exit 1` = warning, `exit 2` = block the action.
5. **Filesystem as substrate**: Memory, session state, and configuration all live in files — they survive context compaction.
