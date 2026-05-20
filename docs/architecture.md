# Forge Studio Architecture

Design rationale, component model, hook mechanics. For research citations, see [research.md](research.md). For mechanical invariants, see [HARNESS_SPEC.md](../HARNESS_SPEC.md).

---

## The 8 Harness Components

**Agent = Model + Harness.** Changing only the harness produces a 6x performance gap. These are the 8 levers:

| # | Component | What It Controls | Plugin |
|---|-----------|-----------------|--------|
| 1 | System Prompts | Base behavior and personality | `behavioral-core` |
| 2 | Tool System | What actions the agent can take | `agents` (tool isolation) |
| 3 | Permission System | What the agent is allowed to do | `behavioral-core` (block-destructive) |
| 4 | Context Management | What the model sees each turn | `context-engine` |
| 5 | Memory Architecture | What persists across sessions | `memory` |
| 6 | Multi-Agent Decomposition | How work is split across agents | `agents` (in-repo) + `cross-repo` (parallel work across sibling repos with workspace ledger at `~/.forge-cross-repo/<run-id>/`) |
| 7 | Behavioral Steering | Ongoing course correction | `behavioral-core` (hooks) |
| 8 | Self-Evolution | Auditable propose → assess → commit → rollback over versioned resources | `workflow` + `evaluator` + `memory` (ledger at `.claude/lineage/`) |

Cross-cutting plugins: `evaluator`, `workflow`, `reference`, `traces`, `diagnostics`, `caveman`, `token-efficiency`, `research-gate`, `long-session`, `policy-gateway`.

Component 8 is drawn from *Autogenesis: A Self-Evolving Agent Protocol* (arXiv:2604.15034, Apr 2026). See `docs/self-evolution.md` for the protocol and `HARNESS_SPEC.md` §Self-Evolution Protocol for invariants.

#### Change Contract Requirement

Every harness mutation that passes through the SEPL loop carries a *change contract* — a structured declaration of component, failure mode targeted, predicted improvement, invariants preserved, falsifiable verification command, and rollback steps. The requirement follows arXiv:2605.18747 §5.2.3, which treats harness mutations as changes to a safety-critical runtime and argues each must ship with a falsifiable claim and a revert path.

Enforcement is structural across three operators:

- `/auto-tune-skill` — proposal output includes a `## Change Contract` YAML block with all six required fields.
- `/assess-proposal` — contract check runs before any rubric criterion; missing or incomplete contract blocks the assessment immediately with a quoted field name in the rejection.
- `/commit-proposal` — on commit, copies the contract into `evidence_bundle.contract` in the change manifest, making it durable for future attribution.

The `invariants_preserved` field may reference named invariants from `plugins/forge-meta/POLICY.md` or state free-form invariants — either form is accepted, so proposals are not blocked when POLICY.md has no matching entry.

See [`docs/self-evolution.md` §Change Contracts](self-evolution.md#change-contracts) for the worked lifecycle example.

### Capability Levels (per arXiv:2604.22748)

*Agentic World Modeling* (Chu et al., Apr 2026) defines a three-tier capability ladder for agents that model environmental dynamics:

- **L1 Predictor** — learns one-step local transition operators.
- **L2 Simulator** — composes those operators into multi-step, action-conditioned rollouts that respect domain laws.
- **L3 Evolver** — autonomously revises its own model when predictions fail against new evidence.

Mapping forge-studio's 8 components to this ladder (interpretive — the paper's framework targets world-modeling agents broadly, applied here to harness components):

| Component | Level | Reason |
|---|---|---|
| System Prompts | L1 | Single-turn behavioral steering; no rollout |
| Tool System | L1 | Each tool call is a single step |
| Permission System | L1 | Per-call allow/deny decisions |
| Context Management | L1 → L2 | Per-turn tracking is L1; compaction recovery + plan-mode replay reach L2 |
| Memory Architecture | L1 → L2 | Recall is L1; SEPL-versioned snapshots enable L2 replay |
| Multi-Agent Decomposition | L2 | Planner/generator/reviewer is multi-step, action-conditioned |
| Behavioral Steering | L1 | Per-message rule re-anchor; no self-correction |
| Self-Evolution (SEPL) | L3 | Propose → assess → commit → rollback is the canonical self-correcting loop; `/prediction-audit` closes the L3 prediction-vs-outcome cycle |

