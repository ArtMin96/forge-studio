# Forge Studio — Harness Specification

> Canonical specification of mechanical invariants and architectural primitives. Machine-readable section headers enable automated validation via `/entropy-scan`. Last updated: 2026-04-14.

## Research Basis

Synthesized from 10 industry sources (2026): Anthropic Engineering, Fowler/Thoughtworks (Böckeler), HumanLayer, NxCode, InfoQ, Productboard, Penligent, Octopus Deploy, Sewak, Chachamaru. Full synthesis: `.claude/plans/curious-bubbling-biscuit-agent-afbc4fea3c7f788d5.md`.

---

## Architectural Primitives

13 building blocks that appear across multiple sources, abstracted from domain-specific implementations:

| # | Primitive | What It Does | Forge Studio Implementation |
|---|-----------|-------------|---------------------------|
| 1 | Planner | Decomposes intent into structured, bounded work units | `agents/planner` (read-only) |
| 2 | Generator/Worker | Executes bounded work with restricted tool access | `agents/generator` (read-write) |
| 3 | Evaluator/Verifier | Independently assesses output against criteria (never self-evaluation) | `evaluator/adversarial-reviewer` + `/verify` + `/challenge` + `/assess-proposal` |
| 4 | Context Firewall | Isolates sub-task context from parent orchestration context | Sub-agents with `context: fork` |
| 5 | Handoff Artifact | Structured file-based state transfer between agents/phases | `.claude/handoffs/`, `.claude/plans/` |
| 6 | Guide (Feedforward) | Pre-execution instructions, conventions, architectural rules | `behavioral-core/rules.d/*.txt` (8 rules), CLAUDE.md |
| 7 | Sensor (Feedback) | Post-execution observation (computational or inferential) | Static analysis hooks, `/gate-report` |
| 8 | Policy Kernel | External enforcement of action classification (allow/deny/defer/ask) | `behavioral-core/block-destructive.sh`, `research-gate/require-read-before-edit.sh`, `research-gate/exploration-depth-gate.sh`, settings.json deny list |
| 9 | Entropy Collector | Periodic scanning agent restoring codebase invariants | `diagnostics/entropy-scan` |
| 10 | Progressive Disclosure | Context loaded on-demand, not upfront | `disable-model-invocation: true` on all skills |
| 11 | Sprint Contract | Negotiated agreement on done-criteria before execution begins | `## Contract` in planner output, `/contract` skill |
| 12 | Trace Telemetry | Persistent log of all agent actions for audit and sync | `traces/` JSONL collection |
| 13 | Self-Evolution Loop | Auditable propose → assess → commit operator over versioned resources, with rollback | `workflow/evolve` + `workflow/commit-proposal` + `workflow/rollback` + `evaluator/assess-proposal`; ledger at `.claude/lineage/ledger.jsonl` |

---

## Invariant: Plugin Structure

Every plugin must follow this directory layout:

```
plugins/{name}/
├── hooks/                    # Optional
│   ├── hooks.json            # Event registrations (required if hooks/ exists)
│   └── *.sh                  # Hook scripts (must be chmod +x)
├── skills/                   # Optional
│   └── {skill-name}/
│       └── SKILL.md          # YAML frontmatter + instructions
├── agents/                   # Optional
│   └── {agent-name}.md       # YAML frontmatter + instructions
└── ...                       # Other plugin-specific files
```

**Validation**: Every `plugins/*/` directory must appear in `.claude-plugin/marketplace.json`. Every `hooks/*.sh` must have executable permission.

## Invariant: SKILL.md Frontmatter

Every SKILL.md must contain YAML frontmatter. Required fields enforce zero-cost progressive disclosure.

```yaml
---
name: skill-name              # Required. Lowercase, hyphenated, max 64 chars.
description: One-line purpose  # Required (recommended). What invoking this skill does.
disable-model-invocation: true # Required for Forge Studio. Zero cost until invoked.
---
```

