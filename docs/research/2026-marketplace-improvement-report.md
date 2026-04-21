# Forge Studio Marketplace Improvement Report

**Date:** 2026-04-21
**Scope:** Integrated synthesis of 9 mindstudio.ai Claude Code posts + broader 2025–2026 Claude Code community research + marketplace self-audit, producing a prioritized gap list and build-now recommendations.

---

## Executive Summary

Forge Studio already covers the full surface of harness-shaped work: behavioral steering, context management, memory, evaluation, orchestration, multi-agent decomposition, tracing, and self-evolution. Most published "Claude Code best-practice" patterns from 2025–2026 are already implemented in one form or another — see the overlap matrix in §4.

The genuine gaps are narrow and concern **parallel multi-agent execution** and **protocol-level self-inspection**. The five recommended additions (§6) all live inside existing plugins; no new plugin folder is needed. The one widely cited pattern that is **not** adopted is Opus-plan → Sonnet-execute model routing: the maintainer uses Opus end-to-end, so model-downgrade token savings are explicitly out of scope.

This report is both a reference document (for future contributors deciding what to add) and a justification record (why specific additions were chosen and others rejected).

---

## 1. Marketplace Inventory (as of 2026-04-21)

| Shape | Count |
|---|---|
| Plugins | 14 |
| Skills | 46 (post-cycle; pre-cycle was 43, plus 3 additions) |
| Hooks | 47 matcher entries (matching `/entropy-scan` convention; post-cycle +2) |
| Agents | 4 |
| Behavioral rules (`rules.d/`) | 8 |
| Docs | 15 files + `HARNESS_SPEC.md` + this report |

Counts reflect state after this cycle's additions. `/validate-marketplace` and `/entropy-scan` can reproduce them.

### Component Coverage

| # | Harness Component | Covered By | Status |
|---|---|---|---|
| 1 | System Prompts | `behavioral-core`, `caveman`, `reference` | Full |
| 2 | Tool System | `agents` (capability-isolated planner/generator/reviewer) | Full |
| 3 | Permission System | `behavioral-core/block-destructive`, `research-gate/require-read-before-edit`, `evaluator/pre-commit-gate` | Full |
| 4 | Context Management | `context-engine`, `caveman`, `token-efficiency`, `rtk-optimizer`, `code-graph` | Full |
| 5 | Memory Architecture | `memory` (three-tier), `traces` (JSONL), `workflow/reflect` | Full |
| 6 | Multi-Agent Decomposition | `agents` (pipeline + fan-out + subagent-driven), `workflow` (orchestration, router) | **Partial — no worktree/directory isolation** |
| 7 | Behavioral Steering | `behavioral-core/rules.d`, `research-gate`, scope-guard, self-review nudge | Full |
| 8 | Self-Evolution | `workflow/evolve`, `evaluator/assess-proposal`, `workflow/commit-proposal`, `workflow/rollback`, memory ledger | **Partial — no inspection tool for the ledger** |

Coverage is complete at component granularity. The partials (6, 8) concern specific sub-capabilities, addressed in §5.

### Cross-cutting Plugins
`evaluator`, `workflow`, `reference`, `traces`, `diagnostics`, `caveman`, `token-efficiency`, `research-gate`, `rtk-optimizer`, `code-graph`. These do not map one-to-one to harness components; they compose to deliver component-level behavior.

---

## 2. Synthesis of 9 mindstudio.ai Claude Code Posts

Per-post summary of the core pattern, the concrete techniques it teaches, the Claude Code primitives it depends on, and the prerequisites a team needs to run it.

### 2.1 Agentic Workflow Patterns

**Core.** Taxonomy of autonomy levels — sequential, operator-delegation, parallel specialized teams, and headless autonomous runs. Each level trades control for throughput.

**Techniques.** Sequential chaining; operator/worker decomposition; parallel partitioning with consistent output schemas; role-scoped `CLAUDE.md` per worker; headless operation via `claude --print`; explicit per-phase failure-recovery design; `--allowedTools` capability isolation; human checkpoints on destructive steps.

**Primitives.** Subagents, per-agent CLAUDE.md, `--allowedTools`, headless `--print` mode, JSON-shaped inter-agent messages.

**Prereqs.** Task decomposition skill, context-window budgeting, defined failure modes, approval gates where needed.

### 2.2 Agent Teams: Parallel Workflows

**Core.** A small team (2–5) of persistent specialized agents each owning a directory, coordinating through a shared task list — replacing fire-and-forget subagents.

**Techniques.** Directory-level ownership (`src/components/` for one agent, `src/api/` for another); per-role CLAUDE.md with schemas and conventions; explicit merge protocol (orchestrator-decides, sequential, or human); git worktrees for physical isolation; a validator agent run after merge.

**Primitives.** Multi-agent, per-role CLAUDE.md, git worktrees/branches.

**Prereqs.** Git repo, organized layout, rate-limit headroom (parallel agents multiply token burn), Ultra-plan access.

### 2.3 Agentic Operating System

**Core.** Treat Claude Code as a persistent OS layer: memory, modular skills, self-improvement loop, scheduled execution, multi-agent coordination.

