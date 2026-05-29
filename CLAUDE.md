# Forge Studio — Project Instructions

## What This Is

A marketplace of composable Claude Code plugins implementing harness principles: behavioral steering, context management, memory, evaluation, orchestration, multi-agent decomposition, and execution traces.

## The Codebase Is Not A Changelog

Shipped files (`.sh`, `.md`, `.json`) must not carry process metadata. Never write:

- Sprint/phase/task markers — `# Sprint 2 wiring`, `(Sprint 9)`, `Post-Sprint 3: X replaced Y`
- References to plans, PRs, research, or "the negotiation" inside source
- Changelog-style notes — `Previously X`, `Replaced in vN`, `Was /handoff, now /progress-log`, `(modified in Sprint K)`
- Dangling references to components that no longer exist

Comments explain **why the code is what it is** (hidden constraints, subtle invariants, workarounds for specific bugs). Not when or why it changed. The plan file, PR description, and git history carry that. Source files rot when they reference external process state that evolves without them.

## Completeness Requirements

**Documentation is part of every change, not a follow-up.** Any change that alters behavior, counts, paths, output shape, or capability must update the docs that describe it *in the same change* — before calling the work done. Docs that contradict the code are a defect of that change. This applies to edits of existing skills/scripts, not just new plugins: if a skill's behavior or a count moves, every doc that states the old value is now stale and must be fixed.

Every change must be complete. Before calling work done:

1. **Follow references** — If you add/modify a plugin, check every file that references it (README.md, docs/architecture.md, marketplace.json, other plugins that interact with it)
2. **Update docs** — New plugin? Update README.md (install command, plugin reference section, active hooks table, architecture diagram). Modified hook? Update the Active Hooks table. New skill? Add to the plugin's reference table. Changed an existing skill or script's behavior, dimension count, or output? Update its `docs/skills/<plugin>/<skill>.md` guide and every other doc that describes that behavior (grep the old value across `docs/`, `README.md`, `HARNESS_SPEC.md`).
3. **Update architecture.md** — If the change affects harness components, the 8-component table, the three-layer diagram, or any architectural pattern
4. **Update marketplace.json** — Every plugin must be registered in `.claude-plugin/marketplace.json`
5. **Verify JSON** — After editing any JSON file, validate it parses: `python3 -c "import json; json.load(open('path'))"`
6. **Test hooks** — Run new/modified shell scripts with `bash path/to/script.sh` and verify exit code and output

## File Conventions

### Plugin Structure
```text
plugins/{name}/
├── hooks/
│   ├── hooks.json       # Event registrations
│   └── *.sh             # Hook scripts (chmod +x)
└── skills/
    └── {skill-name}/
        ├── SKILL.md     # YAML frontmatter + instructions
        ├── scripts/     # Long helpers (≥10-line python or shell), argv-driven
        └── evals/       # Per-skill regression cases (evals.json: {skill_name, evals[]{id, prompt, files, assertions}}); validated by /run-evals
```

### SKILL.md Frontmatter
```yaml
---
name: skill-name
description: Use when <user signal / phrase / file pattern> — <what the skill does, third person, "pushy">.
when_to_use: Reach for this when <concrete situations>. Do NOT use for <X> — use `/sibling` instead.
argument-hint: <arg1> [arg2]           # optional
disable-model-invocation: true         # optional, zero-cost until invoked
context: fork                          # optional, runs in isolated subagent
allowed-tools:                         # optional, capability isolation
  - Read
  - Bash
disallowed-tools:                      # optional, removes tools from the model while the skill is active
  - WebFetch
paths:                                 # optional, glob list — restrict matcher activation to these paths
  - "plugins/**/SKILL.md"              # 15 skills currently use this; field is empirically honored
compatibility: "requires: bash>=4"     # optional, environment requirements (≤500 chars)
license: MIT                           # optional, license name or path to LICENSE file
metadata:                              # optional, vendor extension map
  author: example
mode: interactive                      # optional, mode command marker; values per-skill
# SSL overlay (optional, additive — see arXiv:2604.24026):
scheduling: <one-liner preconditions / triggers>          # defaults to when_to_use
structural:                                                # decomposition into major steps
  - <step 1>
  - <step 2>
logical: <postcondition / measurable success criterion>   # what makes this skill "done"
---
```

### SKILL.md Body Standard

- **Description budget**: `description + when_to_use` ≤ 1536 chars combined; written from the user/Claude POV, not the implementer's.
- **Exclusion clause is mandatory**: every `when_to_use` ends with one `Do NOT use for X — use /sibling instead` line that names a concrete sibling skill (or anti-trigger). Prevents cross-skill duplication.
- **No all-caps imperatives** (`MUST`, `NEVER`, `ALWAYS`, `CRITICAL`) in body prose — write the rule + the reason instead.
- **Long helpers live in `scripts/`**: ≥10-line python or shell snippets go in `plugins/<plugin>/skills/<skill>/scripts/<name>.{py,sh}` (chmod +x, argv-driven). SKILL.md calls them via `bash scripts/<name>.sh` / `python3 scripts/<name>.py`.
- **Multi-step workflows** (>3 steps) ship a copyable `## Execution Checklist` with `- [ ]` boxes Claude ticks as it goes.
- **Artifact-producing skills** (commit messages, ledger entries, JSON outputs, reports) ship 2 concrete `Input:` / `Output:` example pairs with literal labels.
- **Real failures only** in `## Known Failure Modes` — document past pain, never fabricate.
- **SSL overlay is opt-in**: `scheduling`, `structural`, `logical` fields tighten skill matching by separating preconditions, decomposition, and success criteria. Audit with `/ssl-audit`. Skills that already encode this in `when_to_use` need no rewrite.

