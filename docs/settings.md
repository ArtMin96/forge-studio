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

### Recommendation

- **Interactive work**: `default` or `acceptEdits` + deny rules
- **AFK / hands-off**: `auto` if available (Team/Enterprise plan), otherwise `bypassPermissions` + deny rules + iron-rules hooks
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
| Catches wrappers | No (`bash -c 'rm -rf /'` passes) | Yes (Layer 2 in iron-rules) |
| Configuration | settings.json | hooks.json + shell scripts |

**Use both.** Deny rules are the safety net that can't be overridden. Hooks catch what deny rules miss.

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
  "effortLevel": "high"
}
```

| Level | Use case | Cost |
|-------|----------|------|
| `low` | Simple tasks, classification | Cheap |
| `medium` | Most coding tasks | Balanced |
| `high` | Complex debugging, architecture | Higher |
| `max` | Deepest reasoning (Opus 4.6 only) | Highest |

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

### Model Aliases

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
2. **18 deny rules** — Blocks destructive commands at the permission layer
3. **Extended thinking** — Always-on for better reasoning
4. **High effort** — Maximum quality (downgrade to `medium` if cost-sensitive)

Merge into your `~/.claude/settings.json`:

```bash
# Review the template
cat templates/settings.json

# Merge settings (manual — review before applying)
# Copy the deny rules and env vars into your existing settings.json
```

The iron-rules plugin adds hook-based protection on top (4-layer detection: direct patterns, shell wrappers, pipe-to-shell, flag reordering).

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

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `"75"` | Earlier context compaction |
| `ENABLE_LSP_TOOLS` | `"1"` | Enable LSP-based code intelligence |
| `NODE_ENV` | `"development"` | Set Node environment |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `"33000"` | Compaction window size (tokens) |

---

## Source Code Leak Insights (March 31, 2026)

A packaging error exposed Claude Code's source. Relevant findings for settings:

- **Auto-compact buffer** was reduced from 45K to 33K tokens internally
- **14 cache-break vectors** tracked — explains why prompt caching matters
- **Deny rules evaluated before hooks** — confirmed in the permission evaluation pipeline
- **`opusplan` alias** discovered — uses Opus for planning, Sonnet for execution
- **`effortLevel: "max"`** exists — deepest reasoning with no token limit (Opus 4.6 only)
- **Frustration detection** — regex matching on user messages adjusts response tone
- **Shell wrapper bypass** — `bash -c 'rm -rf /'` passes both deny rules and simple regex hooks, motivating the multi-layer detection in iron-rules
- **`auto` mode classifier** — server-side safety classifier for Team/Enterprise plans

See the full leak analysis for unreleased features (KAIROS, BUDDY, ULTRAPLAN, Swarms) and internal codenames.