**Techniques.** File layout: `CLAUDE.md` + `LEARNINGS.md` + `/skills/` + `/memory/` + `/schedules/`; each skill reads LEARNINGS before execution, appends after; heartbeat skill every 15–60 min dispatches based on state; `eval.json` quality gates with retry on failure; weekly LEARNINGS consolidation to prevent bloat; shared markdown task queues as distributed state.

**Primitives.** Skills, persistent memory files, scheduled execution (cron or similar), `eval.json`, file-based queues, optional MCP.

**Prereqs.** Filesystem or cloud storage, scheduler (Linux cron or cloud equivalent), markdown discipline.

### 2.4 Split-and-Merge Pattern

**Core.** A parent agent fans out 2–10 sub-agents via the `Task` tool within a single session, validates and deduplicates, then merges.

**Techniques.** Decompose into independent subtasks; define explicit output schemas in each subagent prompt; issue Task calls in parallel (not sequentially); validate malformed/missing outputs at merge; dedupe and rank; pilot with 2–3 before scaling; self-contained subagent prompts carrying their own scope/format/constraints; nested subagents possible but expensive.

**Primitives.** `Task` tool, orchestrator agent, isolated-context subagents, nested subagents.

**Prereqs.** Demonstrable independence between subtasks, output-schema discipline.

### 2.5 Agent Teams: Shared Task List

**Core.** Orchestrator writes tasks to a shared real-time queue; workers claim, lock, execute in isolated worktrees, report status. Eliminates sequential bottlenecks.

**Techniques.** Task objects with description, file paths, deps, status (pending/in-progress/completed/blocked); claim-and-lock via status transition to prevent duplicate work; dependency ordering with skippable blocked items; size tasks to fit one context window; start with 2–4 workers and measure diminishing returns.

**Primitives.** Orchestrator + workers, git worktrees, shared task list file, per-agent context windows.

**Prereqs.** Git repo, decomposable goal, modular codebase.

### 2.6 Opus Plan Mode → Sonnet Execute

**Core.** `opus-plan` routes planning to Opus and execution to Sonnet for roughly 5× cost savings on planning-heavy sessions.

**Techniques.** Start with Opus to gather requirements and produce a numbered plan (failure points, file structures, function signatures); review; switch via `/model claude-sonnet-4-5`; switch back to Opus only when a mid-build architectural surprise appears; verify the active model before big generations.

**Primitives.** `/model` slash command, plan mode, session context management.

**Prereqs.** Opus + Sonnet access, ability to split planning from execution.

**Note — not adopted by Forge Studio.** The maintainer uses Opus end-to-end (planning and execution). Token savings must come from context/tool/skill-level optimization rather than model downgrades. This pattern remains in the literature for teams that value cost over model consistency.

### 2.7 Karpathy LLM Wiki (Knowledge Base)

**Core.** Replace RAG/embeddings with direct context loading — a `/wiki` folder of markdown concatenated into the 200K window for full-corpus reasoning.

**Techniques.** Descriptive lowercase-hyphenated `.md` files by topic; full sentences with headers (not telegraphic bullets); `cat wiki/*.md > wiki_export.txt` to load; system prompt enforcing "answer only from provided content, cite sections"; under 100K words load all, above 100K use grep/fuzzy file selection; optional scheduled ingestion from external docs.

**Primitives.** None Claude-Code-specific (originally API-focused). Maps to a Skill with file-pack references.

**Prereqs.** 200K-context access, markdown discipline.

### 2.8 What Are Claude Code Skills

**Core.** A skill is a reusable process doc (`skill.md`) with staged, on-demand loading of reference files to prevent context bloat.

**Techniques.** `skill.md` carries only ordered steps (no background); split supporting content into `brand.md`, `examples.md`, `format.md`, `learnings.md`; four structural patterns (linear, conditional, loops, parallel); explicit output-format reference file; staged context loading at specific steps; skill chaining where outputs feed the next skill; append observations to `learnings.md` for self-improvement; binary pass/fail evaluation criteria.

**Primitives.** Skills, `learnings.md` memory, workflow chains, implicit hooks for staged loading.

**Prereqs.** Procedural decomposition, context-window awareness.

### 2.9 Skills vs Slash Commands

**Core.** Skills = automatic, context-triggered. Slash commands = explicit, manual. Choose based on whether execution should be consistent-on-condition or user-controlled.

**Techniques.** Define precise trigger conditions in `skill.md` (exact inputs, not vague intent); prefer code scripts over markdown for procedural steps (less ambiguity); separate process logic from reference data; test with varied real-world inputs before deploying; use slash commands as explicit entry points into multi-step skills; layered architecture (skills as automation layer, slash commands as control/correction layer); group overlapping skills with branching logic rather than creating many narrow ones.

**Primitives.** Skills, slash commands (including `/simplify`, `/batch`, `/loop`, `/btw`, `/voice`), `skill.md`, reference files, code-script steps.

**Prereqs.** Workflow decomposition, ability to distinguish repeatable automation from one-time control.

### 2.10 Cross-Cutting Themes

