# Forge Studio

Personal Claude Code marketplace for making the model work at its best. Behavioral discipline, context mastery, agent effectiveness patterns, and hidden gems.

11 plugins. 25 skills. 11 hooks. 1 agent.

---

## Install

```bash
# Add the marketplace
/plugin marketplace add /path/to/this/repo

# Install a plugin
/plugin install iron-rules@forge-studio

# Install all plugins
/plugin install iron-rules@forge-studio
/plugin install self-critic@forge-studio
/plugin install context-guardian@forge-studio
/plugin install context-diet@forge-studio
/plugin install smart-workflow@forge-studio
/plugin install focus-mode@forge-studio
/plugin install session-mastery@forge-studio
/plugin install explore-plan-code@forge-studio
/plugin install power-user@forge-studio
/plugin install quality-gates@forge-studio
/plugin install edit-safety@forge-studio
```

After installing, start a new session for plugins to load.

### Recommended CLAUDE.md

A lean CLAUDE.md template is included at `templates/CLAUDE.md`. It's designed to work with forge-studio plugins — covers personality, judgment, context management, self-evaluation, and project config without repeating what hooks enforce.

```bash
cp templates/CLAUDE.md ./CLAUDE.md
# Edit the Project Config and Conventions sections for your project
```

### Recommended Settings

A `templates/settings.json` provides deny rules, auto-compact tuning, and thinking/effort defaults. Merge into your `~/.claude/settings.json`:

- **18 deny rules** block destructive commands at the permission layer (before hooks fire)
- **Auto-compact at 75%** prevents context quality decay on multi-step tasks
- **Extended thinking + high effort** for maximum output quality

The deny rules work in any permission mode, including `bypassPermissions`. Combined with iron-rules hooks (4-layer detection), this provides defense-in-depth against destructive operations.

See [Settings Best Practices](docs/settings.md) for the full guide: permission modes, performance tuning, sandbox config, and hidden gems.

---

## Quick Reference

### Discipline


| Command                       | What it does                                                 |
| ----------------------------- | ------------------------------------------------------------ |
| `/rules-audit`                | Audit session for sycophancy, apologies, scope creep, filler |
| `/challenge`                  | Critique your own work before presenting it                  |
| `/devils-advocate <decision>` | Argue against a design decision to find holes                |
| `/postmortem [bug]`           | Structured bug autopsy: root cause, category, prevention     |


### Context


| Command                  | What it does                                                |
| ------------------------ | ----------------------------------------------------------- |
| `/handoff [topic]`       | Generate a session transfer document                        |
| `/resume`                | Pick up from the latest handoff                             |
| `/checkpoint`            | Mid-session drift and scope creep check                     |
| `/audit-context`         | Analyze token overhead from CLAUDE.md, plugins, MCP servers |
| `/lean-claude-md [path]` | Trim CLAUDE.md to only lines that change behavior           |


### Effectiveness


| Command         | What it does                                           |
| --------------- | ------------------------------------------------------ |
| `/route <task>` | Pick the right workflow pattern for this task          |
| `/verify`       | Evidence-based completion check before claiming done   |
| `/scope <task>` | Define task boundaries and acceptance criteria         |
| `/timebox [N]`  | Set a message budget (default 15) for the current task |


### Workflow


| Command           | What it does                                                       |
| ----------------- | ------------------------------------------------------------------ |
| `/morning`        | Daily planning: review yesterday, check handoffs, prioritize today |
| `/eod`            | End-of-day: capture progress, create daily log, trigger handoff    |
| `/weekly`         | Weekly retro: patterns, wins, blockers, tech debt from daily logs  |
| `/explore <what>` | Phase 1: Read codebase via subagent without making changes         |
| `/plan <task>`    | Phase 2: Create implementation plan with files, changes, risks     |
| `/implement`      | Phase 3: Execute plan step-by-step with scope checks               |


### Gems


| Command                         | What it does                                                |
| ------------------------------- | ----------------------------------------------------------- |
| `/healthcheck [--quick|--full]` | Run quality pipeline (auto-detects PHP and/or JS/TS)        |
| `/gate-report`                  | Aggregate all quality warnings before committing            |
| `/ultrathink`                   | Guide to thinking modes and effort levels                   |
| `/parallel-power`               | Multi-session patterns: worktrees, fan-out, writer/reviewer |
| `/unix-pipe`                    | Claude as CLI tool: headless mode, piping, output formats   |
| `/context-tricks`               | Guided compaction, /btw, checkpoints, @ references          |


---

## Active Hooks

These fire automatically. No commands needed.


