# Forge Studio — Harness Specification

> Canonical specification of mechanical invariants and architectural primitives. Machine-readable section headers enable automated validation via `/entropy-scan`.

## Research Basis

Synthesized from 10 industry sources (2026): Anthropic Engineering, Fowler/Thoughtworks (Böckeler), HumanLayer, NxCode, InfoQ, Productboard, Penligent, Octopus Deploy, Sewak, Chachamaru. Full synthesis: `.claude/plans/curious-bubbling-biscuit-agent-afbc4fea3c7f788d5.md`.

---

## Architectural Primitives

13 building blocks that appear across multiple sources, abstracted from domain-specific implementations:

| # | Primitive | What It Does | Forge Studio Implementation |
|---|-----------|-------------|---------------------------|
| 1 | Planner | Decomposes intent into structured, bounded work units; writes `.claude/plans/s<N>-<slug>.md` | `agents/planner` (Write/Edit scoped to `.claude/plans/`) |
| 2 | Generator/Worker | Executes bounded work with restricted tool access | `agents/generator` (read-write) |
| 3 | Evaluator/Verifier | Independently assesses output against criteria (never self-evaluation) | `evaluator/adversarial-reviewer` + `/verify` + `/challenge` + `/assess-proposal` |
| 4 | Context Firewall | Isolates sub-task context from parent orchestration context | Sub-agents with `context: fork` |
| 5 | Handoff Artifact | Structured file-based state transfer between agents/phases | `.claude/plans/`, `.claude/spec.md` (living spec), `claude-progress.txt` (append-only session log), `.claude/features.json` |
| 6 | Guide (Feedforward) | Pre-execution instructions, conventions, architectural rules | `behavioral-core/hooks/rules.d/*.txt`, CLAUDE.md |
| 7 | Sensor (Feedback) | Post-execution observation (computational or inferential) | Static analysis hooks, `/gate-report` |
| 8 | Policy Kernel | External enforcement of action classification (allow/deny/defer/ask) | `behavioral-core/block-destructive.sh` (incl. Layer 5 safe-mode gate), `research-gate/require-read-before-edit.sh`, `research-gate/exploration-depth-gate.sh`, `policy-gateway/scan-secrets.sh`, `policy-gateway/scan-injection.sh`, settings.json deny list |
| 9 | Entropy Collector | Periodic scanning agent restoring codebase invariants | `diagnostics/entropy-scan` |
| 10 | Progressive Disclosure | Context loaded on-demand, not upfront | `disable-model-invocation: true` on all skills |
| 11 | Sprint Contract | Negotiated agreement on done-criteria before execution begins | `## Contract` in planner output, `/contract` skill |
| 12 | Trace Telemetry | Persistent log of all agent actions for audit and sync | `traces/` JSONL collection |
| 13 | Self-Evolution Loop | Auditable propose → assess → commit operator over versioned resources, with rollback | `workflow/evolve` + `workflow/commit-proposal` + `workflow/rollback` + `evaluator/assess-proposal`; ledger at `.claude/lineage/ledger.jsonl` |

---

## Invariant: Plugin Structure

Every plugin must follow this directory layout:

```text
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
| `disallowed-tools` | No | Tools removed from the model while the skill is active. Unlike `allowed-tools`, this **does** restrict — listed tools become uncallable for the skill's lifetime. |
| `argument-hint` | No | Hint shown during autocomplete (e.g., `[issue-number]`). |
| `model` | No | Override session model when skill is active. |
| `effort` | No | Override session effort level: `low`, `medium`, `high`, `xhigh`, `max`. `xhigh`/`max` require Opus 4.7/4.8; on older models Claude Code falls back to the highest supported level. |
| `context` | No | `fork` runs in isolated subagent context. Skill content becomes the subagent prompt. |
| `agent` | No | Subagent type for `context: fork`. Built-in (`Explore`, `Plan`, `general-purpose`) or custom. |
| `paths` | No | Glob patterns limiting auto-activation (e.g., `*.php`). Comma-separated or YAML list. |
| `hooks` | No | Skill-scoped lifecycle hooks. Same format as hooks.json. Scoped to skill lifetime. |
| `shell` | No | Shell for inline `!command` blocks: `bash` (default) or `powershell`. |
| `scheduling` | No | SSL overlay (arXiv:2604.24026). One-liner preconditions / triggers. Defaults to `when_to_use`. Audited by `/ssl-audit`. |
| `structural` | No | SSL overlay. Bullet list decomposing the skill into major steps. Absent by default. |
| `logical` | No | SSL overlay. Postcondition / measurable success criterion. `/ssl-audit` flags skills missing this field. |
| `compatibility` | No | Environment requirements (system packages, network, product). ≤500 chars. Most skills don't need this. |
| `license` | No | License name or path to a bundled LICENSE file. |
| `metadata` | No | Free-form string→string map for vendor extensions (e.g. `version`, `author`). |
| `mode` | No | Marks the skill as a mode command. String; values defined per-skill. |

## Frontmatter Extensions Beyond agentskills.io Spec

The following fields are forge-studio additions not defined by the agentskills.io specification. They are non-portable to strict-spec clients: a client that only implements the canonical spec will silently ignore or reject them. Each extension is intentional — documenting the rationale prevents accidental removal and explains the portability trade-off.

| Extension key | Rationale | Portability |
|---|---|---|
| `when_to_use` | Disambiguates trigger conditions from capability description. Strict clients collapse this into `description` at parse time. | Ignored by strict-spec clients; collapsed into description by lenient clients. |
| `argument-hint` | Drives Claude Code slash-command autocomplete UI. No equivalent in the canonical spec. | Claude Code only. |
| `disable-model-invocation` | Zero-cost progressive disclosure — skill loads only when explicitly invoked. Spec has no equivalent opt-in loading model. | Claude Code only. |
| `context: fork` | Forces skill execution into an isolated subagent context. Spec mentions subagents informally (§F) but does not define a `context` field. | Claude Code only. |
| `agent` | Subagent type paired with `context: fork`. Spec does not define agent delegation in skill frontmatter. | Claude Code only. |
| `mode` | Open-string per-skill mode marker. Semantics defined by each skill's body. Not in the canonical field set. | Claude Code only. |
| `scheduling` | SSL overlay (arXiv:2604.24026). One-liner precondition or trigger; defaults to `when_to_use` if absent. Audited by `/ssl-audit`. | Non-portable. |
| `structural` | SSL overlay. Bullet list decomposing the skill into major steps. Absent by default. | Non-portable. |
| `logical` | SSL overlay. Postcondition / measurable success criterion. `/ssl-audit` flags skills missing this field. | Non-portable. |
| `user-invocable` | `false` hides the skill from the `/` menu. No canonical equivalent. | Claude Code only. |
| `hooks` | Skill-scoped lifecycle hooks active during skill execution. Same format as plugin `hooks.json`. | Claude Code only. |
| `paths` | Glob patterns limiting auto-activation to matching files. Not in canonical spec. | Claude Code only. |
| `shell` | Shell for inline `!command` blocks (`bash` or `powershell`). Not in canonical spec. | Claude Code only. |
| `counterexamples` | List of 2–4 strings: scenarios where the skill should NOT be used. Sourced from the skill's `when_to_use` exclusion text and real near-misses. Helps the router reject false-positive invocations. | Non-portable. |
| `contract` | κ-tuple mapping per NL Harness 2603.25723 App.A: `required_outputs`, `budget`, `permission_scope`, `completion_conditions`, `output_paths`. Machine-readable preconditions and success criteria for the skill. | Non-portable. |

**Design decision:** forge-studio does not namespace these extensions under `metadata.forge.*` (which would be spec-round-trippable). Readability and direct field access are prioritized over strict-spec round-tripping. The trade-off is documented here so future maintainers can make an informed migration decision.

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

Claude Code exposes 30+ hook events across the lifecycle. The groups below cover the events Forge Studio plugins use plus the most relevant others; all events are available.

### Session Lifecycle
| Event | Matcher | Description |
|---|---|---|
| `SessionStart` | Session source (`startup`, `resume`, `clear`, `compact`) | Session begins or resumes |
| `Setup` | None | `--init-only`, or `--init`/`--maintenance` in `-p` mode |
| `SessionEnd` | End reason (`clear`, `resume`, `logout`) | Session terminates |
| `InstructionsLoaded` | Load reason (`session_start`, `compact`, `include`) | CLAUDE.md or `.claude/rules/` loaded |

### Per-Turn Events
| Event | Matcher | Description |
|---|---|---|
| `UserPromptSubmit` | None (always fires) | User submits prompt, before Claude processes |
| `MessageDisplay` | None | While assistant message text is displayed. Can transform or hide it. |
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

## Invariant: Consecutive-Error Escalation + Graceful Degradation

Track consecutive tool failures. Two thresholds:

1. **Warn threshold** (`FORGE_FAILURE_THRESHOLD`, default 3): inject a deterministic message to break retry loops. Non-blocking.
2. **Safe-mode threshold** (`FORGE_SAFE_MODE_THRESHOLD`, default 5): write `.claude/safe-mode` flag + emit `safe-mode-enter` ledger entry. `behavioral-core/block-destructive.sh` Layer 5 reads the flag and denies all Bash/Edit/Write mutations until the user runs `/safe-mode off` (which clears the flag, emits `safe-mode-exit`, and suggests `/postmortem`).

**Rationale** (TRAE §5.2.4 "Graceful Degradation" + 12-Factor Agent, HumanLayer, 2026): After repeated failures, "downshift to a weak-but-safe mode" rather than continuing to attempt mutations. The forced human checkpoint is the value.

**Validation**: `PostToolUseFailure` hook must track consecutive count, warn at warn threshold, write flag + ledger entry at safe-mode threshold. `block-destructive.sh` must check the flag on every `PreToolUse`. `/safe-mode off` must clear the flag, counter, and emit a matching ledger `safe-mode-exit` entry.

## Invariant: Skill Size Budget

Skills should stay under 5,000 tokens (~20,000 chars) to survive compaction intact. Skills under 2,000 tokens (~8,000 chars) are ideal. Skills exceeding 5,000 tokens risk being truncated or dropped after compaction.

**Rationale**: Official docs confirm skills survive compaction with first 5,000 tokens per skill, shared 25,000-token budget. Oversized skills accelerate context rot.

**Validation**: `/entropy-scan` should flag SKILL.md files exceeding ~8,000 characters.

## Invariant: SKILL.md Registration Hygiene

Three rules apply to every SKILL.md beyond the size budget above:

1. **Registry budget** — The runtime `<available_skills>` block has a 15,000-byte ceiling. Sum of `description + when_to_use` UTF-8 bytes across **auto-loadable** skills (those without `disable-model-invocation: true`) must stay under that cap. Skills with `disable-model-invocation: true` are excluded — they appear only in the user-facing `/` menu, never in the LLM context.
2. **Body line cap** — SKILL.md body (content after the closing `---` of frontmatter) must stay under 500 lines.
3. **Name shape** — `name:` must match `^[a-z0-9]+(-[a-z0-9]+)*$`: lowercase alphanumeric segments joined by single hyphens; no underscores, no consecutive hyphens, no leading/trailing hyphen.

**Rationale**: agentskills.io spec (name regex), Hanchung's *Claude Agent Skills: A First Principles Deep Dive* (15,000-byte registry), Anthropic skill-authoring best-practices (<500-line body).

**Validation**: `/validate-marketplace` runs `check-registry-budget.py`, `check-body-lines.py`, and `check-frontmatter.py` (which also enforces the name regex).

## Invariant: SessionStart Latency Budget

Every plugin's SessionStart hooks must collectively respect:

| Phase | Per-plugin total | Marketplace total |
|---|---|---|
| Warm session (binaries cached, marker files present) | < 300 ms expected | < 2,000 ms target / < 5,000 ms ceiling |
| Cold session (first-run install, no markers) | unbounded by design | report cost for visibility, do not block |

**Rationale**: SessionStart hooks are the user's first interaction. Latency here is fixed cost on every conversation. Cold cost is acceptable when amortized across all subsequent sessions, but warm cost must stay imperceptible.

**Mechanism**: `plugins/diagnostics/lib/time-hook.sh` wraps each SessionStart hook command in `hooks.json`, preserves the hook's stdin/stdout/exit-code contract, and appends one JSONL row per invocation to `${FORGE_STUDIO_TIMING_LOG:-~/.local/share/forge-studio/startup.jsonl}`. The wrapper falls through to direct exec on its own internal failure so a measurement bug cannot break session startup.

**Validation**: `/startup-profile` reads the JSONL and reports per-plugin median + p95 ms, plus warm/cold session totals. Run after adding a SessionStart hook or before a release.

**No-go**: never wrap a hook for an event other than SessionStart through this wrapper without first re-evaluating the contract — `PreToolUse` hooks have decision semantics (`exit 2`, `{"decision":"block"}`) that the wrapper does not need to handle today and would have to be extended for.

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
| `effort` | No | Override effort: `low`, `medium`, `high`, `xhigh`, `max`. `xhigh`/`max` require Opus 4.7/4.8; older models fall back to the highest supported level. |
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
1. Invokes `/contract` at the start of every task in the plan to mechanically Read the contract from disk (prevents context decay; protects against agent-loop budget exhaustion when plans have multiple tasks)
2. Confirms each criterion is understood and achievable
3. If any criterion is ambiguous → STOP and report

**Per-task iteration.** When the plan has multiple `#### T<n>` task headings, the orchestrator dispatches one generator–reviewer pair per task, each preceded by its own `/contract` re-read. The contract is one document; what changes per task is the generator's scope. This keeps each subagent's tool-call surface small enough to stay under Anthropic's `maxTurns` / `task_budget` budget reliably. See `agents/skills/dispatch` and `workflow/skills/orchestrate` for the dispatch loop body.

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