1. **Context staging wins.** Posts 3, 7, 8, 9 all separate process from reference material, loading the latter on demand. Core harness principle: context management.
2. **Shared state via markdown files.** Posts 2, 3, 5 all coordinate multi-agent work through plain-text queues rather than message passing. Cheap, auditable, Claude-native.
3. **Worktree isolation.** Posts 2, 5 converge on git worktrees as the physical isolation mechanism for parallel agents editing the same repo.
4. **Planner/executor split.** Posts 1 (operator delegation), 4 (orchestrator + subagents), 5 (orchestrator + queue workers), 6 (Opus plan + Sonnet execute) are the same pattern at different layers: reasoning vs execution.
5. **Self-improvement via LEARNINGS.md.** Posts 3, 8 use append-on-completion files with periodic consolidation. Harness principle: memory + evaluation.
6. **Output-schema discipline.** Posts 1, 4, 8, 9 all require explicit output formats to prevent drift — the lever that makes merge/chain steps actually work.
7. **Evaluation gates.** Posts 3, 8 call for binary pass/fail criteria per skill/output.
8. **Capability scoping.** Posts 1 (`--allowedTools`), 2 (directory ownership), 5 (claim-lock) all narrow each agent's blast radius.

### 2.11 Unique Contributions Per Post

- **Post 1:** Headless `--print` autonomy; per-phase failure-recovery design.
- **Post 2:** Directory-level ownership as a conflict-prevention primitive.
- **Post 3:** Heartbeat scheduler and weekly LEARNINGS consolidation — the only post that closes the self-improvement loop operationally.
- **Post 4:** `Task`-tool fan-out in a single session (vs multi-terminal teams); nested subagents.
- **Post 5:** Claim-and-lock status semantics — the concurrency-control detail others omit.
- **Post 6:** Concrete model-routing economics (`/model` mid-session switching).
- **Post 7:** Full-context loading as an alternative to RAG for sub-100K corpora.
- **Post 8:** Four skill structural patterns; the staged-loading mental model.
- **Post 9:** Decision rubric between skills and slash commands; "prefer code scripts over markdown" for determinism.

### 2.12 Implementation Complexity Tiering

| Tier | Patterns |
|---|---|
| Trivial (markdown/JSON only) | Opus-plan routing (2.6), skill.md scaffolding (2.8), skill-vs-command rubric (2.9), wiki folder + `cat` concat (2.7), directory-ownership CLAUDE.md (2.2) |
| Moderate (hooks + shell scripts) | Split-and-merge `Task` orchestration prompt (2.4), LEARNINGS append-after-run (2.3, 2.8), eval.json gates (2.3, 2.8), output-schema enforcement hook (2.1, 2.4) |
| Deep infra (scheduler, git, state machine) | Heartbeat + weekly consolidation (2.3), shared task queue with claim-lock (2.5), worktree-per-agent teams (2.2, 2.5), headless event-triggered autonomy (2.1) |

---

## 3. Broader Claude Code Research (2025–2026)

### 3.1 Official Anthropic Guidance

Claude Code plugins entered public beta in October 2025 and have since stabilized. The marketplace system supports four installation scopes (user, project, local, shared) and multiple source types (relative path, GitHub, git URL, git subdirectory, npm).

**Marketplace schema** ([Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces)):
- `.claude-plugin/marketplace.json` with plugin listings and metadata
- Source definitions supporting git and npm
- Strict mode controlling authority for component definitions
- Plugin caching at `~/.claude/plugins/cache/` with symlink support
- Private repository auth via `GITHUB_TOKEN`, `GITLAB_TOKEN`, `BITBUCKET_TOKEN`