| Event                    | Plugin           | What it does                                                           |
| ------------------------ | ---------------- | ---------------------------------------------------------------------- |
| Every message            | iron-rules       | Re-anchors behavioral rules (no sycophancy, be critical, stay focused) |
| Every message            | context-guardian | Tracks message count; warns at 10, 25, 40, 50 messages                 |
| Before Bash              | iron-rules       | Blocks `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE`  |
| Before any tool          | focus-mode       | Reminds of active scope boundaries (if a scope exists)                 |
| Before `git commit`      | quality-gates    | Reminds to run tests                                                   |
| After Write/Edit         | iron-rules       | Nudges: "Does this change do ONLY what was asked?"                     |
| After reading >500 lines | context-guardian | Warns to extract what you need before compaction                       |
| After writing .php       | quality-gates    | Runs Larastan/PHPStan on the changed file                              |
| After writing .js/.ts    | quality-gates    | Runs tsc --noEmit and ESLint on the changed file                       |
| After Bash/Grep          | context-guardian | Warns if tool output approaching 50K char truncation boundary          |
| After Edit/Read          | edit-safety      | Tracks edits per file; warns after 3 edits without re-reading          |


---

## Usage Scenarios

### Starting your day

```
/morning
```

Reads yesterday's git log, checks for open handoffs and uncommitted changes, pulls CI status. Produces a prioritized plan. If you left a handoff from yesterday:

```
/resume
```

Picks up where you left off. Shows what was done, what's pending, any uncommitted changes.

Before diving into work, scope the first task:

```
/scope Add rate limiting to the /api/auth endpoint
```

Creates a scope document: which files change, which don't, what "done" looks like. The scope-reminder hook will gently remind you of boundaries throughout the session.

### Building a feature

Start by picking the right approach:

```
/route Add user notification preferences with email/push/sms channels
```

Claude recommends a pattern (e.g., "Orchestrator-Workers: break into independent channel handlers"). Then follow the phases:

```
/explore notification system and user preferences
```

Runs in an isolated subagent. Reads relevant files, reports patterns and dependencies without polluting your context.

```
/plan Add notification preferences
```

Creates a plan with exact files, changes per file, risks, and verification method. Edit with Ctrl+G if needed.

```
/implement
```

Executes the plan step-by-step. Checks scope after each change. Won't mark done without running verification.

```
/verify
```

Shows evidence: what changed, test output, edge case analysis. Either "VERIFIED" with proof or "UNVERIFIED" with what's needed.

### Long session management

After 10 messages, context-guardian warns about context decay (re-read files before editing). At 25, it suggests compaction or handoff. Check drift:

```
/checkpoint
```

Compares your work against the plan. Reports scope creep, suggests whether to continue, compact, or start fresh.

If the session is getting full but you're mid-task:

```
/compact preserve the notification preferences plan and test results
```

If you need to hand off to a fresh session:

```
/handoff notification-preferences
```

Generates a structured handoff document. Next session:

```
/resume
```

### Before committing

The quality-gates hooks already ran Larastan on every PHP file and tsc/ESLint on every JS/TS file you edited. Check the full picture:

```
/healthcheck --quick
```

Runs Pint + Larastan. Add `--full` to include the test suite.

```
/gate-report
```

Aggregates all warnings: static analysis issues, missing migration rollbacks, leftover `dd()` calls, new TODOs in the diff.

For important changes, challenge your own work:

```
/challenge
```

Runs in isolation. Asks: could this be simpler? What breaks? What's the weakest part? Would a staff engineer approve?

### Reviewing your discipline

After a long session, check how well Claude followed the rules:

```
/rules-audit
```

Scans for sycophancy, unnecessary apologies, scope creep, focus violations, filler language. Produces a behavioral score.

Check if your setup is lean:

```
/audit-context
```

Measures CLAUDE.md token weight, counts active plugins and MCP servers, identifies waste. Follow up with:

```
/lean-claude-md
```

Trims your CLAUDE.md to only lines that actually change Claude's behavior.

### Ending your day

```
/eod
```

Reviews today's commits and files changed. Creates a daily log. Suggests handoff if work is in progress.

```
/handoff auth-refactor
```

Captures state for tomorrow. On Friday:

```
/weekly
```

Reads the week's daily logs. Surfaces patterns, wins, blockers, and accumulated tech debt.

---

## Plugins

### iron-rules

The behavioral backbone. Three hooks enforce discipline on every interaction: anti-sycophancy anchoring on every message, destructive command blocking on bash, and self-review nudging after every code write. CLAUDE.md rules degrade over long sessions (~80% compliance). Hooks fire at 100%. This is the difference.