### All Supported Skill Fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Display name. Lowercase letters, numbers, hyphens. Max 64 chars. |
| `description` | Recommended | What the skill does. Claude uses this for auto-invocation. Truncated at 1,536 chars in skill listing. |
| `when_to_use` | No | Additional trigger context. Appended to `description`, counts toward 1,536-char cap. |
| `disable-model-invocation` | Forge Studio: Yes | `true` prevents Claude from auto-loading. Zero cost until manually invoked. |
| `user-invocable` | No | `false` hides from `/` menu. Use for background knowledge Claude should auto-load but users shouldn't invoke. |
| `allowed-tools` | No | Tools Claude can use **without asking permission** while skill is active. Space-separated string or YAML list. Does NOT restrict — all tools remain callable. |
| `argument-hint` | No | Hint shown during autocomplete (e.g., `[issue-number]`). |
| `model` | No | Override session model when skill is active. |
| `effort` | No | Override session effort level: `low`, `medium`, `high`, `max` (Opus 4.6 only). |
| `context` | No | `fork` runs in isolated subagent context. Skill content becomes the subagent prompt. |
| `agent` | No | Subagent type for `context: fork`. Built-in (`Explore`, `Plan`, `general-purpose`) or custom. |
| `paths` | No | Glob patterns limiting auto-activation (e.g., `*.php`). Comma-separated or YAML list. |
| `hooks` | No | Skill-scoped lifecycle hooks. Same format as hooks.json. Scoped to skill lifetime. |
| `shell` | No | Shell for inline `!command` blocks: `bash` (default) or `powershell`. |

**Compaction survival**: Invoked skills survive compaction with first 5,000 tokens per skill. Shared budget of 25,000 tokens across all invoked skills. Most recently invoked skills get priority; older skills may be dropped.

**Validation**: `name`, `description`, and `disable-model-invocation: true` must be present in every Forge Studio SKILL.md.

## Invariant: Hook Exit Codes

Hook scripts communicate via shell exit codes:

| Exit Code | Meaning | When to Use |
|-----------|---------|------------|
| 0 | Info/JSON | Inject information into context. Stdout parsed for JSON. Silent when nothing to report. |
| 1 | Warning | Non-blocking alert. First line of **stderr** displayed. Stdout goes to debug log only. |
| 2 | Block | Prevent action. **Valid for PreToolUse and PreCompact hooks.** For PreToolUse: prevents tool execution (stderr fed to Claude). For PreCompact: prevents context compaction. |

**Preferred approach for PreToolUse blocking**: Exit 0 with JSON `permissionDecision` output instead of exit 2. Provides richer feedback via `permissionDecisionReason` and `additionalContext`.

```bash
# JSON deny — PreToolUse (preferred)
jq -n --arg reason "Explanation" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
```

**PreCompact blocking** (v2.1.105): Hooks can prevent compaction via exit 2 or JSON decision. Use when critical state would be lost. Async hooks cannot block — the hook must be synchronous.

```bash
# JSON block — PreCompact
jq -n --arg reason "Explanation" '{
  decision: "block",
  reason: $reason
}'
exit 0

# Or simply: exit 2 (stderr shown to model)
```

**Validation**: No hook outside `PreToolUse`/`PreCompact` should exit with code 2.

## Invariant: Hook Output Pattern

Hooks must be **silent on success, verbose on failure**. When a hook has nothing to report, it exits 0 with no stdout. Output is only produced when there's actionable information.

**Rationale** (HumanLayer, 2026): "Success is silent, and only failures produce verbose output." Passing results flood context and cause hallucinations.

**Validation**: Hooks should not produce stdout when the condition they check is satisfied/normal.

## Hook Events Reference

28 hook events organized by lifecycle. Forge Studio plugins use a subset; all are available.

### Session Lifecycle
| Event | Matcher | Description |
|---|---|---|
| `SessionStart` | Session source (`startup`, `resume`, `clear`, `compact`) | Session begins or resumes |
| `SessionEnd` | End reason (`clear`, `resume`, `logout`) | Session terminates |
| `InstructionsLoaded` | Load reason (`session_start`, `compact`, `include`) | CLAUDE.md or `.claude/rules/` loaded |