**Skills & hooks format.** SKILL.md with YAML frontmatter supports `description`, `disable-model-invocation`, `context: fork`, `allowed-tools`, `argument-hint`, `model`, `effort`, `agent`, `paths`, `hooks`, `shell`, plus a few more (see `HARNESS_SPEC.md` §Invariant: SKILL.md Frontmatter for the complete list). Hook events operate on `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, plus others introduced through the year. Exit codes: 0 = info, 1 = warning, 2 = block (valid only for `PreToolUse` and `PreCompact`).

**Sub-agents & planning.** Anthropic's guidance emphasizes isolated subagent execution with filtered tool access and specialized prompt composition over monolithic system prompts. Plan mode emerges from multi-phase scaffolding (initializer agent → coding agents with incremental feature work) rather than a dedicated feature.

**Context management.** Progressive compaction and just-in-time tool discovery are centered. Tools should be self-contained with clear use cases, curated minimally to avoid ambiguous dispatch.

### 3.2 Community Patterns & Reference Implementations

Trending marketplaces and their lessons:
- **[Claude Code Plugins Plus Skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills)** — large surface area (423 plugins, ~2,849 skills) organized loosely; useful as a catalog of skill shapes.
- **[Claude Night Market](https://github.com/athola/claude-night-market)** — 19 focused plugins across git workflows, code review, spec-driven development; single-responsibility discipline.
- **[Everything Claude Code](https://github.com/affaan-m/everything-claude-code)** — agent-harness performance optimization emphasis.
- **[Awesome Claude Plugins](https://github.com/quemsah/awesome-claude-plugins)** — community adoption tracking.

Patterns observed across trending repos:
1. **Multi-layer plugin structure** — skills for immediate tasks, agents for reasoning-heavy work, hooks for automation.
2. **MCP server bundling** — plugins now routinely embed pre-configured MCP servers. Forge Studio already does this with `code-graph` and `rtk-optimizer`.
3. **Performance tuning** — token optimization, skill reduction, dynamic tool discovery.
4. **Clarity over completeness** — [Learning from Claude Code's own plugins](https://tgvashworth.substack.com/p/learning-from-claude-codes-own-plugins) reports that Anthropic's internal plugins prioritize single responsibility and minimal instruction overhead.

### 3.3 Agent Harness Research

**Definition consensus (2026).** A harness is the runtime orchestration layer wrapping the core reasoning loop and coordinating tool dispatch, context compaction, safety enforcement, session persistence, and multi-agent coordination. Per [Building Effective AI Coding Agents](https://arxiv.org/html/2603.05344v1), a harness differs from scaffolding: scaffolding assembles the agent before first prompt (tools, system prompt, initial environment); the harness manages everything after.

**Reference harness components (OpenDev pattern).**
1. ReAct execution loop (pre-check/compaction → thinking → self-critique → action → tool execution → post-processing)
2. Prompt composition engine (modular sections by priority, cacheable vs non-cacheable)
3. Tool registry with lazy discovery
4. Safety system (prompt guardrails, schema validation, runtime approvals, lifecycle hooks)
5. Context engineering (progressive compaction, adaptive memory)
6. Subagent orchestration (isolated execution with filtered tool access)

Forge Studio covers all six: compaction hooks and behavioral re-injection (1), `behavioral-core/rules.d` + `caveman` (2), Claude Code's deferred tools + `ToolSearch` (3), `research-gate` + `behavioral-core/block-destructive` + evaluator gates (4), `context-engine` progressive warnings (5), `agents` (6).

**Natural-language harnesses (NLAH).** [Natural-Language Agent Harnesses](https://arxiv.org/html/2603.25723v1) externalize harness logic as editable natural language — explicit role assignments, portable orchestration logic, stage structure, visible failure-recovery. Research-stage; not yet standardized into Claude Code plugins. Not recommended for adoption this cycle.

### 3.4 Specific Techniques Worth Evaluating

**A. Token-efficient tool use.** [Dynamic toolsets](https://www.speakeasy.com/blog/how-we-reduced-token-usage-by-100x-dynamic-toolsets-v2) reports ~96% token reduction by replacing upfront schema loading with `search_tools` / `describe_tools` / `execute_tool` triplet. Claude Code already exposes this via deferred tools and `ToolSearch`. Plugin marketplaces should neither re-implement nor fight it; instead, avoid bundling dozens of near-duplicate commands that inflate the searchable surface. [CodeAgents](https://arxiv.org/html/2507.03254v1) codifies multi-agent reasoning in pseudocode, reducing input tokens 55–87% and output tokens 41–70%.

**B. MCP server integration.** [MCP 2026 Roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/) — 10,000+ public MCP servers in production, MCP donated to the Linux Foundation in December 2025, MCP Server Cards via `.well-known` URL for registry discovery. Plugins can bundle MCP servers; marketplace entries support the `mcpServers` field. Forge Studio already uses this in `code-graph` and `rtk-optimizer`.

**C. Evaluation frameworks.** SWE-bench variants (Verified, Bash-only, Multilingual, Multimodal, SWE-Bench Pro) provide external baselines; progress from 40% → >80% in twelve months. [Scaling agentic evaluation](https://www.ai21.com/blog/scaling-agentic-evaluation-swe-bench) shows multi-tenant simulation environments outperform per-run isolated containers for throughput. For plugin marketplaces, the relevant pattern is not running SWE-bench itself but providing an **internal** eval harness that validates plugin integration (frontmatter, hook exit codes, skill size budgets, marketplace.json consistency). Forge Studio does the first part manually in CLAUDE.md; the new `/validate-marketplace` skill (§6) mechanizes it.

**D. Checkpoint & rollback.** [Agentic checkpoint patterns](https://hamy.xyz/blog/2025-07_ai-checkpointing) distinguish checkpoint (snapshot at a point in time) from rollback (reversibility of mutating operations). Production pattern: tiered state (ephemeral in-context → persistent external storage → checkpoint layer). Forge Studio's `context-engine/checkpoint`, `context-engine/handoff`, and the self-evolution ledger snapshots already implement this.

**E. Session resumption.** Session persistence via JSONL rollout events; multi-agent sessions need a shared state layer. Forge Studio's `context-engine/handoff` + `/resume` + pre/post-compact hooks cover the single-session case; worktree-team (§6) extends this to the multi-agent case.

**F. Subagent coordination.** OpenDev's pattern — single parameterized MainAgent class with behavioral variation via constructor parameters (allowed_tools, system_prompt overrides) rather than class hierarchies — translates in Claude Code to agent files sharing frontmatter conventions with role-specific prompts. Forge Studio's `planner.md`/`generator.md`/`reviewer.md` follow this already; `worktree-team` (§6) extends it to N parallel instances.

### 3.5 Anti-Patterns & What Not to Do

Drawn from [Best Practices for Claude Code](https://code.claude.com/docs/en/best-practices), [Claude Code Gotchas](https://www.dolthub.com/blog/2025-06-30-claude-code-gotchas/), and community feedback:

**Context pollution.**
- Kitchen-sink sessions (unrelated tasks stacked without `/clear`) degrade coherence. Use `/clear` between tasks, or `/handoff` + `/resume` for related tasks.
- Over-correcting loops (re-trying a failing approach) burn tokens without progress. After two failures, `/clear` and rewrite the initial prompt.
- Over-specified `CLAUDE.md` files (>200 lines) dilute attention. Prune ruthlessly.

**Instruction anti-patterns.**
- Negation-based rules ("Do NOT use X") activate the concept they forbid. Prefer positive framing ("Use Y instead"). Forge Studio's `rules.d/` already follows this.
- Ambiguous tool design causes overtriggering. Prefer self-contained tools with minimal use-case ambiguity.

**State-management pitfalls.**
- Assuming agents remember what files they read — explicitly re-read after compaction. Forge Studio's `research-gate/require-read-before-edit` enforces this mechanically.
- "Dumber after compaction" — Claude forgets prior window state. Provide explicit navigation (progress files, `git log`, baseline tests). Forge Studio's `context-engine/pre-compact` and `post-compact` hooks address this.
- Cross-session assumptions — no continuity without an explicit persistent state layer. Forge Studio's `/handoff` + `/resume` provides this.

**Plugin-specific pitfalls.**
- Referencing files outside the plugin directory — they won't be copied to cache. Use `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` variables.
- Pre-loading all tool schemas — use lazy/dynamic discovery.
- Monolithic system prompts — modularize by priority.
- Untested harnesses — evaluations should test plugin + harness integration, not isolated plugin code.

---

## 4. Overlap Matrix — Research Findings vs Existing Plugins

This is the load-bearing table of the report: every substantive pattern from §2 and §3 mapped to an existing Forge Studio capability or flagged as a gap. This is what prevented five or six "new plugin" proposals from being recommended.

| Pattern | Already Covered By | Status |
|---|---|---|
| Sequential chaining / operator delegation (2.1) | `workflow/orchestrate`, `agents/dispatch` | Have it |
| Fan-out to subagents (2.1, 2.4) | `agents/fan-out`, `reference/parallel-patterns` | Have it |
| Headless `--print` autonomy (2.1) | Outside marketplace scope (CLI flag) | Skip |
| Capability isolation via `allowed-tools` (2.1) | `agents/planner` (read-only), `reviewer` (read-only) | Have it |
| Multi-agent teams (2.2) | `agents` plugin pipeline | **Partial** — no worktree/directory isolation |
| Directory-level ownership (2.2) | Not built — no PreToolUse hook scoping writes by agent role | **Gap** |
| Git worktree per agent (2.2, 2.5) | Not built in the marketplace (Superpowers has a skill; Forge has no plugin) | **Gap** |
| CLAUDE.md + LEARNINGS.md + skills + memory OS (2.3) | `memory`, `traces`, `workflow/reflect`, ledger | Have it — strongest existing coverage |
| Heartbeat scheduler (2.3) | Outside marketplace scope (requires cron) | Skip |
| `eval.json` binary gates (2.3, 2.8) | `evaluator/verify`, `evaluator/gate-report`, `evaluator/healthcheck` | Have it |
| Split-and-merge via `Task` tool (2.4) | `agents/fan-out`, `agents/dispatch` | Have it |
| Nested subagents (2.4) | `agents/subagent-driven-development` | Have it |
| Shared task list (2.5) | `context-engine/task-guardian` tracks tasks created via `TaskCreate` | Partial — no claim-lock semantics |
| Worker-pool orchestration (2.5) | Not built | Gap (subsumed by worktree-team) |
| Opus-plan → Sonnet-execute routing (2.6) | Not built, **explicitly rejected** (Opus end-to-end preference) | Skip |
| Karpathy wiki pattern (2.7) | Not built; `memory` is different shape | Optional — §6 Tier 2 |
| Skills with staged reference loading (2.8) | All Forge skills use `disable-model-invocation: true` | Have it |
| LEARNINGS.md append-after-run (2.8) | `memory/remember`, `workflow/reflect`, ledger | Have it |
| Binary pass/fail per skill (2.8) | `evaluator/gate-report`, `evaluator/verify` | Have it |
| Skills-vs-commands rubric (2.9) | Not documented as such — best-practice guidance missing | Doc gap |
| Output-schema enforcement (2.1, 2.4, 2.8) | `agents/contract` declares but no mechanical validator | **Partial gap** |
| Dynamic tool discovery (3.4A) | `ToolSearch` (platform-level); `reference/thinking-modes` covers extended thinking | Have it |
| MCP server bundling (3.4B) | `code-graph`, `rtk-optimizer` | Have it |
| Checkpoint / rollback (3.4D) | `context-engine/checkpoint`, `workflow/rollback`, ledger snapshots | Have it |
| Session resumption (3.4E) | `/handoff` + `/resume` + pre/post-compact hooks | Have it |
| Plugin evaluation harness (3.4C, internal shape) | Not built — no automated plugin validation | Hardening gap |
| JSON + frontmatter validators (hardening) | Manual only per CLAUDE.md guidance | Hardening gap |
| Ledger audit tool (hardening) | No inspection skill despite ledger protocol | Hardening gap |
| Plugin dev walkthrough (hardening) | CLAUDE.md covers structure; no walkthrough | Doc gap |
| NLAH harness reformulation (3.3) | Research-stage | Skip |

Aggregate: the pattern-surface is large; the gap-surface is small.

---

## 5. Genuine Gaps

Five items qualify — not fifteen, because most patterns are already delivered by existing plugins. The filter was strict: a "gap" means no existing plugin expresses the pattern mechanically, and the pattern has a concrete shape (not research-stage).

### 5.1 Worktree-Team Orchestration (Capability Gap)
Patterns 2.2, 2.5 converge on the same primitive: N parallel agents in git worktrees, each with role-scoped CLAUDE.md and directory ownership. Forge Studio's existing `agents` plugin does in-session pipeline and fan-out, but neither provides physical worktree isolation nor per-agent filesystem scoping. This is the clearest gap.

### 5.2 Directory-Ownership Guard (Capability Gap)
Directly complements 5.1. A PreToolUse hook that, when an active role is set, blocks Edit/Write outside the role's declared owned directories. Opt-in (via env var) so it stays dormant outside of worktree-team sessions. Mechanical prevention of the single most common multi-agent failure mode: two workers editing the same file.

### 5.3 Output-Schema Validator (Capability Gap, Partial)
`agents/contract` already declares the sprint contract shape. What's missing is a SubagentStop hook that parses the planner's declared `## Output Schema` or `## Contract` and warns when the generator's artifacts omit required sections. This makes the contract mechanically enforceable rather than a convention the reviewer has to notice.