### self-critic

Implements Anthropic's evaluator-optimizer pattern. `/challenge` forces self-critique before completion. `/devils-advocate` argues against decisions to find holes. The adversarial-reviewer agent does read-only code review with a skeptical eye — it can't modify code, only critique it.

### context-guardian

Context is the most important resource (per Anthropic's own docs). This plugin tracks message count (warns at 10, 25, 40, 50), warns when reading large files, detects potential tool output truncation near the 50K char boundary, and provides the handoff/resume/checkpoint system for session-to-session continuity.

### context-diet

Your setup competes for context tokens. This plugin audits the overhead (CLAUDE.md size, plugin count, MCP server count) and trims waste. Based on the finding that a focused 30-line CLAUDE.md outperforms a 200-line one.

### smart-workflow

From Anthropic's "Building Effective Agents" research. `/route` picks the right pattern for the task (simple fix, prompt chaining, routing, orchestrator-workers, evaluator-optimizer). `/verify` enforces evidence-based completion — no more "it should work."

### focus-mode

Prevents the "infinite exploration" anti-pattern. `/scope` defines boundaries before work starts. The scope-reminder hook nudges focus on every tool use. `/timebox` sets a message budget forcing efficiency.

### session-mastery

Daily rituals that compound over weeks. Morning planning, end-of-day capture, weekly retrospective. Each feeds the next: morning reads handoffs and daily logs, EOD creates daily logs and triggers handoffs, weekly analyzes the full week.

### explore-plan-code

Structures Anthropic's recommended four-phase workflow into explicit skills. Explore runs in an isolated subagent (keeps main context clean). Plan produces a file that can be edited before implementation. Implement follows the plan step-by-step with scope checks.

### power-user

Reference skills for hidden Claude Code features. Not tools you invoke during work — knowledge you look up when you need it. Ultrathink, parallel worktrees, Unix piping, context management tricks. All `disable-model-invocation: true` so they cost zero tokens until invoked.

### quality-gates

Code quality hooks for PHP and JS/TS. Larastan runs automatically on every PHP file write. TypeScript compiler and ESLint run on every JS/TS file write. Migration files get checked for `down()` methods. Pre-commit triggers a test reminder. `/healthcheck` auto-detects project type and runs the appropriate pipeline (Pint → Larastan → Pest for PHP, Prettier → tsc → ESLint → Vitest/Jest for JS/TS).

### edit-safety

Enforces edit verification patterns. Tracks how many times each file is edited per session. After 3 edits to the same file without a re-read, warns to verify current file state. Prevents the common failure mode where auto-compaction silently destroys context of earlier file reads, leading to edits against stale state.

---

## Design Principles

**Hooks over instructions.** CLAUDE.md rules have ~80% compliance that degrades as context fills. Hooks fire deterministically at 100%. For non-negotiable behavior, use hooks.

`**exit 2` blocks, `exit 1` warns.** Most developers get hook exit codes wrong. The iron-rules destructive command blocker uses `exit 2` to actually prevent execution.

**Zero cost until invoked.** All 25 skills use `disable-model-invocation: true`. They don't load into context until you call them. Installing all 11 plugins adds near-zero overhead.

**Subagent isolation.** Skills that read many files (`/explore`, `/challenge`, `/devils-advocate`) use `context: fork` to run in isolated subagents. Only summaries return to your main session.

**One concern per plugin.** Each plugin does one thing. Install only what you need. Remove what you don't.

**Re-anchor on every message.** The iron-rules `UserPromptSubmit` hook defeats long-session drift by re-injecting behavioral rules on every message — not just at session start.

---

## Customization

**Adjust hook thresholds:** Edit the shell scripts in `plugins/{name}/hooks/`. For example, change the 25-message warning in `context-guardian/hooks/track-message-count.sh`.

**Edit skill behavior:** Each SKILL.md is self-contained. Modify the instructions, add sections, or change the output format.

**Add your own skills:** Create `skills/{name}/SKILL.md` with YAML frontmatter in any plugin directory.

**Disable a hook:** Remove the entry from the plugin's `hooks/hooks.json`.

**Disable a plugin:** `/plugin disable {name}@forge-studio`

**Adjust the destructive command blocklist:** Edit `iron-rules/hooks/block-destructive.sh` to add or remove patterns.

---

## Docs

- [Budget Window Warmup](docs/warmup.md) — Anchor your 5-hour token budget window to predictable hours using scheduled triggers or GitHub Actions