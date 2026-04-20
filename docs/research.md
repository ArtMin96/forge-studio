# Research Findings

Research backing Forge Studio's design decisions. Each finding links to a specific paper or source and maps to a concrete marketplace implementation. Last updated: 2026-04-09.

---

## Papers

### IDE-Bench — Agent Failure Modes (arXiv 2601.20886)

Evaluated 15 LLMs as IDE agents across 80 real SWE tasks. Key findings:

- **8+ exploratory tool calls before first edit = 60.2% success vs 6.9% for <4** (8.7x improvement)
- Top 3 failure modes: premature editing (63%), thrashing/backtracking (28.2%), context loss (27.6%)
- Only 8% of post-edit transitions go to testing — models verify by re-reading, not running tests
- Models above 85% pass@5 show stable first-attempt success; below that, retries are needed

**Marketplace impact**: research-gate (read-before-edit block), exploration-depth-gate (warn if <6 exploratory calls), detect-thrashing.sh, test-nudge.sh, `80-explore-before-act.txt` rule.

### Meta-Harness — Harness Optimization (arXiv 2603.28052)

Automated harness search using Claude Code as proposer. Stanford/UW-Madison.

- **Harness changes alone create a 6x performance gap** — harness matters as much as the model
- Environment bootstrapping (OS, languages, tools snapshot) was the single biggest win (+1.7% on TerminalBench-2)
- Additive changes beat prompt rewrites — extend, don't restructure
- Two-stage verification prevents premature completion
- Context efficiency beats context volume — 4x fewer tokens, 7.7 points higher accuracy

**Marketplace impact**: env-bootstrap.sh (SessionStart), additive plugin architecture, `/verify` two-stage check.

### VeRO — Agent Optimization Harness (arXiv 2602.22480)

Scale AI. Evaluates optimizer configurations for coding agents.

- Evidence-Based template: **Tools >> Workflow >> Prompts** optimization hierarchy
- Single-variable experimentation prevents regression — change one thing, verify, proceed
- Prompt modifications dominate all strategies (>50% of attempts), even when structural changes available
- Early iterations yield most value — diminishing returns after 2-3 cycles
- Instruction template should match agent sophistication (detailed for simple agents, minimal for capable ones)

**Marketplace impact**: `90-single-variable-changes.txt` rule. Evidence-Based hierarchy informs plugin design.

### VCC — View-Oriented Conversation Compiler (arXiv 2603.29678)

Stanford. Compiles raw agent traces into structured views.

- **Structured views cut reflector tokens 50-67% while improving analysis quality**
- Three views: Summary (orientation), Adaptive (search), Full (detail) — progressive disclosure
- Smaller memory files correlate with higher quality — focused rules outperform verbose ones
- Format is infrastructure, not implementation detail — up to 40pp accuracy difference
- Strip harness noise (system-reminders, internal tool calls, ANSI codes) from analysis input

**Marketplace impact**: `/trace-compile` skill (three-view pattern), enhanced `/trace-evolve` with progressive disclosure.

### Poisoned Identifiers (arXiv 2604.04289v1)

Guzman Lorenzo. Tests LLM deobfuscation of adversarially-named code.

- **Task framing > verification instructions**: "write fresh" beats "verify carefully" by 80-100%
- Translation-frame trap: "convert/clean/refactor" preserves source artifacts uncritically
- Multi-agent verification detects issues but fails to correct them (0/6 correction rate)
- Models evaluate decoded names at domain level, not per-token

**Marketplace impact**: `75-task-framing.txt` rule (generation frame over translation frame).

### Speculative Decoding (arXiv 2211.17192) + Hierarchical Speculative Decoding (arXiv 2510.19705)

Leviathan et al.; Mohri et al. Draft-and-verify inference pattern with provably-equivalent outputs.

- Smaller "draft" model proposes tokens; larger "verifier" accepts or rejects in parallel
- 2–3× speedup on T5-XXL; HSD extends to stacked drafts for further 1.2× gain
- Core insight: **hierarchical verification is cheaper than monolithic generation when each tier has the minimum-capable tooling it needs**

**Marketplace impact**: validates the planner→generator→reviewer→`/verify` chain used by the workflow plugin. Each agent runs with restricted tools (read-only planner/reviewer, read-write generator) so later tiers cannot undo earlier decisions silently.

### Advisor Models (arXiv 2510.02453)