### 5.4 Marketplace Validator (Hardening Gap)
`CLAUDE.md` currently lists a manual checklist (check JSON, check executability, check frontmatter, check size). `/entropy-scan` covers most of this but is geared toward drift detection, not pre-release validation. A focused `/validate-marketplace` skill — JSON parse, SKILL.md schema, hook exec, skill size budget, marketplace.json/plugin-dir set equality — replaces the checklist with a runnable check and can be invoked before commits.

### 5.5 Ledger Audit (Hardening Gap)
The lineage protocol documented in `HARNESS_SPEC.md` §Self-Evolution and `docs/lineage.md` has strict invariants: every commit has an earlier propose + pass-assess on the same resource/version; every commit/rollback has a snapshot file; the ledger is append-only; the `resource` field must be a registry slug. Nothing in the marketplace currently inspects these. `/lineage-audit` closes the inspection loop.

### Explicitly Rejected
- **shared-task-queue plugin** — overlaps `context-engine/task-guardian` and `TaskCreate`/`TaskCompleted` hooks.
- **learnings-memory plugin** — overlaps `memory/remember`, `workflow/reflect`, ledger.
- **eval-gates plugin** — overlaps `evaluator/verify`, `evaluator/gate-report`, `evaluator/healthcheck`.
- **heartbeat scheduler plugin** — out of marketplace scope (requires cron/remote trigger).
- **Opus-plan → Sonnet-execute command** — maintainer uses Opus end-to-end.
- **NLAH harness reformulation** — research-stage; not standardized.