The annotation is descriptive, not aspirational — the goal is precise vocabulary, not climbing the ladder for its own sake. Component upgrades go through SEPL like any other harness change.

### TRAE Harness-Engineering Framings (overlays, not replacements)

The 8-component model describes *what* Forge Studio controls. TRAE's "Definitive Guide to Harness Engineering" (2026) provides orthogonal *outcomes* and *mechanics* framings useful for audit and design:

**R.E.S.T. objectives** (outcome axes — use `/rest-audit`):
- **Reliability** — fault recovery (long-session `init.sh` + `claude-progress.txt`), idempotency (SEPL snapshots), graceful degradation (`.claude/safe-mode` flag)
- **Efficiency** — token budgeting (`/timebox`, caveman, `/token-pipeline`), rtk optimizer, code-graph instead of re-reads
- **Security** — `behavioral-core/block-destructive` Layer 5 (safe-mode) + layers 1–4 (patterns), `research-gate`, `policy-gateway` (secrets + injection + sensitive-op audit)
- **Traceability** — `.claude/lineage/ledger.jsonl` (SEPL + policy-block + safe-mode + progress-log), `traces/` JSONL collection, `claude-progress.txt`

**PPAF loop** (agent cycle):
- **Perception** — context-engine, long-session SessionStart surface-progress
- **Planning** — workflow/orchestrate, agents/planner, `/feature-list`, `/living-spec`
- **Action** — agents/generator, evaluator skills
- **Feedback/Reflection** — traces, `/verify` (now executes features.json verify_cmds), `/reflect`, memory, `/rest-audit`

**REPL container model** (harness as deterministic shell around stochastic LLM):
- *Read* — context-engine assembles structured prompt from CLAUDE.md + MCP + turns + memory + progress tail
- *Eval* — PreToolUse hooks intercept tool calls (block-destructive, research-gate, policy-gateway)
- *Print* — PostToolUse hooks wrap outputs as observations (static analysis, traces, thrashing detection)
- *Loop* — workflow orchestrates phase transitions; SubagentStop updates `spec.md` + `features.json`

**State Separation Principle**: Claude Code is treated as a stateless compute unit; all cross-turn state lives in files (`.claude/plans/`, `.claude/spec.md`, `.claude/features.json`, `.claude/lineage/ledger.jsonl`, `.claude/memory/`, `.claude/safe-mode`, `claude-progress.txt`). Forcing the LLM to maintain state via prompt engineering is the anti-pattern.

---

## Three-Layer Model