Asawa et al. Small open-weight "advisor" models that generate per-instance natural-language guidance for frontier black-box LLMs.

- **71% gain on RuleArena (Taxes)** for GPT-5 when advised by a trained open model
- 24.6% fewer steps for Gemini 3 Pro on SWE agent tasks
- Advisors trained with a cheap student model transfer gains to frontier models without access

**Marketplace impact**: corroborates the sprint-contract protocol used by the workflow plugin. A file-backed `## Contract` section in the plan is the durable advisory signal — re-read by every agent from disk so it survives context compaction.

---

## Community Sources

### Anthropic — Building Effective Agents

Orchestrator/worker pattern catalog. Five canonical patterns: prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer.

- **Router pattern cuts LLM inference cost ~40%** with <2% quality loss when routing accuracy ≥ 95%
- "Start simple. Add complexity only when it demonstrably improves outcomes."

**Marketplace impact**: `route-prompt.sh` in the workflow plugin — shell-first router that classifies prompts to one of simple / pipeline / fan-out / tdd-loop before any model call.

### Anthropic — How We Built Our Multi-Agent Research System

Scaling rules for multi-agent orchestration.

- **1 agent** for simple fact-finding (3–10 tool calls); **2–4** for comparisons; **10+** only for complex research
- Multi-agent uses ~15× more tokens than chat; **token usage alone explains 80% of performance variance**
- Parallel subagents cut wall-clock time by up to 90% on heavy tasks

**Marketplace impact**: fan-out batch size of 3–5 (workflow plugin), per-phase context isolation to keep token counts sublinear.

### Anthropic — Infrastructure Noise in Agentic Coding Evals

Runtime configuration variance dominates model-capability differences on evals.

- 6pp gap from infra alone on Terminal-Bench 2.0 — larger than most leaderboard gaps
- Separating guaranteed resource floor from kill threshold (3× headroom) cut infra error rate from 5.8% → 2.1%
- Principle: **graceful degradation over hard fail; resume over restart**

**Marketplace impact**: workflow-plugin hooks are advisory (no exit-2 blocks), LLM router fallback silently degrades when the CLI is absent, state lives on disk so retries resume from last known-good.

### mattpocock/skills `tdd` + alexop.dev *Custom TDD Workflow for Vue*

Test-first development loop with fresh-context per phase.

- Vertical slicing: one behavior → one test → one implementation; never batch
- Public-interface assertions only — avoid mocking internals
- **Per-phase subagent context isolation raised skill activation from ~20% to ~84%** (alexop)

**Marketplace impact**: `/tdd-loop` skill (workflow plugin). RED/GREEN/REFACTOR phases each run in a forked subagent context with a real-command completion gate (`./vendor/bin/pest` or project test runner).

### LangChain — Harness Hill-Climbing with Evals

Eval-driven harness optimization methodology. Six-step loop: source evals → tag by category → split train/holdout → baseline → optimize iteratively → validate with human review.

Concrete rules discovered:
- Use reasonable defaults when request clearly implies them
- Don't ask for details the user already supplied
- Don't issue near-duplicate searches
- Reorder clarifications: domain-first before implementation

**Marketplace impact**: `85-no-redundant-exploration.txt` rule, `/trace-evolve` failure categorization.

### Karpathy — LLM Wiki Pattern

Three-layer knowledge architecture: Raw Sources (immutable) → Wiki (LLM-maintained markdown) → Schema (CLAUDE.md). Operations: Ingest, Query, Lint. Sessions compound into structured knowledge.

**Marketplace impact**: Validates memory plugin's three-tier architecture. Future consideration for wiki-style memory evolution.

### Claude Code Changelog (v2.1.63–v2.1.97)

Key new capabilities leveraged:
- `${CLAUDE_PLUGIN_DATA}` (v2.1.78) — persistent per-plugin state
- Conditional `if` on hooks (v2.1.85) — declarative filtering without shell
- TaskCreated event (v2.1.84) — task lifecycle hooks
- PostCompact event (v2.1.76) — context recovery after compaction
- 1M context window GA (v2.1.75) — 15% fewer compaction events

### Community Best Practices

- ~150-200 effective instruction budget before CLAUDE.md compliance drops
- CLAUDE.md instructions: ~70% compliance. Hooks: ~100% compliance
- Plan-Execute-Verify pattern prevents premature implementation
- Subagents + worktrees for context isolation at scale