---

## 6. Recommendations

Tiered, with the rule that every addition either lives inside an existing plugin or is explicitly justified as a new plugin.

### Tier 1 — Build Now (5 additions, 0 new plugins)

| # | Addition | Plugin (existing) | Shape | Est. size |
|---|---|---|---|---|
| 1 | `worktree-team` | `agents` | New skill | ~80 LoC |
| 2 | `directory-ownership` | `agents` | New PreToolUse hook | ~50 LoC |
| 3 | `output-schema-check` | `agents` | New SubagentStop hook | ~60 LoC |
| 4 | `validate-marketplace` | `diagnostics` | New skill | ~70 LoC |
| 5 | `lineage-audit` | `memory` | New skill | ~70 LoC |

Rationale for single-plugin consolidation: three of five additions concern multi-agent orchestration and naturally belong in `agents`. Validation is diagnostic work — `diagnostics` is the home. Ledger inspection is a memory/self-evolution concern — `memory` is the home (it already owns the version-aware `remember` skill).

### Tier 2 — Optional / Future (not built this cycle)

- **Karpathy wiki skill.** Would add a `knowledge-wiki` skill (likely in `memory` or a new `knowledge` plugin) that concatenates `/wiki/*.md` into context on demand. Not built because: (a) the existing `memory` plugin is sufficient for cross-session recall; (b) adding it risks becoming an underused convention unless the team commits to writing a wiki. Kept on the shelf for teams that actually build out a project wiki.
- **Monitor-based plugins.** Claude Code supports background monitors ([docs/architecture.md §Background Monitors](../architecture.md)). Forge Studio declares no monitors. Candidate uses: watching `.claude/traces/` for error bursts, watching CI status, watching external file changes. Not built because no concrete use-case is currently paining the maintainer.
- **Plugin development guide.** A walkthrough (not just a structure reference) for writing a new plugin. CLAUDE.md has the skeleton; a narrative `docs/plugin-development.md` would help contributors. Deferred to when contributor volume justifies it.

### Tier 3 — Out of Scope

- **Heartbeat scheduler.** Requires cron or remote triggers — outside marketplace scope.
- **Opus-plan → Sonnet-execute routing.** Maintainer uses Opus end-to-end. Token savings from this pattern are explicitly declined.
- **Multi-tenant evaluation simulation.** Infrastructure-heavy; not a marketplace concern.
- **Natural-language harness reformulation.** Research-stage; no stable Claude Code integration exists.