Source: *Autogenesis: A Self-Evolving Agent Protocol* (Wentao Zhang, arXiv:2604.15034, Apr 2026). Protocol detail: `docs/self-evolution.md`.

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

Adding a new kind requires amending this table and `docs/self-evolution.md`.

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

```text
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

## Long-Session Protocol

Long-running sessions (multi-hour / multi-day / cross-session) rely on a durable artifact triad at the repo root + `.claude/`:

| Artifact | Role | Producer | Consumer |
|---|---|---|---|
| `init.sh` | Replayable dev-env bootstrap (install, build, test commands) | `/init-sh` | Fresh-context agents; `surface-progress.sh` surfaces its presence |
| `claude-progress.txt` (repo root) | Append-only session log: `Done / In progress / Blockers / Next` per session | `/progress-log`, `pre-compact-handoff.sh`, `turn-gate.sh` | `surface-progress.sh` (SessionStart), `/session-resume`, `/token-pipeline`, `/rest-audit` |
| `.claude/spec.md` | Living spec — evolves as planner→generator→reviewer complete | `/living-spec`, `plugins/workflow/hooks/after-subagent.sh` | reviewer step, `/verify`, `/rest-audit` |
| `.claude/features.json` | Testable requirements expanded from `## Contract` | `/feature-list`, `after-subagent.sh` | `/tdd-loop`, `/verify`, `/rest-audit` |