### hooks.json Events
`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`

Hook exit codes: `0` = info, `1` = warning, `2` = block action (PreToolUse, PreCompact)

### README.md Plugin Table

The root `README.md` contains a plugin reference table with column order **`| Plugin | Purpose | Hooks | Skills |`**. When updating a plugin row:

- The third column is the hook count, the fourth is the skill count — not the other way around.
- Each row's hook count must reflect every script registered in that plugin's `hooks/hooks.json`, summed across events.
- The header line at the top of `README.md` (`<H> hooks`) and the `## Active Hooks` paragraph (`<H> hook command registrations`) must both agree with `bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh .`. Three locations, one number.

### Plan Files

Plans under `.claude/plans/` are authoring artifacts — gitignored, per-session. When a plan instructs a future change to a count, path, or table value:

- **Reference live state, not snapshot values.** A plan that hardcodes `58 hooks → 59 hooks` rots the moment another plan lands. Use `<H>` placeholders or "increment current count by 1" phrasing instead.
- **Mandate a pre-edit verification step** (e.g., `grep -nE "\b[0-9]+ hooks?\b" README.md`) so the generator reads current values from disk before editing.
- **Spell out column position** when changing table cells — refer to the table header explicitly so an off-by-one in column order doesn't slip through.

This keeps plans dispatchable in any order and prevents bake-in errors that the per-task pipeline must otherwise fix mid-flight.

### marketplace.json Entry
```json
{
  "name": "plugin-name",
  "description": "What it does",
  "version": "1.0.0",
  "source": "./plugins/plugin-name",
  "category": "category-name",
  "tags": ["tag1", "harness:component", "overhead:zero|minimal|moderate"]
}
```

## Documentation Checklist (for every plugin change)

- [ ] `README.md` — three count locations must agree:
  - Header line `<N> plugins. <M> skills. <H> hooks. <A> agents. <R> behavioral rules.`
  - `## Active Hooks` paragraph: `<H> hook command registrations across <P> plugins`
  - Per-plugin table row: `| <plugin> | <purpose> | <hooks> | <skills> |` — column order is **`Hooks | Skills`**, not the reverse
- [ ] `README.md` install command list and key-skills table reflect any new plugin or user-invocable skill
- [ ] `docs/architecture.md` — If new harness component or pattern
- [ ] `.claude-plugin/marketplace.json` — Plugin registered; `plugin.json` `version` matches the marketplace entry
- [ ] Hook scripts are executable (`chmod +x`); extracted skill scripts under `scripts/` too
- [ ] JSON files parse cleanly
- [ ] Drift counts match: `bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh .` agrees with the README header line **and** the Active Hooks paragraph

## Project Config

```text
No build step — this is a collection of markdown, JSON, and shell scripts.
Validate JSON: python3 -c "import json; json.load(open('file.json'))"
Test hooks: bash plugins/{name}/hooks/{script}.sh
```

## MCP Tools: codegraph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
codegraph MCP tools BEFORE using Grep/Glob/Read to explore the
codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, callees, impact) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `codegraph_search` (find symbols by name) instead of Grep
- **Task context**: `codegraph_context` composes search + node + callers + callees in one call
- **Understanding impact**: `codegraph_impact` instead of manually tracing references
- **Finding relationships**: `codegraph_callers` / `codegraph_callees` for who-calls-what
- **Call paths**: `codegraph_trace` to see how one symbol reaches another
- **File structure**: `codegraph_files` instead of filesystem scanning

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `codegraph_search` | Finding functions/classes/methods by name |
| `codegraph_context` | Building task context — composes search + node + callers + callees |
| `codegraph_callers` | Finding what calls a function |
| `codegraph_callees` | Finding what a function calls |
| `codegraph_impact` | Understanding blast radius of changing a symbol |
| `codegraph_trace` | Tracing the call path between two symbols |
| `codegraph_node` | Getting details (optionally source) for one symbol |
| `codegraph_explore` | Source for several related symbols + a relationship map |
| `codegraph_files` | Getting the indexed file structure |
| `codegraph_status` | Checking index health and statistics |

### Workflow

1. The graph auto-updates after HEAD-moving git commands (via hooks).
2. Use `codegraph_context` to assemble the relevant code for a task.
3. Use `codegraph_impact` to understand what a change affects.
4. Use `codegraph_callers` / `codegraph_callees` to map relationships.