---

## 7. Design Notes for Tier-1 Additions

### 7.1 `agents/skills/worktree-team/SKILL.md`

Shape: a slash command that reads N role definitions (planner, generator, reviewer by default, extensible) and bootstraps a worktree per role with a role-scoped CLAUDE.md. The skill does **not** dispatch work across the worktrees — Claude Code's `--agent` flag and the existing `agents` plugin handle that. The skill's responsibility is physical isolation: creating worktrees, writing role-scoped CLAUDE.md files, emitting the launch commands.

Key decisions:
- Worktrees live at `.claude/worktrees/<role>-<short-sha>` to match the Superpowers `using-git-worktrees` convention and keep them discoverable.
- Role-scoped CLAUDE.md composes the repo CLAUDE.md + a `## Role: <name>` section + owned-directory declaration.
- Worktrees are cleaned up via Claude Code's built-in `ExitWorktree` when idle.
- N is bounded (default 3, max 5) — per 2.2, parallel agents multiply token burn.

### 7.2 `agents/hooks/directory-ownership.sh`

Shape: PreToolUse hook on Edit|Write. Reads `.claude/agents/active-role.json` (written by `worktree-team` when a role is activated). If a role is active and its `owned_directories` list doesn't include the target file path, exit 2 with JSON `permissionDecision: deny` and an explanation citing the role.

Opt-in via `FORGE_DIRECTORY_OWNERSHIP` (defaults `"0"`). This matches the existing opt-out patterns (`FORGE_RTK_DISABLED`, `FORGE_CODE_GRAPH_DISABLED`) and keeps the hook silent outside of worktree-team sessions.

Why opt-in (not opt-out) for this one: the rest of Forge assumes a single-agent session. The worktree-team pattern is a distinct mode. Forcing directory scoping on single-agent sessions would be noise; activating it per-role is the honest shape.

### 7.3 `agents/hooks/output-schema-check.sh`

Shape: SubagentStop hook. When the generator (by `agent_type`) finishes, read the most recent plan, extract its `## Contract` or `## Output Schema` section, and verify that the files the generator claims to have produced (via trace data or plan checkboxes) are present. Silent on success. Warns on missing.

Does not block — a SubagentStop blocking hook would prevent the pipeline from continuing, and the reviewer is the authoritative check. This hook is an early warning; `contract-check.sh` remains the final check.

### 7.4 `diagnostics/skills/validate-marketplace/SKILL.md`

Shape: slash command that runs a fixed set of checks focused on *pre-commit validation* rather than entropy scanning:
1. `.claude-plugin/marketplace.json` parses as JSON.
2. Every `plugins/*/` directory has a marketplace entry with matching `name` and `source`.
3. Every SKILL.md parses its frontmatter and has `name`, `description`, `disable-model-invocation: true`.
4. Every `plugins/*/hooks/*.sh` is executable.
5. Every SKILL.md fits in the skill-size budget (warn over 2,000 tokens, flag over 5,000).
6. Every `plugins/*/hooks/hooks.json` parses.

Exit with a structured report and an overall `VALID`/`INVALID` verdict. Designed to be run as a pre-commit hook in the future.

Distinct from `/entropy-scan`: entropy-scan focuses on documentation drift and stale state; validate-marketplace focuses on mechanical correctness. Small overlap in checks 3 and 4, kept because both commands should work standalone.

### 7.5 `memory/skills/lineage-audit/SKILL.md`

Shape: slash command that reads `.claude/lineage/ledger.jsonl` and verifies the protocol invariants:
1. File exists and is parseable (one valid JSON per line).
2. `operator` values only from `{propose, assess, commit, reject, rollback}`.
3. `resource` field matches one of the registry slug patterns.
4. Every `commit` entry has a matching earlier `propose` entry (same `resource`, same `version`) and an `assess` with `verdict: pass`.
5. Every `commit` and `rollback` has a snapshot file on disk at `.claude/lineage/versions/<slug>/<prev-or-target>`.
6. No `commit` follows a `reject` for the same resource+version without a new `propose` + `assess`.

Output structured report per entry violating an invariant plus an overall `CLEAN`/`VIOLATIONS: N`.

Does not modify the ledger. Audit only.

---

## 8. Deferred But Documented

These items emerge from the research but are not Tier 1:

**Directory-ownership CLAUDE.md template.** Post 2.2 recommends shipping `CLAUDE.md` fragments per role. The `worktree-team` skill composes these dynamically; pre-authoring templates would be premature until the shape is proven in use. Keep as a file-pack opportunity for future iteration.

**LEARNINGS.md weekly consolidation.** Post 2.3 closes the self-improvement loop with a scheduled consolidation step. Forge's `/trace-evolve` is the analogous function but is manual. Adding a scheduled wrapper is easy once `ScheduleWakeup` / cron patterns are standardized in the maintainer's environment. Deferred.

**`eval.json` per-skill binary criteria.** Posts 2.3, 2.8 propose a structured eval file beside each skill. Forge's evaluator gates achieve the same behavior at the session level rather than the skill level. Skill-level eval files would be useful for a marketplace run at contributor-scale; at single-maintainer scale they are over-engineering.

