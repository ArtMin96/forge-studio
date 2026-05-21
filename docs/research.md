# Research Findings

Research backing Forge Studio's design decisions. Each finding links to a specific paper or source and maps to a concrete marketplace implementation.

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

### Engineering Pitfalls in AI Coding Tools (arXiv 2603.20847, FSE '26)

Zhang, Dai, Pham, Uddin, Yang, Wang. Empirical study of 3.8K publicly reported bugs in Claude Code, Codex, and Gemini CLI.

- **67%+ of reported bugs are functionality defects** (not infra or UI)
- **36.9% trace to API, integration, or configuration errors**
- Most failures manifest at **tool invocation (37.2%)** and **command execution (24.7%)** stages

**Marketplace impact**: direct empirical backing for `research-gate` (read-before-edit), `evaluator` static-analysis hooks, and the PreToolUse guardrails in `behavioral-core`. Note: summary is taken from the paper abstract; full-PDF methodology was not independently verified.

### Detecting and Correcting Reference Hallucinations (arXiv 2604.03173)

Rao, Wong, Callison-Burch. Citation-fidelity study across commercial LLMs and deep-research agents.

- **3–13% of citation URLs are hallucinated** (non-existent target); 5–18% fail to resolve overall
- Deep research agents emit more citations **and** hallucinate at higher rates than search-augmented LLMs
- `urlhealth` self-correction loop plus Wayback Machine disambiguation reduces non-resolving URLs 6–79× to <1%
- Benchmarks: **DRBench** (53,090 URLs, 10 models), **ExpertQA** (168,021 URLs, 32 fields)

**Marketplace impact**: motivates the new `/verify-refs` skill in the evaluator plugin. Advisory-only — per the EACL alignment-tradeoff finding below, hard blocks on reference fidelity risk regressing other safety properties. Summary from abstract only; detection implementation not re-derived.

### The Unintended Trade-off of AI Alignment (EACL 2026 Findings, aclanthology 2026.findings-eacl.53)

Mahmoud, Khalil, Karimpanal, Semage, Rana. Shows hallucination-mitigation and safety alignment share model components — pushing one down often pushes the other down.

- Overlapping features encode both hallucination and refusal behavior
- Fine-tuning on benign data degrades alignment as a side effect
- Proposed mitigations: sparse-autoencoder feature disentanglement, subspace orthogonalization

**Marketplace impact**: rationale for keeping Forge's reliability-oriented gates (research-gate, `/verify-refs`, evaluator gates) **advisory** rather than hard blocks. Prompt-level anti-hallucination pressure is deliberately delegated to model providers; the marketplace adds procedural checks (separate agents, evidence requirements) that don't alter alignment weights. Summary from HTML abstract after PDF extraction failed.

### Code as Agent Harness — Survey (arXiv 2605.18747)

Six years of harness-engineering research compressed into one organizing framework. The paper argues that an agent harness must be *executable* (every claimed behavior can be run as a command), *inspectable* (internal state is visible without access to model weights), and *stateful* (the harness, not the context window, holds durable facts across sessions). Together these three properties prevent the most common failure mode: agent behavior diverges from intent after compaction or handoff because the harness provided no ground truth to recover from. The paper's central loop is Plan–Execute–Verify (PEV): plan in isolation, execute with narrow tool grants, verify against a machine-checkable criterion before declaring done.

Five stages define Agentic Harness Engineering (AHE): observe (collect traces), diagnose (localize failure via telemetry), propose (draft a falsifiable change), evaluate (run the criterion), promote (write to manifest with evidence). Six convergence types — correctness-gated, security-gated, performance-gated, score-based, consensus, implicit — are enumerated in §4.3.2; "implicit" (user judgment) is the default but loses falsifiability in multi-session sprints. The diagnose stage (§3.5.2, §5.1.1) shows production attribution accuracy of 14–53% when localizing regressions from telemetry alone; without verifier_obligations on each manifest entry, attribution degrades to guessing. SyncMind (§4.3) formalizes belief-state divergence as `|Bk − Sk|` — the distance between an agent's cached belief about a file and disk reality — and identifies this as the technical root of brittleness after compaction.

