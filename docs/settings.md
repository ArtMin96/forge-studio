# Settings Best Practices

Recommended Claude Code `settings.json` configuration. A template is available at `templates/settings.json`.

---

## Settings Hierarchy

Settings are evaluated in order of precedence (highest first):

| Scope | File | Who it affects |
|-------|------|----------------|
| Managed | `managed-settings.json` | All users on machine (IT-deployed) |
| CLI flags | `--model`, `--effort`, etc. | Current session only |
| Local | `.claude/settings.local.json` | You, this project (gitignored) |
| Project | `.claude/settings.json` | All collaborators (git-tracked) |
| User | `~/.claude/settings.json` | You, all projects |

**If a tool is denied at ANY level, no other level can allow it.** This is the key safety property.

---

## Permission Modes

Set via `permissions.defaultMode`:

| Mode | Behavior | AFK-safe | Best for |
|------|----------|----------|----------|
| `default` | Prompts on first use of each tool | No | Getting started, sensitive work |
| `acceptEdits` | Auto-accepts file edits, prompts on Bash | Partial | Code iteration |
| `plan` | Read-only, no modifications | N/A | Exploration, design phase |
| `auto` | Server-side classifier decides per-action | Yes | Long tasks (Team/Enterprise) |
| `dontAsk` | Blocks all unapproved tools | No | Locked-down CI/pipelines |
| `bypassPermissions` | Skips all prompts | Yes (risky) | Isolated VMs/containers |

**Terminology:**
- **AFK-safe**: Claude can run autonomously without prompting you for permissions while you're away from the keyboard
- **Team/Enterprise**: Anthropic plan tiers at claude.ai — `auto` mode requires one of these plans

### Recommendation

- **Interactive work**: `default` or `acceptEdits` + deny rules
- **AFK / hands-off**: `auto` if available (Team/Enterprise plan), otherwise `bypassPermissions` + deny rules + behavioral-core hooks
- **CI/CD**: `bypassPermissions` in isolated containers

---

## Deny Rules

