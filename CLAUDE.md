# Forge Studio — Project Instructions

## What This Is

A marketplace of composable Claude Code plugins implementing harness principles: behavioral steering, context management, memory, evaluation, orchestration, multi-agent decomposition, and execution traces.

## Scope: This Marketplace Is For Daily Work Across Projects

The marketplace is **not** built to work on itself. It is installed once and used across many unrelated projects (PHP/Laravel, JS/TS, Python, Go, Ruby, Rust, monorepos, microservices, docs sites, etc.). Every plugin, hook, and skill must be designed for that wider daily use.

Concrete consequences when authoring or modifying anything in `plugins/`:

- **Hooks must be project-agnostic.** A hook that hardcodes `plugins/<X>/`, `marketplace.json`, `docs/architecture.md`, `HARNESS_SPEC.md`, or any other forge-internal path is a no-op (or worse, a false positive) on every other project. Match by canonical filenames common across ecosystems (`package.json`, `Dockerfile`, `.github/workflows/*.yml`, `pyproject.toml`, `Cargo.toml`, `README*`, `CHANGELOG*`, `docs/`, `.env*`, schemas/migrations) — not by this repo's structure.
- **Marketplace-self-audit skills are the exception**, not the rule. `/entropy-scan`, `/validate-marketplace`, `/policies-list`, `/ssl-audit` *are* allowed to know about `plugins/` and `marketplace.json` because their explicit job is to audit this marketplace. They are slash-only tools, not always-on hooks. Don't extend that pattern to anything that fires on every project.
- **Tool matchers must reflect actual Claude Code tools.** Real tool names: `Bash`, `Edit`, `Write`, `Read`, `Grep`, `Glob`, plus event-specific matchers (`auto`/`manual` for PreCompact, error categories for StopFailure). `MultiEdit` is not a stable matcher — do not use it. Verify against `https://code.claude.com/docs/en/tools-reference` before adding any matcher.
- **Repo detection before forge assumptions.** If a hook needs to behave differently inside this marketplace versus a user project, gate it behind detection (`[ -f .claude-plugin/marketplace.json ] && ...`) or an explicit env var (`FORGE_MARKETPLACE_DEV=1`). Default behavior must be useful in any repo.
- **Path resolution must respect worktrees.** Use `CLAUDE_PROJECT_DIR` (set by Claude Code) → `git rev-parse --git-common-dir` parent → `pwd` as a fallback chain. Never slug `pwd` directly when interfacing with `~/.claude/projects/<slug>/` — Claude Code keys that off the main repo, so a worktree-derived slug writes to the wrong directory.
- **Portability matters.** Avoid GNU-only tools in shell hooks: no `tac` (use `awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}'`), no `grep -P` (use `grep -E` with POSIX ERE: `\<word\>` for word boundaries, `[[:space:]]` for `\s`, `[[:alnum:]_]` for `\w`). Hooks silently no-op on macOS/BSD when GNU extensions are missing.

## Always Check Authoritative Claude Code Documentation

Before editing anything in this marketplace — adding a hook event, changing a matcher, using an env var, writing skill frontmatter, calling MCP, building a plugin manifest — open the official sources first. Train-time knowledge drifts; treat these URLs as ground truth and verify before claiming a feature works.

| Source | Use it for |
|---|---|
| [Claude Code CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md) | Recent breaking changes, new hook events, new tool matchers, deprecations. Check the latest 30 days before any non-trivial change. |
| [Best practices](https://code.claude.com/docs/en/best-practices) | Recommended patterns and anti-patterns. |
| [Hooks reference](https://code.claude.com/docs/en/hooks) | Authoritative event list, exit-code semantics, JSON output schema (`{"decision":"block","reason":...}` vs `hookSpecificOutput.permissionDecision`), `stop_hook_active` contract. |
| [Plugins reference](https://code.claude.com/docs/en/plugins-reference) | `plugin.json`, `marketplace.json`, `hooks.json` schema. |
| [Tools reference](https://code.claude.com/docs/en/tools-reference) | Canonical tool names for matchers. |
| [Env vars](https://code.claude.com/docs/en/env-vars) | `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PROJECT_DIR`, `CLAUDE_SESSION_ID`, etc. — never invent env vars when an official one exists. |
| [Plugins guide](https://code.claude.com/docs/en/plugins) | Plugin authoring conventions. |
| [Headless](https://code.claude.com/docs/en/headless) | CLI invocation patterns and stdin contracts. |
| [Skills](https://code.claude.com/docs/en/skills) | YAML frontmatter schema, `disable-model-invocation` semantics, listing budget (1,536 chars per entry; ~2K total), compaction carry-over. |
| [MCP](https://code.claude.com/docs/en/mcp) | MCP tool naming, when hooks can call MCP, server install patterns. |

If an answer needs to be precise (matcher names, exit-code semantics, frontmatter fields, env var names), fetch the doc — do not guess from memory. WebFetch the source directly when in doubt.

## Reference Following: One Change Touches Many Files

When you modify anything, follow every reference. A change is incomplete until every file that knows about the changed thing has been reconciled with it.

- **New / removed plugin** → `README.md` (install command, plugin reference table, Active Hooks table, header counts), `docs/architecture.md` (component table, hook tables), `.claude-plugin/marketplace.json`, any cross-plugin policy registry entry.
- **New / removed hook** → register in `plugins/<plugin>/hooks/hooks.json`, add an FS-id to `plugins/diagnostics/registry/policies.json` (deny/gate/anchor/nudge/log verdict), update README Active Hooks paragraph counts and the per-event table in `docs/architecture.md`.
- **New / renamed skill** → re-grep for old name across all SKILL.md `Do NOT use for X — use /sibling instead` clauses; broken sibling references degrade routing advice.
- **Renamed identifier** → search direct calls, type references, string literals, dynamic imports, re-exports, test files, comment references. Assume grep missed something; run it twice with different queries.
- **Plugin version bump** → `plugins/<plugin>/.claude-plugin/plugin.json` AND the entry in `.claude-plugin/marketplace.json` (validate-marketplace check 8 fails on mismatch).
- **Behavioral rule change** → `plugins/behavioral-core/hooks/rules.d/*.txt` is one source; the related skill (`/verify`, `/challenge`, etc.), CLAUDE.md, and any hook that enforces the same intent need to stay coherent.

If you cannot say "I checked every file that names this thing", the change is not done.

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