### Per-Turn Events
| Event | Matcher | Description |
|---|---|---|
| `UserPromptSubmit` | None (always fires) | User submits prompt, before Claude processes |
| `Stop` | None | Claude finishes responding |
| `StopFailure` | Error type (`rate_limit`, `server_error`, `authentication_failed`, `max_output_tokens`) | Turn ends due to API error |

### Tool Execution Events
| Event | Matcher | Description |
|---|---|---|
| `PreToolUse` | Tool name (`Bash`, `Edit\|Write`, `mcp__*`) | Before tool executes. Can block (exit 2) or modify input (`updatedInput`). |
| `PostToolUse` | Tool name | After successful tool call |
| `PostToolUseFailure` | Tool name | After failed tool call |
| `PermissionRequest` | Tool name | Permission dialog appears. Can auto-allow/deny. |
| `PermissionDenied` | Tool name | Auto mode classifier denies tool. Can retry. |

### Agent/Team Events
| Event | Matcher | Description |
|---|---|---|
| `SubagentStart` | Agent type | Subagent spawned |
| `SubagentStop` | Agent type | Subagent finished |
| `TeammateIdle` | None | Agent team teammate about to idle |
| `TaskCreated` | None | Task created via TaskCreate |
| `TaskCompleted` | None | Task marked as completed |

### Context & Configuration Events
| Event | Matcher | Description |
|---|---|---|
| `PreCompact` | Trigger (`manual`, `auto`) | Before compaction. Can block. |
| `PostCompact` | Trigger | After compaction completes |
| `ConfigChange` | Config source (`user_settings`, `project_settings`, `skills`) | Config file changes mid-session |
| `CwdChanged` | None | Working directory changes |
| `FileChanged` | Filenames (`\.envrc\|\.env`) | Watched file changes on disk |

### Worktree Events
| Event | Matcher | Description |
|---|---|---|
| `WorktreeCreate` | None | Worktree being created. Non-zero exit aborts. |
| `WorktreeRemove` | None | Worktree being removed |

### MCP & Notification Events
| Event | Matcher | Description |
|---|---|---|
| `Elicitation` | MCP server name | MCP server requests user input |
| `ElicitationResult` | MCP server name | User responds to MCP elicitation |
| `Notification` | Type (`permission_prompt`, `idle_prompt`) | Claude Code sends notification |

## Hook Handler Types

Four handler types, each with different capabilities:

| Type | Description | Blocks? | Key Field |
|---|---|---|---|
| `command` | Shell script execution | Yes (exit 2) | `command` |
| `prompt` | LLM-driven evaluation | No | `prompt` (with `$ARGUMENTS` placeholder) |
| `agent` | Agent-type evaluation | No | `prompt` + optional `model` |
| `http` | Webhook POST | No | `url` + optional `headers` |

### Hook Handler Fields

Common fields (all types): `type`, `if`, `timeout`, `statusMessage`, `once`.

Command-specific: `command`, `async`, `asyncRewake`, `shell`.

| Field | Type | Description |
|---|---|---|
| `if` | string | Permission rule syntax filter (e.g., `Edit(*.php)`). Tool events only. |
| `once` | boolean | Run only once per session, then removed. Skills only. |
| `async` | boolean | Run in background without blocking. |
| `asyncRewake` | boolean | Run async; wake Claude on exit 2 with stderr. Implies `async`. |
| `shell` | string | `bash` (default) or `powershell`. |
| `statusMessage` | string | Custom spinner message while hook runs. |

## Invariant: Consecutive-Error Escalation

Track consecutive tool failures. After 3 consecutive failures without a successful tool use, inject a deterministic warning to break retry loops.

**Rationale** (12-Factor Agent, HumanLayer, 2026): Agents with 50+ turns commonly lose focus and repeat failed approaches. Deterministic escalation after 2-3 failures prevents infinite retry loops.

**Validation**: `PostToolUseFailure` hook must track consecutive count, warn at threshold, reset on `PostToolUse` success.

## Invariant: Skill Size Budget