- **Belief-state divergence is the primary compaction failure mode** (§4.3): `|Bk − Sk|` grows every time the context window summarizes an edit rather than retaining the exact post-edit content. Cheapest mitigation: sha256 snapshot before and after every edit, re-checked before the next edit on the same path.
- **Evidence bundles distinguish verified from claimed quality** (§5.2.4): a manifest entry without `evidence_bundle.checks_run` is indistinguishable from one that was never verified. The paper requires each entry to declare what was read (`read_set`), what was assumed (`assumptions`), what was checked (`checks_run`), and what remains uncertain (`remaining_risks`).
- **Harness mutations require change contracts** (§5.2.3): a proposal to change a harness component must carry `{component, failure_mode_targeted, predicted_improvement, invariants_preserved, falsifiable_by, rollback_steps}`. Absent a falsifiable_by command, safe rollback is guesswork.
- **Adaptive reviewer pools reduce single-reviewer bottleneck** (§4.1.3): SoA and MAGIS scale reviewer count to the number of independent candidate files. For a planner output enumerating N ≥ 3 independent files, running N parallel reviewers and an aggregator reduces wall-clock time by up to N× while improving coverage per file.
- **Compaction with provenance beats prose summaries** (§3.2.6): structured YAML capturing open failures, recent edits, pending verifications, and belief snapshots lets the post-compact turn recover concrete state (failing test name, suspect file path) rather than re-deriving it from a summary paragraph.
- **Feedback should route by type, not be poured into one inbox** (§5.2.2): compiler errors trigger local syntax repair, test failures trigger behavioral diagnosis, type errors trigger annotation fixes, lint warnings trigger in-place revision. A single "something failed, retry" path discards the discriminating signal the error string already carried.
- **Verifiers must declare their scope** (§5.2.2): every accepted action should record what was checked, what could not be checked, and what confidence the verifier provides. A green pass is meaningful only when paired with the uncovered set.
- **Critic confidence is orthogonal to severity** (§5.2.2): a high-severity low-confidence finding is speculation; a low-severity high-confidence finding is a known nit. Reviewers that conflate the two waste user attention on the wrong axis.
- **Policy must be context-sensitive** (§5.2.5): the same secret-shape regex flagged in `src/config.ts` is a real leak; in `tests/fixtures/api-keys.test.js` it is intentional. Global rules without per-path scope train users to ignore the gate.
- **Static and execution views answer different questions** (§4.4): a static caller graph says who *could* call a symbol; execution traces say who *actually* called it. Refactoring on the graph alone misses dynamic dispatch; deciding on traces alone misses dormant callers. The deepest harness joins both — intersection, static-only, runtime-only become three distinct decision axes.

**Marketplace impact**: `/belief-audit` ([docs/belief-audit.md](belief-audit.md), context-engine PreToolUse + PostToolUse hooks), transactional manifest schema with `evidence_bundle` and `read_set` ([docs/transactional-manifest.md](transactional-manifest.md), forge-meta change-manifest), `/convergence-check` ([docs/convergence.md](convergence.md), workflow), `/failure-attribute` (traces), `/harness-metrics` ([docs/harness-metrics.md](harness-metrics.md), forge-meta), `change_contract` block enforced by `/assess-proposal` on every `/auto-tune-skill` proposal, adaptive reviewer pool in `/dispatch` (agents), structured pre-compact briefing via `forward-briefing.sh` (context-engine PreCompact) + `post-compact-recovery.sh` (PostCompact) ([docs/compaction-briefing.md](compaction-briefing.md)), feedback-type router `route-failure.sh` (evaluator PostToolUseFailure), `COVERED`/`UNCOVERED` lines in `/verify` verdict block, `[CONFIDENCE]` field in adversarial-reviewer findings, context-sensitive policy scope in `policy-gateway/rules.d/secrets.txt`, `/impact-trace` static × execution dual-view (code-graph).

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
