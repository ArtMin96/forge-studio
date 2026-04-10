# Forge Studio — Harness Specification

> Canonical specification of mechanical invariants and architectural primitives. Machine-readable section headers enable automated validation via `/entropy-scan`. Last updated: 2026-04-09.

## Research Basis

Synthesized from 10 industry sources (2026): Anthropic Engineering, Fowler/Thoughtworks (Böckeler), HumanLayer, NxCode, InfoQ, Productboard, Penligent, Octopus Deploy, Sewak, Chachamaru. Full synthesis: `.claude/plans/curious-bubbling-biscuit-agent-afbc4fea3c7f788d5.md`.

---

## Architectural Primitives

12 building blocks that appear across multiple sources, abstracted from domain-specific implementations:

| # | Primitive | What It Does | Forge Studio Implementation |
|---|-----------|-------------|---------------------------|
| 1 | Planner | Decomposes intent into structured, bounded work units | `agents/planner` (read-only) |
| 2 | Generator/Worker | Executes bounded work with restricted tool access | `agents/generator` (read-write) |
| 3 | Evaluator/Verifier | Independently assesses output against criteria (never self-evaluation) | `evaluator/adversarial-reviewer` + `/verify` + `/challenge` |
| 4 | Context Firewall | Isolates sub-task context from parent orchestration context | Sub-agents with `context: fork` |
| 5 | Handoff Artifact | Structured file-based state transfer between agents/phases | `.claude/handoffs/`, `.claude/plans/` |
| 6 | Guide (Feedforward) | Pre-execution instructions, conventions, architectural rules | `behavioral-core/rules.d/*.txt`, CLAUDE.md |
| 7 | Sensor (Feedback) | Post-execution observation (computational or inferential) | Static analysis hooks, `/gate-report` |
| 8 | Policy Kernel | External enforcement of action classification (allow/deny/defer/ask) | `behavioral-core/block-destructive.sh`, `research-gate/require-read-before-edit.sh`, `research-gate/exploration-depth-gate.sh`, settings.json deny list |
| 9 | Entropy Collector | Periodic scanning agent restoring codebase invariants | `diagnostics/entropy-scan` |
| 10 | Progressive Disclosure | Context loaded on-demand, not upfront | `disable-model-invocation: true` on all skills |
| 11 | Sprint Contract | Negotiated agreement on done-criteria before execution begins | `## Contract` in planner output, `/contract` skill |
| 12 | Trace Telemetry | Persistent log of all agent actions for audit and sync | `traces/` JSONL collection |

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

Every SKILL.md must contain these YAML frontmatter fields:

```yaml
---
name: skill-name              # Required. Lowercase, hyphenated.
description: One-line purpose  # Required. What invoking this skill does.
disable-model-invocation: true # Required. Zero cost until invoked.
allowed-tools:                 # Optional. Capability isolation.
  - Read
  - Bash
---
```

**Validation**: `name`, `description`, and `disable-model-invocation: true` must be present in every SKILL.md.

## Invariant: Hook Exit Codes

Hook scripts communicate via shell exit codes:

| Exit Code | Meaning | When to Use |
|-----------|---------|------------|
| 0 | Info/JSON | Inject information into context. Stdout parsed for JSON. Silent when nothing to report. |
| 1 | Warning | Non-blocking alert. First line of **stderr** displayed. Stdout goes to debug log only. |
| 2 | Block | Prevent tool execution. **Only valid for PreToolUse hooks.** Stdout ignored; stderr fed to Claude. |

**Preferred approach for PreToolUse blocking**: Exit 0 with JSON `permissionDecision` output instead of exit 2. Provides richer feedback via `permissionDecisionReason` and `additionalContext`.

```bash
# JSON deny (preferred)
jq -n --arg reason "Explanation" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
```

**Validation**: No hook outside `PreToolUse` should exit with code 2.

## Invariant: Hook Output Pattern

Hooks must be **silent on success, verbose on failure**. When a hook has nothing to report, it exits 0 with no stdout. Output is only produced when there's actionable information.

**Rationale** (HumanLayer, 2026): "Success is silent, and only failures produce verbose output." Passing results flood context and cause hallucinations.

**Validation**: Hooks should not produce stdout when the condition they check is satisfied/normal.

## Invariant: Agent Tool Boundaries

Agent capability isolation prevents error propagation between phases:

| Agent Role | Allowed Tools | Cannot Do |
|-----------|--------------|-----------|
| Planner | Read, Glob, Grep, Bash | Modify files (no Write, Edit) |
| Generator | Read, Write, Edit, Bash, Glob, Grep | Skip planning phase |
| Reviewer | Read, Grep, Glob, Bash | Modify files (no Write, Edit) |

**Rationale** (Anthropic, 2026): "When asked to evaluate work they've produced, agents tend to respond by confidently praising the work — even when quality is obviously mediocre." Capability isolation ensures reviewers evaluate honestly rather than rubber-stamping by editing.

**Validation**: Agent `.md` frontmatter `tools` must match these boundaries.

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

**Six checks**:

| # | Check | What It Validates |
|---|-------|------------------|
| 1 | Plugin count drift | README header counts vs actual directories/skills/hooks |
| 2 | Marketplace registration gap | marketplace.json entries vs `plugins/` directories |
| 3 | SKILL.md frontmatter completeness | Required fields: name, description, disable-model-invocation |
| 4 | Hook script executability | All `plugins/*/hooks/*.sh` have `chmod +x` |
| 5 | Memory staleness | `.claude/memory/` topic files with dates > 90 days |
| 6 | Invariant compliance | Plugin structure rules from this spec |

**Invocation**: `/entropy-scan` (manual, zero-cost until invoked)

**Output**: Structured report showing pass/fail per check with proposed fixes. No writes — report only.

---

## Change Policy

### Adding a New Plugin

1. Create `plugins/{name}/` with required structure
2. Register in `.claude-plugin/marketplace.json`
3. Update `README.md`: install command, plugin reference section, skill table, active hooks (if any), header counts
4. Update `docs/architecture.md`: three-layer diagram (if applicable), relevant sections
5. Run `/entropy-scan` to verify consistency

### Adding a Hook

1. Create the `.sh` script in the plugin's `hooks/` directory
2. Register in the plugin's `hooks/hooks.json`
3. Set executable: `chmod +x`
4. Update `README.md` Active Hooks table
5. Follow the silent-on-success pattern
6. Test: `echo '{"tool_name":"...","tool_input":{...}}' | bash path/to/hook.sh`

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