Skills should stay under 5,000 tokens (~20,000 chars) to survive compaction intact. Skills under 2,000 tokens (~8,000 chars) are ideal. Skills exceeding 5,000 tokens risk being truncated or dropped after compaction.

**Rationale**: Official docs confirm skills survive compaction with first 5,000 tokens per skill, shared 25,000-token budget. Oversized skills accelerate context rot.

**Validation**: `/entropy-scan` should flag SKILL.md files exceeding ~8,000 characters.

## Invariant: Agent Tool Boundaries

Agent capability isolation prevents error propagation between phases:

| Agent Role | `tools` | Cannot Do |
|-----------|---------|-----------|
| Planner | Read, Glob, Grep, Bash | Modify files (no Write, Edit) |
| Generator | Read, Write, Edit, Bash, Glob, Grep | Skip planning phase |
| Reviewer | Read, Grep, Glob, Bash | Modify files (no Write, Edit) |

**Rationale** (Anthropic, 2026): "When asked to evaluate work they've produced, agents tend to respond by confidently praising the work — even when quality is obviously mediocre." Capability isolation ensures reviewers evaluate honestly rather than rubber-stamping by editing.

**Validation**: Agent `.md` frontmatter `tools` must match these boundaries.

### Agent Frontmatter Reference

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Unique identifier. Lowercase, hyphenated. |
| `description` | Yes | When Claude should delegate to this agent. |
| `tools` | No | Allowlist of tools. Inherits all if omitted. Use `Agent(type)` to restrict subagent spawning. |
| `disallowedTools` | No | Denylist. Applied before `tools`. Removes from inherited or specified pool. |
| `model` | No | `sonnet`, `opus`, `haiku`, full model ID, or `inherit` (default). |
| `effort` | No | Override effort: `low`, `medium`, `high`, `max` (Opus 4.6 only). |
| `maxTurns` | No | Cap on agentic turns before agent stops. |
| `skills` | No | Skills preloaded into agent context at startup (full content, not just metadata). |
| `mcpServers` | No | Per-agent MCP server access. Reference by name or inline definition. |
| `hooks` | No | Agent-scoped lifecycle hooks. Same format as hooks.json. **Not available in plugin agents.** |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local`. Cross-session learning. |
| `background` | No | `true` to always run as background task. |
| `isolation` | No | `worktree` for isolated git worktree copy. Auto-cleaned if no changes. |
| `color` | No | Display color: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`. |
| `initialPrompt` | No | Auto-submitted first turn when running as main agent (`--agent`). |
| `permissionMode` | No | Override permission mode. **Not available in plugin agents.** |

### Plugin Agent Security Restrictions

Plugin subagents do NOT support `hooks`, `mcpServers`, or `permissionMode`. These fields are **silently ignored** when loading agents from a plugin. This prevents untrusted plugins from escalating permissions or injecting hooks into the runtime.

If a plugin agent needs these capabilities, users must copy the agent file to `.claude/agents/` or `~/.claude/agents/`.

## Invariant: Evaluation Separation

Evaluation and generation must be performed by **different agents**. Self-evaluation is unreliable.

This manifests as:
- Planner/Generator/Reviewer are separate agents with separate tool sets
- The `adversarial-reviewer` agent is read-only (cannot modify what it evaluates)
- The `/verify` skill produces evidence, not assertions
- The evaluation gate hook warns when committing planned work without verification

**Validation**: No agent definition should combine Write/Edit tools with a "review" or "evaluate" role.

## Invariant: Marketplace Registration

Every plugin directory under `plugins/` must have a corresponding entry in `.claude-plugin/marketplace.json` with:
- `name` matching the directory name
- `source` pointing to `./plugins/{name}`
- `category`, `tags`, `version`, `description` all present

**Validation**: Set of `plugins/*/` directories must equal set of marketplace.json `name` entries.

## Invariant: Token Budget

Hook output must stay within token budget to avoid flooding context:

| Hook Type | Max Output | Rationale |
|-----------|-----------|-----------|
| SessionStart | ~500-800 tokens (one-time) | Environment bootstrap, startup checks |
| UserPromptSubmit | ~200-300 tokens per message | Behavioral re-injection |
| PreToolUse | ~50-100 tokens | Decision-point warnings |
| PostToolUse | ~100-200 tokens | Analysis results, warnings |
| PreCompact/PostCompact | ~200-300 tokens | State preservation/restoration |

Agent markdown should stay under ~100 lines (Octopus, 2026).

---

## Sprint Contract Protocol

When using the Planner → Generator → Reviewer pipeline:

### 1. Planner Writes Contract

The planner's output must include a `## Contract` section:

```markdown
## Contract
What the generator must produce:
- [ ] {Criterion 1 — must be testable, not vague}
- [ ] {Criterion 2}
Verification method: {specific command or check}
```

### 2. Generator Confirms Contract

Before writing any code, the generator:
1. Invokes `/contract` to mechanically Read the plan file (prevents context decay)
2. Confirms each criterion is understood and achievable
3. If any criterion is ambiguous → STOP and report

### 3. Reviewer Validates Compliance

The reviewer's first check (before correctness, security, conventions) is:
- Does the implementation satisfy every criterion in the `## Contract` section?
- Is the verification method actually runnable?
- Were criteria marked complete that shouldn't be?

---

## Evaluation Gate Protocol

A hook-enforced nudge to run `/verify` before committing planned work.

**Mechanism**:
1. `pre-commit-gate.sh` fires on `git commit`
2. Checks if an active plan exists in `.claude/plans/`
3. Checks if `~/.claude/evaluation-gate.flag` contains the current plan name
4. Plan exists + gate not cleared → exit 1 (warn)
5. No active plan → exit 0 (silent — quick fixes bypass gate)

**Clearing the gate**: `/verify` writes the plan name to `~/.claude/evaluation-gate.flag` when verdict is `VERIFIED: Yes`.

**Configuration**: Set `FORGE_EVALUATION_GATE` to `"0"` in settings.json to disable.

---

## Entropy Management Protocol

Periodic scanning to detect drift between documentation and reality.

**Nine checks**:

| # | Check | What It Validates |
|---|-------|------------------|
| 1 | Plugin count drift | README header counts vs actual directories/skills/hooks |
| 2 | Marketplace registration gap | marketplace.json entries vs `plugins/` directories |
| 3 | SKILL.md frontmatter completeness | Required fields: name, description, disable-model-invocation |
| 4 | Hook script executability | All `plugins/*/hooks/*.sh` have `chmod +x` |
| 5 | Memory staleness | `.claude/memory/` topic files with dates > 90 days |
| 6 | Invariant compliance | Plugin structure rules from this spec |
| 7 | Skill token weight | SKILL.md files exceeding 2,000-token compaction-safe ceiling |
| 8 | Rule provenance | `rules.d/*.txt` entries declare an `# origin:` header (advisory) |
| 9 | Tool-menu inflation | Agent/skill tool lists within `FORGE_TOOL_MENU_MAX` (default 10) |

**Invocation**: `/entropy-scan` (manual, zero-cost until invoked)

**Output**: Structured report showing pass/fail per check with proposed fixes. No writes — report only.

---

## Self-Evolution Protocol

Source: *Autogenesis: A Self-Evolving Agent Protocol* (Wentao Zhang, arXiv:2604.15034, Apr 2026). Protocol detail: `docs/lineage.md`.

Two layers:
- **RSPL** (Resource Substrate Protocol Layer) — resources the loop may touch: rules, skills, hooks, memory topics, env vars. Each resolves to a stable slug.
- **SEPL** (Self Evolution Protocol Layer) — four operators over those resources: `propose`, `assess`, `commit`, `rollback`. Every operator appends to an append-only ledger.

### Resource Slug Registry