```text
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
│  │ efficiency    │ │ long-session ││
│  │ policy-       │ │              ││
│  │ gateway       │ │              ││
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

## Forge Hook Deployment

69 hook command registrations across 16 plugins. Hooks fire automatically on events — no commands needed. For the underlying Claude Code event API catalog see [`HARNESS_SPEC.md` §Hook Events Reference](../HARNESS_SPEC.md#hook-events-reference); the tables below describe **what forge actually deploys** at each event.

### Session Lifecycle

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| SessionStart | context-engine | env-bootstrap.sh | OS, memory, languages, tools, git state snapshot |
| SessionStart | context-engine | mcp-instruction-monitor.sh | MCP server token overhead + config injection-pattern scan |
| SessionStart | caveman | caveman-init.sh | Load compressed communication rules |
| SessionStart | behavioral-core | output-style-check.sh | One-time check for unsafe output styles |
| SessionStart | workflow | session-bootstrap.sh | Surface active plan + unchecked items + recent progress |
| SessionStart | long-session | bootstrap-substrate.sh | Idempotently create `.claude/{plans,gate}/`, `.claude/spec.md`, `.claude/features.json` so handoff chain works on first run (opt-out: `FORGE_LONG_SESSION_BOOTSTRAP=0`) |
| SessionStart | long-session | surface-progress.sh | Tail `claude-progress.txt`, `features.json` status, `spec.md` delta, `init.sh` presence |
| SessionStart | rtk-optimizer | rtk-bootstrap.sh | First session: install `rtk` binary + run `rtk init -g`. Subsequent sessions: no-op |
| SessionStart | code-graph | code-graph-bootstrap.sh | Install `code-review-graph` and register MCP server for current repo on first run |
| PreCompact | context-engine | pre-compact-guard.sh | Block compaction when uncommitted work has no progress entry or tasks in-progress |
| PreCompact | context-engine | pre-compact.sh | Save scope, plan, progress, git state to recovery file |
| PreCompact | workflow | pre-compact-handoff.sh | Advisory nudge to run `/progress-log` before auto-compaction |
| PostCompact | context-engine | post-compact.sh | Re-inject scope, plan, tasks, modified files from recovery |
| PostCompact | caveman | caveman-restore.sh | Re-inject compressed communication rules |
| SessionEnd | traces | session-summary.sh | Write session summary to trace file |
| SessionEnd | forge-meta | session-end-digest.sh | Write a ≤10KB AHE-pillar digest (Component/Experience/Decision) to `.claude/sessions/<session-id>-digest.md` |

### Every User Message (UserPromptSubmit)

| Plugin | Hook | What It Does |
|--------|------|-------------|
| behavioral-core | behavioral-anchor.sh | Re-anchor all behavioral rules from `rules.d/` |
| context-engine | track-context-pressure.sh | 5-stage progressive context pressure warnings |
| context-engine | track-system-reminders.sh | Track system-reminder injection patterns |
| context-engine | task-guardian.sh | Remind about incomplete tasks |
| workflow | route-prompt.sh | Agentic router: classify prompt (shell/hybrid/LLM), nudge pattern |
| traces | collect-user-turn.sh | Append `user_turn` JSONL entry (prompt_length, session_id; no content stored) for clarification-timing analysis |
| long-session | budget-trigger.sh | Graduated context-budget advisory at 70/80/90/99% of `CLAUDE_CONTEXT_WINDOW_USED_PCT` |

### Before Tool Use (PreToolUse — 13 hooks, deny-chain)

| Matcher | Plugin | Hook | What It Does |
|---------|--------|------|-------------|
| Bash | behavioral-core | block-destructive.sh | **Block** safe-mode + `rm -rf`, `git push --force`, etc. |
| Edit\|Write | behavioral-core | scope-guard.sh | Warn when editing files outside active scope |
| Edit\|Write | research-gate | require-read-before-edit.sh | **Block** edit/write if file not Read in session (exit 2) |
| Edit\|Write | research-gate | exploration-depth-gate.sh | Warn if insufficient exploration before first edit |
| Edit\|Write | policy-gateway | scan-secrets.sh | **Block** on secret pattern match; ledger `policy-block` |
| Bash\|Edit\|Write | policy-gateway | scan-injection.sh | **Block** on prompt-injection pattern; ledger `policy-block` |
| Bash | evaluator | pre-commit-gate.sh | Warn if plan exists but `/verify` not run |
| Edit\|Write | agents | directory-ownership.sh | Worktree-team scope guard (opt-in: `FORGE_DIRECTORY_OWNERSHIP=1`) |
| Edit\|Write | forge-meta | pre-edit-guard.sh | **Block** edits to protected verifier paths when `FORGE_META_EVOLVE=1`; human edits pass silently |
| Edit\|Write | long-session | spec-drift-detect.sh | Detect drift between active plan and HEAD on edit attempts |
| (any) | diagnostics | doom-loop.sh | Fingerprint last 20 tool calls; warn at ≥3 identical (exit 1), **block** at ≥5 (exit 2); delete `/tmp/forge-doom-<session>` to override |
| Read | token-efficiency | track-duplicate-reads.sh | Warn on duplicate reads |
| Edit\|Write | context-engine | belief-snapshot.sh | Record sha256 of file before edit; feeds `/belief-audit` drift detection |

### After Tool Use (PostToolUse — 21 hooks)

| Matcher | Plugin | Hook | What It Does |
|---------|--------|------|-------------|
| Write\|Edit | behavioral-core | self-review-nudge.sh | "Does this change do ONLY what was asked?" |
| Read | context-engine | check-large-file.sh | Warn on files >500 lines |
| Bash\|Grep | context-engine | warn-tool-truncation.sh | Warn on large output or near-truncation |
| Edit\|Read | context-engine | track-edits.sh | Track edits per file; warn after 3 without re-reading |
| Edit | context-engine | detect-thrashing.sh | Detect thrashing (5+ edits same file, oscillating regions) |
| EnterPlanMode | context-engine | plan-mode-enter.sh | Inject plugin-aware plan mode guidance |
| (any) | context-engine | consecutive-failure-reset.sh | Reset consecutive failure counter on success |
| Edit\|Write | context-engine | belief-verify.sh | Record post-edit sha256; new baseline for future `/belief-audit` calls |
| Write\|Edit (.php) | evaluator | php-static-analysis.sh | Run PHPStan on changed file |
| Write\|Edit (.js/.ts) | evaluator | js-static-analysis.sh | Run tsc + ESLint on changed file |
| Edit\|Write | evaluator | test-nudge.sh | Nudge to run tests after every 3rd edit |
| Bash | evaluator | test-nudge-reset.sh | Reset test-nudge counter when tests detected |
| Bash | evaluator | filter-test-output.sh | Replace verbose passing test output with summary |
| Edit\|Write | policy-gateway | audit-sensitive-ops.sh | Audit writes to `.env` / `secrets/` / key files; ledger `sensitive-op-audit` |
| Edit\|Write | policy-gateway | suggest-harden.sh | Suggest hardening when touching auth/permission code; ledger advisory |
| Bash | memory | post-commit-prompt.sh | After `git commit`, prompt for memory-worthy patterns from the change |
| Read | research-gate | track-file-reads.sh | Record file read for edit gate |
| Read\|Grep\|Glob | research-gate | track-exploration.sh | Track exploration depth |
| Write\|Edit | traces | collect-file-trace.sh | Log file change to session trace |
| Bash | traces | collect-bash-trace.sh | Log command, exit code, output to session trace |
| Bash | code-graph | code-graph-update.sh | Refresh graph after `git commit/merge/rebase/pull/checkout/reset/cherry-pick` |

### Failure & Task Events

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| PostToolUseFailure | context-engine | consecutive-failure-guard.sh | Warn at `FORGE_FAILURE_THRESHOLD`; write `.claude/safe-mode` + ledger at `FORGE_SAFE_MODE_THRESHOLD` |
| PostToolUseFailure | traces | collect-failure-trace.sh | Log tool failures to session trace |
| TaskCreated¹ | context-engine | task-guardian-log.sh | Log task for progress guardian |
| TaskCompleted¹ | evaluator | task-completion-gate.sh | Warn if task marked done without verification evidence |
| StopFailure | traces | log-stop-failure.sh | Log API errors and rate limits to session trace |

¹ `TaskCreated` and `TaskCompleted` are agent-teams events — they only fire when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set. Without that env var, these two hooks are inert.

### Agent Dispatch (SubagentStart)

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| SubagentStart | agents | contract-reread.sh | Extract `## Contract` from the most-recent plan file and write it to `.claude/state/active-contract.md` so the subagent gets a fresh copy rather than a decayed in-context version; exit 1 (warn) if no plan or no contract |