**Mechanics**:
1. Planner writes `.claude/plans/{topic}.md` with `## Contract`.
2. `/feature-list` expands Contract bullets into `features.json` with `verify_cmd` per item.
3. `/living-spec` initializes `spec.md` from the Contract.
4. Generator runs; `after-subagent.sh` (SubagentStop) appends a delta block to `spec.md` and flips matching `features.json` items to `done` when commit subjects cite `F<n>` ids.
5. At session end: `/progress-log` appends to `claude-progress.txt` and emits ledger entry (same SEPL schema).
6. Next session: `surface-progress.sh` (SessionStart) surfaces the tail.

**Source**: Anthropic — *"Effective harnesses for long-running agents"* (init.sh + claude-progress.txt + feature-list JSON pattern); Augment — *"Intent"* blog (living-spec concept, Coordinator/Specialists/Verifier).

---

## Policy Gateway Protocol

Policy Gateway sits between planner and execution (TRAE §5.2.4). Three layers, all non-destructive to the existing `block-destructive` + `research-gate` chain — same `permissionDecision:deny` JSON contract; same ledger:

| Hook | Event | Role |
|---|---|---|
| `scan-secrets.sh` | PreToolUse:Edit\|Write | Regex-match new content against `rules.d/secrets.txt`; deny + emit `policy-block` ledger entry |
| `scan-injection.sh` | PreToolUse:Bash\|Edit\|Write | Regex-match tool input against `rules.d/injection.txt`; deny + ledger entry |
| `audit-sensitive-ops.sh` | PostToolUse:Edit\|Write | Non-blocking; append `sensitive-op-audit` ledger entry when writes target `.env`, `secrets/`, `credentials/`, `keys/`, `.pem`, `.key`, `.p12`, `.pfx`, `id_rsa*`, `id_ed25519*` |