**Skills-vs-commands rubric documentation.** Post 2.9 deserves a doc page. Deferred because the existing plugins already embody the rubric (every Forge skill is user-invocable with a clear trigger condition); the value is mainly pedagogical.

---

## 9. Verification

- **Report itself.** This document can be re-derived by running `/validate-marketplace` (post-build) against the five new additions. Citation accuracy is preserved through direct links.
- **Plugin count & version churn.** Only `agents`, `diagnostics`, `memory` versions bump; no new plugin folders; marketplace entry count stays at 14.
- **README drift.** After this cycle, README still needs a count update (37 → 49 skills, 49 → ~70 hooks). The `/entropy-scan` Check 1 and `/validate-marketplace` will flag this automatically.
- **No regressions.** All existing hooks remain unchanged. The new hooks are opt-in or silent-on-success by default.

---

## 10. Citations

### 10.1 Primary Sources (mindstudio.ai Claude Code series)

- [Claude Code Agentic Workflow Patterns](https://www.mindstudio.ai/blog/claude-code-agentic-workflow-patterns)
- [Claude Code Agent Teams: Parallel Workflows](https://www.mindstudio.ai/blog/claude-code-agent-teams-parallel-workflows)
- [Agentic Operating System in Claude Code](https://www.mindstudio.ai/blog/agentic-operating-system-claude-code)
- [Claude Code Split-and-Merge Pattern](https://www.mindstudio.ai/blog/claude-code-split-and-merge-pattern-sub-agents)
- [Claude Code Agent Teams: Shared Task List](https://www.mindstudio.ai/blog/claude-code-agent-teams-shared-task-list)
- [Claude Code Opus Plan Mode Token Savings](https://www.mindstudio.ai/blog/claude-code-opus-plan-mode-token-savings)
- [Karpathy LLM Wiki Knowledge Base Pattern](https://www.mindstudio.ai/blog/karpathy-llm-wiki-knowledge-base-pattern)
- [What Are Claude Code Skills](https://www.mindstudio.ai/blog/what-are-claude-code-skills)
- [Claude Skills vs Slash Commands](https://www.mindstudio.ai/blog/claude-skills-vs-slash-commands)

### 10.2 Official Anthropic

- [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces)
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Best Practices for Claude Code](https://code.claude.com/docs/en/best-practices)

### 10.3 Harness Research

- [Building Effective AI Coding Agents](https://arxiv.org/html/2603.05344v1)
- [Natural-Language Agent Harnesses](https://arxiv.org/html/2603.25723v1)
- Autogenesis — *A Self-Evolving Agent Protocol* (Zhang, arXiv:2604.15034, Apr 2026) — backs Forge's ledger protocol

### 10.4 Token Optimization

- [Dynamic Toolsets (Speakeasy)](https://www.speakeasy.com/blog/how-we-reduced-token-usage-by-100x-dynamic-toolsets-v2)
- [CodeAgents Framework](https://arxiv.org/html/2507.03254v1)

### 10.5 Evaluation

- [SWE-bench Leaderboard](https://www.vals.ai/benchmarks/swebench)
- [Scaling agentic evaluation (AI21)](https://www.ai21.com/blog/scaling-agentic-evaluation-swe-bench)

### 10.6 Community Marketplaces

- [Claude Code Plugins Plus Skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills)
- [Claude Night Market](https://github.com/athola/claude-night-market)
- [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)
- [Awesome Claude Plugins](https://github.com/quemsah/awesome-claude-plugins)

### 10.7 MCP & Infrastructure

- [MCP 2026 Roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)
- [CONTINUITY — session state persistence](https://github.com/duke-of-beans/CONTINUITY)

### 10.8 Anti-Patterns & Best Practices

- [Claude Code Gotchas (DoltHub)](https://www.dolthub.com/blog/2025-06-30-claude-code-gotchas/)
- [Learning from Claude Code's own plugins](https://tgvashworth.substack.com/p/learning-from-claude-codes-own-plugins)
- [Agentic checkpoint patterns (hamy.xyz)](https://hamy.xyz/blog/2025-07_ai-checkpointing)

---

## Appendix — Mapping Table (Tier-1 Addition → Research Provenance)

| Addition | Primary source(s) | Secondary support |
|---|---|---|
| `worktree-team` | 2.2 (directory ownership), 2.5 (worktree-per-worker), 2.1 (capability isolation) | 3.4F (subagent coordination), 3.3 (ReAct subagent pattern) |
| `directory-ownership` hook | 2.2 (directory ownership) | 2.5 (claim-lock analog), 3.5 (anti-pattern: two agents editing same file) |
| `output-schema-check` hook | 2.1 (schema discipline), 2.4 (schema validation at merge), 2.8 (binary criteria) | 3.3 (safety schema validation), 3.5 (ambiguous tool design) |
| `validate-marketplace` skill | 3.1 (marketplace schema), 3.4C (plugin integration evals), CLAUDE.md existing checklist | 3.5 (plugin anti-patterns) |
| `lineage-audit` skill | `HARNESS_SPEC.md` §Self-Evolution, `docs/lineage.md` | Autogenesis (arXiv:2604.15034) |

Every Tier-1 addition has ≥1 primary citation. Every rejection has a reason logged in §5.