### Agent Lifecycle

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| SubagentStop | agents | contract-check.sh | Warn if sprint contract criteria not verified by reviewer |
| SubagentStop | agents | output-schema-check.sh | Warn if generator finished without producing declared artifacts |
| SubagentStop | workflow | after-subagent.sh | Nudge next phase (planner→generator→reviewer→/verify); append spec.md delta; flip features.json `F<n>` to done |
| SubagentStop | evaluator | auto-verify.sh | Emit structured-gradient signal (Dimension/Direction/Magnitude) for generator/reviewer stops; PASS when `gate/features.json` all passing, FAIL otherwise; disable with `FORGE_AUTO_VERIFY=0` |
| SubagentStop | forge-meta | manifest-writer.sh | Append one change-manifest entry to `.claude/evolution/change_manifest.jsonl` when the agent emits a `change_manifest:` marker or git shows recent uncommitted changes |

### Change-Manifest Entry Format

Each line in `.claude/evolution/change_manifest.jsonl` is one JSON object. The schema is backward-compatible: legacy entries (only the first six fields) continue to parse alongside v2 entries. Readers tolerate missing fields.

```jsonc
{
  // Envelope — auto-populated by manifest-writer.sh
  "id":            "chg-<unix-epoch>-<random6hex>",
  "iso_timestamp": "2026-05-20T10:00:00Z",
  "session_id":    "s-xyz",
  "agent_type":    "generator",

  // Change context — required
  "type":          "skill-edit",
  "description":   "extend change-manifest schema",

  // Change context — optional legacy fields
  "files":              "plugins/forge-meta/skills/change-manifest/SKILL.md",
  "failure_pattern":    "schema too narrow for attribution",
  "predicted_fixes":    "downstream attribution now possible",
  "risk_tasks":         "T3 convergence depends on new fields",
  "constraint_level":   "soft",
  "why_this_component": "forge-meta owns the evolution ledger",

  // Transactional state — optional, strongly recommended for non-trivial changes
  "read_set":  ["plugins/forge-meta/skills/change-manifest/SKILL.md"],
  "write_set": ["plugins/forge-meta/skills/change-manifest/SKILL.md"],
  "assumptions":          ["append-manifest.sh omit-empty logic handles all new fields"],
  "verifier_obligations": ["python3 -c \"import json; [json.loads(l) for l in open('.claude/evolution/change_manifest.jsonl')]\""],
  "rollback_handle":      "git revert HEAD",

  // Evidence bundle — optional sub-object; emit when at least one field is known
  "evidence_bundle": {
    "checks_run":           ["json-parse", "hook-exit-code"],
    "assumptions_preserved":["append-manifest.sh omit-empty logic handles all new fields"],
    "untested_regions":     ["post-compact behavior"],
    "remaining_risks":      ["downstream skills unaware of new fields"]
  }
}
```