| Kind | Slug | On-disk path |
|---|---|---|
| Rule | `rules.d/<f>` | `plugins/behavioral-core/hooks/rules.d/<f>` |
| Skill | `skills/<plugin>/<name>` | `plugins/<plugin>/skills/<name>/SKILL.md` |
| Hook | `hooks/<plugin>/<script>` | `plugins/<plugin>/hooks/<script>` |
| Memory topic | `memory/topics/<slug>` | `.claude/memory/topics/<slug>.md` |
| Env var | `env/<VAR>` | `.claude/settings.json` key `env.<VAR>` |

Adding a new kind requires amending this table and `docs/lineage.md`.

### Ledger Invariants

- Location: `.claude/lineage/ledger.jsonl`. One JSON object per line. Append-only.
- Every `commit` entry has a matching earlier `propose` and `assess` (verdict pass) on the same resource + target version.
- Every `commit` and `rollback` has a snapshot file at `.claude/lineage/versions/<slug>/<prev-or-target>`.
- `reject` entries prevent a given proposal artifact from being re-committed without a new propose+assess cycle.

### Operator Ownership

| Operator | Skill | Plugin |
|---|---|---|
| propose | `/evolve`, `/router-tune`, `/remember` (for memory topics) | workflow, memory |
| assess | `/assess-proposal` | evaluator |
| commit | `/commit-proposal` | workflow |
| rollback | `/rollback` | workflow |

Evaluator owns `assess` for the same reason it owns `/verify` — honest evaluation requires separation from proposal authorship.

### Validation Additions for `/entropy-scan`

When the diagnostics plugin is updated to cover self-evolution, add:
1. Every `commit`/`rollback` in the ledger has a matching snapshot file on disk.
2. Every `commit` has a preceding `assess` with verdict `pass` in the same resource lineage.
3. Ledger file is append-only (check via mtime heuristic or git history if available).

### No-Go List

- No auto-commit of file resources. `WORKFLOW_EVOLVE_AUTOCOMMIT=1` is limited to `env/<VAR>` numeric deltas within ±20%.
- No destructive branch. Rollbacks are themselves logged — the ledger is the source of truth.
- No cross-repo sync. Ledger stays local to `.claude/`.

---

## Change Policy

### Adding a New Plugin

1. Create `plugins/{name}/` with required structure
2. Register in `.claude-plugin/marketplace.json`
3. Update `README.md`: install command, plugin reference section, skill table, active hooks (if any), header counts
4. Update `docs/architecture.md`: three-layer diagram (if applicable), relevant sections
5. Run `/entropy-scan` to verify consistency
6. Run `claude plugin validate` to check frontmatter and hooks.json

### Adding a Hook

1. Create the `.sh` script in the plugin's `hooks/` directory
2. Register in the plugin's `hooks/hooks.json`
3. Set executable: `chmod +x`
4. Update `README.md` Active Hooks table
5. Follow the silent-on-success pattern
6. Test: `echo '{"tool_name":"...","tool_input":{...}}' | bash path/to/hook.sh`
7. Run `claude plugin validate` to check hooks.json structure

### Adding a Skill

1. Create `skills/{name}/SKILL.md` with required frontmatter
2. Set `disable-model-invocation: true`
3. Update `README.md` plugin reference skill table and header counts
4. No marketplace.json change needed (skills belong to existing plugins)

### Modifying Agent Definitions

1. Changes must preserve tool boundary invariants
2. Review `## Contract` section compatibility
3. Update `docs/architecture.md` if agent roles change

---

## Convention: Rule Provenance (Advisory)

Rules in `plugins/behavioral-core/hooks/rules.d/*.txt` should declare their origin on the first non-blank line:

```
# origin: <source>
# <rule text follows>
```

Accepted sources:

| Source form | Meaning |
|---|---|
| `postmortem:<id>` | Derived from a specific `/postmortem` artifact |
| `trace:<slug>` | Derived from a failure pattern surfaced by `traces/trace-evolve` |
| `ledger:<entry-id>` | Committed via the self-evolution loop (SEPL) |
| `external:<short-reason>` | Externally sourced preference or policy |

**Rationale** (Osmani, 2026 — *Agent Harness Engineering*): *"Every rule must trace to a specific past failure or external constraint."* Constraints that accumulate without provenance are the primary cause of rule-file bloat and context degradation.