**Evolvability**: rule files live in `plugins/policy-gateway/rules.d/` and register as SEPL resources under the slug `hooks/policy-gateway/rules.d/<file>` — `/evolve` can propose additions.

**Deep-dive skill**: `/policy-audit` replays ledger entries + scans the working tree. Invoked by `/rest-audit` Security axis.

---

## Deliberate Non-Features

Some patterns discussed in external harness literature are intentionally **not** implemented. Documented here to preempt future "why isn't this here?" questions.

### Ralph-loop / auto-continuation hook

**What it is**: A `Stop` hook that re-injects the original prompt into a fresh context window on each turn-end, driving long-horizon tasks to completion without human intervention.

**Why Forge Studio does not ship this**: Every Forge self-evolution step is explicitly human-gated (`propose → assess → commit`, ledger-audited). An auto-continuation primitive conflicts with this discipline — the loop runs work past the operator's attention boundary and can burn budget on a degraded path. `workflow/turn-gate.sh` + the long-session artifacts (`init.sh` + `claude-progress.txt` + `features.json` + `spec.md`) give the same long-horizon capability with the human kept in the loop.

### Training-time self-evolution

**What it is**: Agent self-improvement via reward-free world-knowledge exploration (arXiv 2604.18131) or continual-learning approaches (self-distillation, gradient projections, replay, KL penalties — as sketched in Ilija Lichkovski's "Defining Continual Learning" thread).

**Why Forge Studio does not ship this**: These are **training-time** techniques — they modify model weights. Forge Studio's harness is a **runtime** layer between Claude Code and the user's work. Self-evolution at the harness layer means evolving rules / hooks / skills / memory topics / env vars via SEPL (propose → assess → commit → rollback). The two are complementary, not substitutable.

### Managed Agents API port (Session / Harness / Sandbox split)

**What it is**: Anthropic's April 9 2026 Claude Managed Agents introduced a "meta-harness" decomposition — Session (append-only event log), Harness (model loop + tool router), Sandbox (execution env) — exposed as composable production APIs.

**Why Forge Studio does not ship this**: Production API concern, not plugin-marketplace concern. Claude Code itself is already a harness; Forge Studio customizes *that* harness. Re-creating the Session/Harness/Sandbox split inside plugins would duplicate the host layer. Where the idea applies — append-only session events — is already covered by `.claude/lineage/ledger.jsonl` (SEPL) and `claude-progress.txt` (long-session).

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