**Backward compatibility**: readers written before the transactional fields existed continue to work — missing fields produce `None` / empty on access. New writers should emit at minimum `evidence_bundle.checks_run` and either `untested_regions` or `remaining_risks`; an absent `evidence_bundle` is treated as suspect by failure-attribution tooling.

The `evidence_bundle` concept follows the evidence-bundle pattern from arXiv:2605.18747 §5.2.1, which argues that each agent action should carry the evidence it was based on so that diagnosis and replay are possible without re-running the full session.

For contributor guidance see [`docs/transactional-manifest.md`](transactional-manifest.md).

### Turn Completion

| Event | Plugin | Hook | What It Does |
|-------|--------|------|-------------|
| Stop | workflow | turn-gate.sh | Every N turns: remind about unchecked plan items and context pressure |

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

Forge Studio uses `command`-type hooks exclusively — deterministic, fast, cheap. The full handler-type table (`command` / `prompt` / `agent` / `http`, with execution semantics and use cases) lives in [`HARNESS_SPEC.md` §Hook Handler Types](../HARNESS_SPEC.md#hook-handler-types).

The `prompt` and `agent` types enable inferential hooks but cost tokens on every firing. Reserve these for periodic deep analysis, not per-tool checks.

---

## Why Hooks Beat Instructions

| Mechanism | Compliance | Why |
|-----------|-----------|-----|
| CLAUDE.md instructions | ~70% | Diluted over long conversations as attention drifts |
| Hooks (event-driven) | ~100% | Re-injected at decision points; model can't "forget" |

Forge Studio uses hooks for enforcement, skills for guidance. Anything that must always happen goes in a hook. Anything opt-in goes in a skill.

---

## Behavioral Rules (`rules.d/`)

14 rules in `plugins/behavioral-core/hooks/rules.d/`. Each `.txt` file = one behavioral rule. Re-injected every message via `behavioral-anchor.sh`.

| # | Rule | Purpose |
|---|------|---------|
| 10 | tone | No sycophancy, no filler, lead with substance |
| 25 | brevity | 25 words between tools, 100 word responses |
| 30 | intellectual-honesty | Challenge own work, admit uncertainty |
| 35 | no-code-narration | No what-comments, no changelog notes in source |
| 40 | solve-underlying-goal | Read intent, name inferred preconditions before coding |
| 45 | clarify-goal-before-acting | Surface goal/scope ambiguity early — one targeted question, not mid-way pivots |
| 50 | faithful-reporting | Report outcomes accurately, no false claims |
| 55 | evidence-before-claims | Attach proof to every "done / fixed / passing" claim |
| 60 | minimal-changes | Fix the bug only, no scope creep |
| 65 | deliberation-suppression | Don't reach for /ultrathink etc on polluted context — CoT can amplify the failure pattern (arXiv:2605.08060) |
| 70 | confidence-escalation | When confidence low, escalate (/safe-mode, /verify) rather than guess and act |
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

### Pooled dispatch

When the planner enumerates N≥3 independent files, `/dispatch` scales the reviewer layer horizontally: N parallel reviewer subagents (each scoped to one file via `target_file:`) plus one aggregator reviewer that merges findings across all files. The cap is N=5 to bound context overhead. Below N=3, the standard single-reviewer flow applies. The aggregator's role is distinct from per-file reviewers: it deduplicates, surfaces cross-file inconsistencies, and emits a unified verdict — it does not re-read source files. See [Adaptive Reviewer Pool](agentic-workflow.md#adaptive-reviewer-pool) for the full decision sequence.

---

## Progressive Context Management

5-stage warnings as context fills:

| Stage | Action |
|-------|--------|
| Notice (~50%) | Re-read files before editing |
| Moderate (~65%) | Consider /compact |
| Elevated (~75%) | Recommend compacting now |
| High (~85%) | Strongly recommend /progress-log |
| Critical (~92%) | /progress-log now or risk incoherent output |

Configurable via `FORGE_CONTEXT_STAGE1`-`STAGE5` (message counts) or `FORGE_CONTEXT_PCT1`-`PCT5` (percentages).

### Belief-State Audit

After compaction, the model's internal representation of file contents can diverge from disk reality — particularly when other agents, hooks, or external processes wrote files between turns. arXiv:2605.18747 §4.3 (SyncMind) formalizes this as `|Bk − Sk|`: the gap between the agent's belief `Bk` and the actual system state `Sk`. Unchecked, it is the root cause of stale-belief bugs in long sessions.

Three-step flow:

```
Edit (PreToolUse)  ──► sha256 ──► .claude/state/belief.jsonl {op: "pre"}
Edit succeeds       ──► Claude's internal belief = post-edit state
PostToolUse        ──► sha256 ──► .claude/state/belief.jsonl {op: "post"}

/belief-audit       ──► re-sha256 disk  ──► diff vs latest stored signature ──► drift report
```

- Snapshots are appended by `belief-snapshot.sh` (PreToolUse) and `belief-verify.sh` (PostToolUse). Both are async and exit 0 always — they observe, never block.
- `/belief-audit [N]` reads the N most-recently-edited paths, re-hashes each, and emits a Markdown drift report. Exit 1 if any file has changed since last snapshot. Fires automatically on PostCompact via `post-compact-belief-audit.sh`.
- State lives in `.claude/state/belief.jsonl` (JSONL, one entry per snapshot).

See [`docs/belief-audit.md`](belief-audit.md) for the user-facing guide.

---

## Context Preservation Across Compaction

arXiv:2605.18747 §3.2.6 identifies compaction as the point where bare prose summaries silently discard the highest-signal items — failing test names, stack frames, suspect file paths. The structured briefing emitted by `forward-briefing.sh` (PreCompact) and re-injected by `post-compact-recovery.sh` (PostCompact) preserves exactly those items in a YAML schema with four fields:

| Field | Source | What it carries |
|-------|--------|-----------------|
| `open_failures` | `~/.claude/traces/*.jsonl` | Last 5 non-zero-exit tool calls: command, stack preview, log path |
| `recent_edits` | `.claude/state/belief.jsonl` | Last 10 unique paths touched this session |
| `pending_verifications` | `.claude/evolution/change_manifest.jsonl` | `verifier_obligations` from manifest entries with empty `evidence_bundle.checks_run` |
| `belief_snapshots` | `.claude/state/belief.jsonl` | Last sha256 per path — lets the post-compact turn detect drift before re-editing |

**Prose vs structured — what the model sees after a long debugging session:**

```
# v1 prose (pre-T8):
"Context compacted. You were editing auth middleware and tests were failing."

# v2 structured (T8):
open_failures:
  - test: "pytest tests/auth/test_middleware.py::test_token_refresh"
    stack_top: "AssertionError: expected 401, got 500 (line 47)"
    log_path: "/home/.claude/traces/2026-05-20-abc1.jsonl"
recent_edits:
  - "/app/Http/Middleware/TokenAuth.php"
  - "tests/auth/test_middleware.py"
pending_verifications:
  - "pytest tests/auth/ -x"
belief_snapshots:
  - path: "/app/Http/Middleware/TokenAuth.php"
    sha256: "a3f1b2..."
```

The structured form lets the post-compact turn re-read exactly the right files and re-run exactly the right verification — without asking the user to reconstruct what was happening.

`pre-compact.sh` / `post-compact.sh` still handle scope, plan pointers, git state, and task-guardian tasks. The new hooks add provenance without replacing the existing recovery flow. See [`docs/compaction-briefing.md`](compaction-briefing.md) for the user-facing guide.

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

## Sprint Contract and Convergence

Every non-trivial sprint plan should declare two things:

1. **`## Contract`** — what must be true after the sprint (testable criteria, one per bullet).
2. **`## Convergence`** — when the sprint is done (machine-checkable shell command).

The Contract is checked by the reviewer and `/verify` against each criterion's evidence. Convergence is checked by `convergence-check/scripts/check.sh` — a `criterion` shell command that exits 0 when the sprint is complete.

Without a declared convergence criterion, sprint termination is `implicit` (user judgment). Implicit is fine for one-shot edits and exploration. For multi-session sprints, implicit loses falsifiability: the user's memory of what "done" means at the start may drift from what the implementation actually produced.

The six types from arXiv:2605.18747 §4.3.2 — test-gated, security-gated, performance-gated, score-based, consensus, hybrid — map to Forge Studio criterion patterns:

| Type | Forge Studio criterion example |
|---|---|
| test-gated | `"./vendor/bin/pest --filter=BillingUpgrade"` |
| security-gated | `"bash plugins/policy-gateway/hooks/secrets-scan.sh ."` |
| performance-gated | `"bash scripts/bench.sh \| awk '/p99/{exit($2>200)}'"` |
| score-based | `"bash plugins/evaluator/skills/score-rubric/scripts/score.sh \| grep PASS"` |
| consensus | `"test -f .claude/gate/reviewer-1.pass -a -f .claude/gate/reviewer-2.pass"` |
| hybrid | `"bash run-tests.sh && python3 -c \"import json; json.load(open('.claude-plugin/marketplace.json'))\""` |

`/verify` quotes the criterion output verbatim and refuses "done" if `met: false`. `/status` shows the current criterion state in its situational report. See [docs/convergence.md](convergence.md) for the full reference.

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

See [`HARNESS_SPEC.md` §Glossary](../HARNESS_SPEC.md#glossary) for the canonical term definitions.