**Enforcement**: Advisory. `/entropy-scan` Check 8 reports missing provenance but does not block. New rules added through the self-evolution loop naturally acquire `ledger:` provenance; legacy rules can be backfilled incrementally.

---

## Deliberate Non-Features

Some patterns discussed in external harness literature are intentionally **not** implemented. Documented here to preempt future "why isn't this here?" questions.

### Ralph-loop / auto-continuation hook

**What it is**: A `Stop` hook that re-injects the original prompt into a fresh context window on each turn-end, driving long-horizon tasks to completion without human intervention.

**Why Forge Studio does not ship this**: Every Forge self-evolution step is explicitly human-gated (`propose → assess → commit`, ledger-audited). An auto-continuation primitive conflicts with this discipline — the loop runs work past the operator's attention boundary and can burn budget on a degraded path. `workflow/turn-gate.sh` + manual `/handoff` / `/resume` give the same long-horizon capability with the human kept in the loop.

### Sandbox / execution isolation primitive

**What it is**: A dedicated plugin imposing process/network/filesystem sandboxing on agent-spawned commands.

**Why Forge Studio does not ship this**: The Claude Code host already owns permission gating, allowlists, and worktree isolation. `agents/worktree-team` provides filesystem isolation at the git level; `behavioral-core/block-destructive.sh` and `settings.json` deny rules cover command-level gating. A marketplace-level sandbox would duplicate the host boundary and can only weaken, not strengthen, the existing security model.

### Parallel "AGENTS.md" support

**What it is**: Reading `AGENTS.md` in addition to `CLAUDE.md` to match an emerging cross-vendor convention.

**Why Forge Studio does not ship this**: Claude Code loads `CLAUDE.md` natively. Supporting two parallel files fragments user configuration and creates synchronization burden. When the Claude Code host itself adopts `AGENTS.md`, Forge inherits it for free.

### Multi-sample consensus / Semantic Triangulation

**What it is**: Fan-out a single task to N workers, then pick the consensus answer. Source: *Semantic Triangulation* (arXiv 2511.12288v3) reports pass-rate improvements on CodeForces/CodeElo/LiveCodeBench via "just-tri-it" N-sample consensus.

**Why Forge Studio does not ship this**: The maintainer runs Opus end-to-end. N-sample consensus multiplies Opus token cost linearly in N without an equivalent cost-recovery path (no downgrade to a cheap draft model). `agents/worktree-team` already provides parallelism, but as *task decomposition* — each worker owns different files — not as duplicate-and-vote over the same task. If the maintainer switches to a draft-plus-verify model split later, this belongs in a new `triangulate` skill inside `agents/`; for now it stays deferred.

### Streaming / token-level hallucination detection

**What it is**: Real-time token-level or activation-based hallucination detection during generation, as in *Streaming Hallucination Detection in Long CoT* (arXiv 2601.02170v1) and *DAIReS* syndrome-decoding (arXiv 2602.06532).

**Why Forge Studio does not ship this**: Both require hooks into the model's own token stream or embedding space. Claude Code plugins run at the turn boundary (PreToolUse, PostToolUse, UserPromptSubmit, etc.) — there is no marketplace surface for sub-token observation. The turn-level analog — challenging claims before committing to them — is already covered by `/verify`, `/challenge`, and `/verify-refs`.

---

## Glossary

| Term | Definition |
|------|-----------|
| Feedforward | Pre-execution guidance (rules, instructions, conventions) |
| Feedback | Post-execution observation (linters, tests, review agents) |
| Context entropy | Degradation of agent coherence as context fills with irrelevant content |
| Context firewall | Sub-agent isolation preventing intermediate results from polluting parent |
| Back-pressure | Principle: success is silent, failures are verbose |
| Sprint contract | Negotiated done-criteria between planner and evaluator before execution |
| Harnessability | Property of a codebase indicating how well it supports harness controls |
| Evaluation gate | Hook-enforced verification step before committing planned work |
| Entropy collector | Periodic scanner detecting drift between documentation and codebase state |
