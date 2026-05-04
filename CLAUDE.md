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

Every change must be complete. Before calling work done:

1. **Follow references** — If you add/modify a plugin, check every file that references it (README.md, docs/architecture.md, marketplace.json, other plugins that interact with it)
2. **Update docs** — New plugin? Update README.md (install command, plugin reference section, active hooks table, architecture diagram). Modified hook? Update the Active Hooks table. New skill? Add to the plugin's reference table.
3. **Update architecture.md** — If the change affects harness components, the 7-component table, the three-layer diagram, or any architectural pattern
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
        └── SKILL.md     # YAML frontmatter + instructions
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

- [ ] `README.md` — Install command, plugin reference table, active hooks table, architecture diagram counts
- [ ] `docs/architecture.md` — If new harness component or pattern
- [ ] `.claude-plugin/marketplace.json` — Plugin registered; `plugin.json` `version` matches the marketplace entry
- [ ] Hook scripts are executable (`chmod +x`); extracted skill scripts under `scripts/` too
- [ ] JSON files parse cleanly
- [ ] Drift counts match: `bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh .` agrees with the README header line

## Project Config

```text
No build step — this is a collection of markdown, JSON, and shell scripts.
Validate JSON: python3 -c "import json; json.load(open('file.json'))"
Test hooks: bash plugins/{name}/hooks/{script}.sh
```

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