Deny rules block specific tool patterns regardless of permission mode. They use glob matching and are evaluated **before** hooks fire. Even in `bypassPermissions`, deny rules are enforced.

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force *)",
      "Bash(git reset --hard *)",
      "Bash(git checkout -- *)",
      "Bash(git clean -f *)",
      "Bash(git branch -D *)",
      "Bash(* DROP TABLE *)",
      "Bash(curl * | bash *)"
    ]
  }
}
```

### Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `Bash(rm -rf *)` | Any bash command starting with `rm -rf` |
| `Bash(* DROP TABLE *)` | Any command containing `DROP TABLE` |
| `Bash(git push * --force)` | Force push with flag at end |
| `Edit(/etc/**)` | Editing system files |
| `Read(~/.ssh/*)` | Reading SSH keys |
| `WebFetch(domain:evil.com)` | Fetching from specific domain |

### Deny Rules vs Hooks

| | Deny Rules | Hooks (PreToolUse) |
|---|---|---|
| Matching | Glob patterns | Regex / arbitrary logic |
| Evaluated | Before tool execution, at permission layer | After permission check, before execution |
| Override | Cannot be overridden by any settings level | Can be bypassed by obfuscation |
| Catches wrappers | No (`bash -c 'rm -rf /'` passes) | Yes (Layer 2 in behavioral-core) |
| Configuration | settings.json | hooks.json + shell scripts |

**Use both.** Deny rules are the safety net that can't be overridden. Hooks catch what deny rules miss.

See [Architecture: Why Hooks Beat Instructions](architecture.md#why-hooks-beat-instructions) for how hooks complement deny rules.

---

## Performance Tuning

### Auto-Compaction

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75"
  }
}
```

Controls when context compaction triggers (percentage of context window used):
- **95%** (default) — Compacts too late, causing quality degradation on multi-step tasks
- **75%** (recommended) — Compacts earlier, preserving coherence
- **60-70%** — Conservative, for very long sessions
- Values above ~83% are silently capped to default

### Effort Level

```json
{
  "effortLevel": "max"
}
```

Maps directly to `output_config.effort` in the API call. Higher effort = more reasoning compute before the model responds.

| Level | Use case | Cost | Who can use |
|-------|----------|------|-------------|
| `low` | Simple tasks, classification | Cheap | All users |
| `medium` | Most coding tasks | Balanced | All users |
| `high` | Complex debugging, architecture | Higher | All users |
| `max` | Deepest reasoning, no token limit | Highest | Opus 4.6 only for external users |

External users can persist `low`/`medium`/`high` in settings. `max` must be set per-session or via `CLAUDE_CODE_EFFORT_LEVEL=max` in env.

### Thinking

```json
{
  "alwaysThinkingEnabled": true
}
```

Forces extended thinking on every response. More internal reasoning = better output quality.

### Prompt Caching

Enabled by default. **Never disable it.** Controls via env:

| Variable | Effect |
|----------|--------|
| `DISABLE_PROMPT_CACHING=1` | Disables all caching (bad) |
| `DISABLE_PROMPT_CACHING_OPUS=1` | Per-model control |

Claude Code splits the system prompt at a `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` marker. Everything before it gets globally cached (shared across sessions). Everything after is session-specific (ephemeral cache). See `docs/architecture.md` for details on what busts the cache.

### Model Aliases

These are native Claude Code aliases, available via `--model` flag or `model` key in settings.json.

| Alias | Resolves to |
|-------|-------------|
| `sonnet` | Latest Claude Sonnet 4.6 |
| `opus` | Latest Claude Opus 4.6 |
| `haiku` | Fast, efficient model |
| `opus[1m]` | Opus with 1M context window |
| `opusplan` | Opus for planning, Sonnet for execution |

---

## Sandbox Configuration

Lives in `~/.claude.json` (NOT `settings.json`):

```json
{
  "sandbox": {
    "filesystem": {
      "denyRead": ["~/.aws/credentials", "~/.ssh/id_*", "~/.gnupg/*"]
    },
    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org"]
    }
  }
}
```

OS-level restrictions. Prevents Claude from reading sensitive files or making unexpected network calls.

---

## Recommended Template

The `templates/settings.json` in this repo provides:

1. **Auto-compact at 75%** — Prevents context quality decay
2. **11 deny rules** — Blocks destructive commands at the permission layer
3. **Extended thinking** — Always-on for better reasoning
4. **Max effort** — Deepest reasoning on Opus 4.6
5. **Tool search enabled** — Defers unused tool schemas, saves 500-2K tokens per deferred tool
6. **Git instructions disabled** — Saves ~2K tokens (covered by CLAUDE.md)
7. **Prompt suggestions disabled** — Eliminates background compute after every turn
8. **Clear context on plan accept** — Clean context for implementation after planning
9. **Non-essential traffic disabled** — No telemetry noise

Merge into your `~/.claude/settings.json`:

```bash
# Review the template
cat templates/settings.json

# Merge settings (manual — review before applying)
# Copy the deny rules and env vars into your existing settings.json
```

The behavioral-core plugin adds hook-based protection on top (4-layer detection: direct patterns, shell wrappers, pipe-to-shell, flag reordering).

---

## Token Reduction

Settings that reduce the system prompt size or eliminate wasteful background work. These directly lower cost and free context budget for actual work.

### Disable Git Instructions

```json
{
  "includeGitInstructions": false
}
```

Removes ~2K tokens of git commit/PR workflow instructions from the Bash tool's system prompt section. Safe to disable when your `CLAUDE.md` already covers git conventions or when you don't need Claude to create commits/PRs.

### Disable Prompt Suggestions

```json
{
  "promptSuggestionEnabled": false,
  "env": {
    "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false"
  }
}
```

Two separate controls:
- `promptSuggestionEnabled: false` — hides the suggestion UI
- `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` — disables the fire-and-forget `executePromptSuggestion()` that runs after every turn

Set both. The background task generates next-prompt suggestions even if the UI is hidden, wasting compute.

### Tool Search / Deferred Loading

```json
{
  "env": {
    "ENABLE_TOOL_SEARCH": "true"
  }
}
```

Each tool schema costs 300-2,000 tokens. With 30-54 tools, tool definitions alone can consume 10K-50K tokens. Tool search defers unused tool schemas and loads them on demand via `ToolSearchTool`.

| Value | Behavior | Token savings |
|-------|----------|---------------|
| `"true"` | Always defer MCP and `shouldDefer` tools | ~500-2K per deferred tool |
| `"auto"` (default) | Defer when tool definitions exceed 10% of context window | Adaptive |
| `"auto:N"` | Defer when exceeding N% of context window (e.g., `"auto:5"`) | Custom threshold |
| `"false"` | No deferral, all tools loaded inline | None |

Recommended: `"true"` if you have MCP servers. The model uses `ToolSearchTool` to fetch schemas on demand — a small per-invocation cost vs permanent schema bloat.

### Clear Context on Plan Accept

```json
{
  "showClearContextOnPlanAccept": true
}
```

After you approve a plan, offers "clear context" so implementation starts with a clean context window. Prevents the planning conversation (which can be long) from consuming context during execution.

### Disable 1M Context

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_1M_CONTEXT": "1"
  }
}
```

Forces the standard context window instead of the extended 1M window. Smaller context windows compact earlier but maintain better attention quality. Useful if you're not working on tasks that need massive context.

See [Architecture: Prompt Cache](architecture.md#prompt-cache-architecture) for what busts the cache.

---

## Background Task Control

Three background operations that run asynchronously after every turn (they don't block your next message) (`src/query/stopHooks.ts:136-157`):

1. `executePromptSuggestion()` — suggests next prompts
2. `executeExtractMemories()` — auto-extracts and writes memory files
3. `executeAutoDream()` — processes auto-dream state

These modify state that the next turn reads. If you type before they complete, the model sees stale state.

### Disable Auto-Memory

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1"
  }
}
```

Disables the built-in `executeExtractMemories()` background task. **Use this if you have a marketplace memory plugin** — running two memory systems creates conflicts and wastes compute.

### Disable Non-Essential Traffic

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

Disables telemetry and non-essential network calls. Reduces background noise.

---

## Anti-Hallucination

### Anti-False-Claims Rule

The most impactful behavioral finding from the source analysis. Anthropic gates this behind `USER_TYPE === 'ant'` — a flag that identifies internal Anthropic employees. External users don't receive this instruction. Anthropic added it after false-claim rates increased significantly in newer model versions.

The instruction (replicated in `plugins/behavioral-core/hooks/rules.d/55-no-false-claims.txt`):

> Report outcomes faithfully: if tests fail, say so with the relevant output; if you did not run a verification step, say that rather than implying it succeeded. Never claim "all tests pass" when output shows failures, never suppress or simplify failing checks to manufacture a green result, and never characterize incomplete or broken work as done. When a check did pass or a task is complete, state it plainly — do not hedge confirmed results with unnecessary disclaimers or re-verify things you already checked. The goal is an accurate report, not a defensive one.

This is injected via `behavioral-anchor.sh` on every `PreToolUse` and `PostToolUse` event. External users don't get this from Claude Code — the marketplace plugin provides it.

### Numeric Length Anchors

Also ant-only (`prompts.ts:527-535`). Anthropic measured ~1.2% output token reduction vs qualitative "be concise" phrasing.

Replicated in `plugins/behavioral-core/hooks/rules.d/25-numeric-anchors.txt`:

> Keep text between tool calls to 25 words or fewer. Keep final responses to 100 words or fewer unless the task requires more detail.

Concrete numbers outperform vague "be brief" instructions because the model can actually measure against a target.

See [Claude Code Analysis](claude-code-analysis.md) for the full source analysis that discovered these features.

---

## Anti-Patterns

| Setting | Why it's bad |
|---------|-------------|
| `DISABLE_PROMPT_CACHING: "1"` | Wastes cost and increases latency |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING: "1"` | Removes dynamic thinking budget |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "95"` | Default — compacts too late |
| `bypassPermissions` without deny rules | No safety net at all |
| No `deny` rules in any settings file | Relies entirely on hooks (bypassable) |

---

## Environment Variables

Useful variables to set in `settings.json` under `"env"`:

### Claude Code Core

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `"75"` | Earlier context compaction (default 95% is too late) |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `"33000"` | Compaction window size (tokens) |
| `CLAUDE_CODE_EFFORT_LEVEL` | `"max"` | Override effort level per-session (needed for `max`) |
| `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` | `"false"` | Disable background prompt suggestion compute |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | `"1"` | Disable built-in auto-memory extraction |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `"1"` | Disable telemetry and non-essential network calls |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | `"1"` | Force standard context window |
| `CLAUDE_CODE_NO_FLICKER` | `"1"` | Reduce terminal output flicker |
| `CLAUDE_CODE_ATTRIBUTION_HEADER` | `"0"` | Disable attribution header in output |
| `ENABLE_LSP_TOOL` | `"1"` | Enable LSP-based code intelligence |
| `ENABLE_TOOL_SEARCH` | `"true"` | Defer unused tool schemas (see Token Reduction) |

### Forge Studio Plugins

| Variable | Value | Purpose |
|----------|-------|---------|
| `FORGE_CONTEXT_STAGE1` - `STAGE5` | `"8"/"15"/"22"/"30"/"40"` | Context pressure message-count thresholds |
| `FORGE_CONTEXT_PCT1` - `PCT5` | `"50"/"65"/"75"/"85"/"92"` | Context pressure percentage thresholds |
| `FORGE_LARGE_FILE_LINES` | `"500"` | Large file warning threshold (line count) |
| `FORGE_TRACES_ENABLED` | `"1"` or `"0"` | Enable/disable execution trace collection |
| `FORGE_SELF_REVIEW_INTERVAL` | `"3"` | Edits between self-review nudges (default 3) |
| `FORGE_FAILURE_THRESHOLD` | `"3"` | Consecutive failures before escalation warning (default 3) |
| `FORGE_TEST_NUDGE_INTERVAL` | `"3"` | Edits between test-run nudges (default 3) |
| `FORGE_TEST_ESCALATION_INTERVAL` | `"6"` | Edits before escalated test warning with JSON additionalContext (default 2× nudge interval) |
| `FORGE_EXPLORE_DEPTH` | `"6"` | Exploratory calls before edit gate lifts (IDE-Bench recommends 8+) |
| `FORGE_EVALUATION_GATE` | `"1"` or `"0"` | Enable/disable pre-commit evaluation gate |
| `FORGE_RESEARCH_GATE` | `"1"` or `"0"` | Enable/disable read-before-edit enforcement |

---

## Internal Behavior Notes

Observations from Claude Code's source (`src/`) relevant to settings:

- **Auto-compact buffer**: The compaction window is approximately 33K tokens. Set `CLAUDE_CODE_AUTO_COMPACT_WINDOW` to tune this.
- **Deny rules evaluated before hooks** — deny rules fire at the permission layer, before PreToolUse hooks. This means deny rules are the primary safety net.
- **`opusplan` alias** — uses Opus for planning, Sonnet for execution. Useful for cost-efficient architectural work.
- **Shell wrapper bypass** — `bash -c 'rm -rf /'` passes both deny rules and simple regex hooks, motivating the multi-layer detection in behavioral-core.
- **`auto` mode classifier** — server-side safety classifier available on Team/Enterprise plans.
- **System prompt size: 14.5K-63.5K tokens** — assembled from 20+ conditional sections before the model sees any user message. Tool schemas are the largest contributor (30-54 tools x 300-2K tokens each).
- **`CLAUDE_CODE_SIMPLE=1`** — reduces system prompt to ~50 tokens. Useful for subagents that only need search/read. Trade-off: loses all behavioral guidance.
- **Feature flags create 2^N variants** — 20+ internal flags (`PROACTIVE`, `KAIROS`, `COORDINATOR_MODE`, etc.) conditionally include/exclude prompt sections. The model was trained against specific combinations but deployed with different ones.
- **Function result clearing** — under context pressure, Claude Code silently evicts old tool results. File reads from 10+ turns ago may no longer be in context. This is why the `track-edits` hook exists.
- **Fire-and-forget race condition** — `executeExtractMemories()` runs async after each turn. If you type before it completes, the model reads stale memory. No mitigation exists in the binary.
- **MCP instructions bust prompt cache** — marked `DANGEROUS_uncachedSystemPromptSection`. Every MCP server connect/disconnect invalidates ~20K tokens of cached system prompt.
- **Ant-only features** — internal employees get: anti-false-claims instruction (29-30% false claim rate without it), numeric length anchors (~1.2% token reduction), Config/Tungsten/REPL tools, coordinator mode. The marketplace replicates the behavioral ones via hooks.