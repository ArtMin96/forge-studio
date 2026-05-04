# Claude Code Token Optimization — Research Report

Date: 2026-04-07
Confidence: High (primarily sourced from official Anthropic docs, the Claude Code team's own engineering posts, and verified community benchmarks)

---

## Table of Contents

1. [Where Tokens Actually Go (Benchmarks)](#1-where-tokens-actually-go)
2. [Prompt Caching — The Single Biggest Lever](#2-prompt-caching)
3. [Context Window Management and Compaction](#3-context-window-management)
4. [Model Selection and Extended Thinking](#4-model-selection-and-extended-thinking)
5. [Subagent Efficiency](#5-subagent-efficiency)
6. [Hook-Based Optimizations](#6-hook-based-optimizations)
7. [MCP and Tool Overhead](#7-mcp-and-tool-overhead)
8. [Third-Party Tools and Plugins](#8-third-party-tools-and-plugins)
9. [Configuration Reference](#9-configuration-reference)
10. [Actionable Checklist](#10-actionable-checklist)

---

## 1. Where Tokens Actually Go

**Confirmed (Anthropic docs + engineering posts):**

| Category | Typical Token Cost | Notes |
|---|---|---|
| System prompt + tool schemas + CLAUDE.md | 25,000-35,000 | Before your first message |
| MCP tool definitions (5 servers, ~58 tools) | ~55,000 | Anthropic has seen 134K internally before optimization |
| Single file read (100 lines) | 1,000-1,600 | Code with long lines costs more |
| Single file read (500 lines) | 5,000-8,000 | This is a major token sink |
| Each tool invocation overhead | 50-200 | Function call structure, params, return formatting |
| 50+ tool calls session overhead | 2,500-10,000 | Cumulative |
| Extended thinking (default) | Up to 31,999/request | Billed as output tokens |
| Agent teams | ~7x standard sessions | Each teammate has its own context window |
| A "simple" edit command end-to-end | 50,000-150,000 | Read + generate edit + test + verify |
| 20 file reads + 10 edits session | 150,000+ | With full reads and full rewrites |
| Background usage (idle) | ~$0.04/session | Summarization, command processing |

**Key insight:** A coding session with Claude Code routinely consumes 10x-100x more tokens than a typical chat because of the agentic loop: read file (input), generate edit (output), run test (input from output), re-read to verify (input again).

**Source:** [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs), [Best Practices — Claude Code Docs](https://code.claude.com/docs/en/best-practices)

---

## 2. Prompt Caching

### How It Works

Every message you send re-transmits the entire conversation to the API. Message 1 sends system prompt + tools + CLAUDE.md + your message. Message 50 sends all of that plus 49 prior rounds. Without caching, this is catastrophically expensive.

Claude Code handles caching automatically. You cannot add more caching on top, and you do not need to. The system uses prefix matching — it caches everything from the start of the request up to cache_control breakpoints.

### Cost Impact

- Cache write tokens: 1.25x base input price (5-min TTL) or 2x (1-hour TTL)
- Cache read tokens: 0.1x base input price (90% discount)
- Real-world savings: A 100-turn Opus session without caching costs $50-100 in input tokens. With caching: $10-19.
- A single cache failure caused a 10x cost spike for one hour (from Anthropic's own incident reports)
- The Claude Code team monitors cache hit rate like uptime — cache breaks are treated as incidents

### What Breaks the Cache (CONFIRMED)

These are verified causes from the Claude Code engineering team:

1. **Adding/removing MCP tools mid-session** — Tools are part of the cached prefix. Any change invalidates everything after it. This is why Claude Code locks the tool list at startup.
2. **Switching models mid-conversation** — Rebuilding the cache for a new model can cost more than keeping the expensive model. 100K tokens into an Opus conversation, switching to Haiku to "save money" actually costs more because the entire cache must rebuild.
3. **Modifying the system prompt** — Every edit invalidates the entire cached prefix. Claude Code leaves the system prompt untouched after the first request.
4. **Non-deterministic tool ordering** — If tools serialize in different order between requests, the cache breaks even if the tools themselves are identical.
5. **Timestamps in system prompts** — A new timestamp per request means the first tokens differ every time. Nothing downstream can cache.
6. **Changing tool_choice or image usage patterns** between calls.

### Design Decisions That Preserve Cache

- **Plan mode uses tools, not tool-set swaps.** Instead of swapping to read-only tools (which would break cache), Claude Code keeps all tools present and uses EnterPlanMode/ExitPlanMode as tools themselves.
- **Context updates go in user messages, not system prompts.** Changed context is wrapped in `system-reminder` tags within user messages, preserving the cached system prompt prefix.
- **MCP tools use `defer_loading` stubs.** Only tool names enter context. Full schemas load on-demand via ToolSearch. This keeps the cached prefix stable and saves context.
- **Model switching uses subagents.** Different models run as separate subagent conversations, keeping the parent's cache intact.

### Best Practices

- Do not add/remove MCP servers mid-session
- Do not switch models in the main conversation (use subagents)
- Do not embed dynamic data in CLAUDE.md or system prompts
- Keep sessions active (cache expires after ~5 minutes of inactivity; each hit resets the timer)
- Minimum cacheable length: 1,024 tokens (Claude Code's system prompt alone is ~4,000, so this is always met)

**Sources:** [Claude Code Cache Design — 90% Cost Cut](https://tonylee.im/en/blog/claude-code-cache-design-90-percent-cost-cut), [Prompt Caching — Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [Tool Use with Prompt Caching](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-use-with-prompt-caching)

---

## 3. Context Window Management

### How Compaction Works

Auto-compaction triggers when the context window approaches its limit (~200K tokens for flagship models). Claude summarizes the conversation history into a compressed form to free space.

**What survives compaction:**
- CLAUDE.md files — loaded fresh from disk after compaction (verbatim)
- Tool definitions — remain in the system prompt
- The summary itself — Claude's best-effort compression of the conversation

**What gets lost:**
- Exact code snippets and detailed outputs
- Nuanced instructions given mid-conversation
- "Personality" and tone established during the session
- Specific architectural decisions unless they were prominent

### Custom Compaction

You can guide what gets preserved:
```text
/compact Focus on code samples and API usage
/compact Keep the auth flow decisions, the current test plan, and the open TODOs
```

In CLAUDE.md:
```markdown
# Compact instructions
When you are using compact, please focus on test output and code changes
```

### Selective Compaction

Use `Esc + Esc` or `/rewind`, select a message checkpoint, and choose "Summarize from here" — this condenses from that point forward while keeping earlier context intact.

### Hook-Based Context Restoration

- **PreCompact** hooks inject content into the context being summarized (but it gets paraphrased, not preserved verbatim)
- **PostCompact** hooks run after compaction completes, receiving the `compact_summary`. They have no decision control (cannot modify the result) but can perform follow-up tasks
- **SessionStart with `compact` source** — When a session resumes after compaction, a SessionStart hook can re-inject critical context from a file

**Workaround pattern for lossless memory through compaction:**
1. PreCompact hook captures state to a file
2. PostCompact hook (or SessionStart on compact) reads the file and re-injects it

### Proactive Strategy

- `/clear` between unrelated tasks (most impactful habit)
- `/compact` at ~70% capacity, not when auto-compact triggers at ~95%
- `/usage` or status line to monitor usage continuously
- `/btw` for quick questions that should not enter conversation history
- Target: sessions under 30K tokens, compact at 70%, reset every 20 iterations

**Sources:** [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs), [Best Practices — Claude Code Docs](https://code.claude.com/docs/en/best-practices), [PostCompact Hook Feature Request #32026](https://github.com/anthropics/claude-code/issues/32026)

---

## 4. Model Selection and Extended Thinking

### Model Selection

| Model | Use Case | Relative Cost |
|---|---|---|
| Opus | Complex multi-file refactors, architecture, debugging gnarly issues | Highest |
| Sonnet | Writing tests, simple edits, explaining code, ~80% of daily work | Medium |
| Haiku | Quick lookups, formatting, renaming, repetitive tasks, subagent exploration | Lowest |

Switch with `/model` mid-session. Set default in `/config` or `settings.json`.

**Important caveat:** Switching models in the main conversation breaks prompt cache (see Section 2). Use subagents for model switching instead.

### Extended Thinking

Extended thinking is enabled by default and reserves up to 31,999 output tokens per request.

**Effort levels** (`/effort`):
- **low** — Simple, well-defined tasks. May skip thinking entirely.
- **medium** — Everyday dev work: bugs, features, refactoring.
- **high** (default) — Complex reasoning, nuanced analysis.
- **max** — Opus 4.6 only.
- **auto** — Claude decides per-task.

**Cost reduction:** Setting `MAX_THINKING_TOKENS=8000` or `MAX_THINKING_TOKENS=10000` cuts hidden thinking cost by ~70%.

**Recommended cost-optimized settings.json:**
```json
{
  "model": "sonnet",
  "env": {
    "MAX_THINKING_TOKENS": "10000",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  }
}
```

This yields ~60% cost reduction versus always running Opus with default thinking.

Note: `budget_tokens` is deprecated on Claude Opus 4.6 and Sonnet 4.6. Use the effort parameter instead.

**Sources:** [Effort — Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/effort), [Claude Code Effort Levels Explained](https://www.mindstudio.ai/blog/claude-code-effort-levels-explained)

---

## 5. Subagent Efficiency

### How Subagents Save Context

Each subagent runs in its own fresh conversation. Intermediate tool calls and results stay inside the subagent. Only the final summary returns to the parent. This is the primary mechanism for avoiding context pollution.

A research-assistant subagent can explore dozens of files without any of that content accumulating in the main conversation. The parent receives a concise summary, not every file the subagent read.

### The Cost Trade-off

Subagents reduce context bloat in the main session but they still consume tokens in their own sessions. Parallel subagents drain quota proportionally to concurrency. Five parallel subagents burn tokens 5x as fast as one sequential session.

### Best Practices (CONFIRMED)

1. **Use lighter models for subagents.** Main session on Opus, subagents on Sonnet or Haiku. Set `CLAUDE_CODE_SUBAGENT_MODEL=haiku` or specify `model: haiku` in agent definitions.
2. **Craft precise invocation prompts.** The only channel from parent to subagent is the prompt string. Include file paths, error messages, and decisions directly.
3. **Use subagents for high-volume read operations.** Tests, documentation fetching, log processing, codebase exploration — anything that generates verbose output.
4. **Use subagents for verification.** After Claude implements something, spin up a subagent to review the code. Fresh context avoids confirmation bias.
5. **Custom subagent definitions** in `.claude/agents/` can restrict tools, set models, and provide specialized instructions.
6. **Avoid vague exploration tasks.** An unscoped "investigate" request can cause a subagent to read hundreds of files.

### When NOT to Use Subagents

- Simple tasks where the overhead of spawning exceeds the savings
- When the parent already has the needed context (no point re-reading)
- On rate-limited plans where parallel consumption hits limits faster

**Sources:** [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents), [Claude Code Sub Agents — DEV Community](https://dev.to/onlineeric/claude-code-sub-agents-burn-out-your-tokens-4cd8)

---

## 6. Hook-Based Optimizations

### PreToolUse for Preventing Waste

**Exit code semantics:**
- `0` — info (tool proceeds)
- `1` — warning (tool proceeds with warning)
- `2` — block the action (PreToolUse blocks tool call, PreCompact blocks compaction)

**Pattern: Filter verbose output before Claude sees it**

Instead of Claude reading a 10,000-line log file, a PreToolUse hook can grep for `ERROR` and return only matching lines — reducing context from tens of thousands of tokens to hundreds.

Example from official docs — filter test output to show only failures:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/filter-test-output.sh"
          }
        ]
      }
    ]
  }
}
```

The script checks if the command is a test runner and modifies it to show only failures via `updatedInput`.

**Pattern: Slow down token burn (sleep hook)**

A hook with `"matcher": "Write|Edit"` and `"command": "sleep 30"` creates intentional pauses before writes, giving you time to review and intervene. Simple but effective for preventing runaway autonomous sessions.

**Pattern: Block writes to protected files**

A PreToolUse hook that exits with code 2 prevents edits to production-critical files entirely.

### Input Modification (v2.0.10+)

PreToolUse hooks can modify tool inputs before execution. Instead of blocking and forcing retries (which wastes tokens on the retry), hooks intercept, correct, and allow — one pass instead of two.

Use cases: automatic dry-run flags, secret redaction, convention enforcement.

### PostToolUse for Auto-Linting

Run linters/formatters after every edit automatically. Catches issues immediately instead of accumulating them for a costly fix-all-at-once pass.

### PostCompact for Context Restoration

See Section 3. The PreCompact/PostCompact pipeline can create lossless memory through compaction cycles.

**Sources:** [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks), [Hitting the Brakes on Claude Code](https://preslav.me/2025/07/26/claude-code-token-burn-slow-down-hooks/), [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs)

---

## 7. MCP and Tool Overhead

### The Problem

MCP tool definitions are one of the most overlooked token costs. They consume 8-30% of your context window before you do anything.

Specific numbers:
- A typical 5-server, 58-tool setup: ~55K tokens of overhead
- Jira MCP alone: ~17K tokens
- Anthropic has seen setups where tool definitions consume 134K tokens

### Mitigation (CONFIRMED — Official)

1. **Deferred loading (default since ~2025).** MCP tools use `defer_loading` — only tool names enter context (~30-50 tokens each). Full schemas load on-demand via ToolSearch. This preserves prompt cache stability and reduces context by ~85%.

2. **Prefer CLI tools.** `gh`, `aws`, `gcloud`, `sentry-cli` add zero per-tool listing overhead. Claude runs CLI commands directly via Bash. This is officially more context-efficient than MCP servers.

3. **Disable unused servers.** Run `/mcp` to see configured servers. Disable anything not needed for the current task. Use `/context` to see what is consuming space.

4. **Install code intelligence plugins** for typed languages. A single "go to definition" call replaces what might otherwise be a grep + reading multiple candidate files. Language servers also report type errors automatically after edits.

5. **`MAX_MCP_OUTPUT_TOKENS`** environment variable. Default: 25,000. Claude Code warns when MCP output exceeds 10,000 tokens. Lower this to prevent MCP tools from flooding context.

**Sources:** [Connect Claude Code to tools via MCP — Claude Code Docs](https://code.claude.com/docs/en/mcp), [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs)

---

## 8. Third-Party Tools and Plugins

### Token Optimization Plugins (Community)

| Tool | Mechanism | Claimed Savings | Notes |
|---|---|---|---|
| [RTK Token Optimizer](https://mcpmarket.com/tools/skills/rtk-token-optimizer) | PreToolUse hook intercepting Bash commands, filtering redundant git/docker/test output | 60-90% | Performance-focused proxy; well-reviewed |
| [Toonify MCP](https://github.com/PCIRCLE-AI/toonify-mcp) | Token compression for structured data (JSON/CSV/YAML) and source code | 25-66% on data, 20-48% on code | Plugin for Claude Code |
| [Token Optimizer MCP](https://github.com/ooples/token-optimizer-mcp) | Caching, compression, smart tool intelligence | Claims 95%+ | Ambitious claims; verify independently |
| [claude-token-efficient](https://github.com/drona23/claude-token-efficient) | A single CLAUDE.md that keeps responses terse | Reduces output verbosity | Drop-in, no code changes |
| [prompt-caching plugin](https://github.com/flightlesstux/prompt-caching) | Automatic prompt caching for repeated file reads | Up to 90% on repeated reads | Zero config |

### Skills vs. MCP for Context Efficiency

- Skills use ~30-50 tokens each, loaded on-demand
- MCP servers can use 50K+ tokens
- For most workflows: 2-3 MCP servers (GitHub, Filesystem, one domain-specific) + custom Skills

### Move CLAUDE.md Instructions to Skills

Specialized instructions (PR review checklists, migration guides, etc.) should be skills, not CLAUDE.md entries. Skills load on-demand; CLAUDE.md loads every session. Aim for CLAUDE.md under 200 lines.

**Caveat:** Anthropic advises using third-party MCP servers at your own risk — they have not verified the correctness or security of all servers.

**Sources:** [Claude Code Skills vs MCP vs Plugins — Complete Guide](https://www.morphllm.com/claude-code-skills-mcp-plugins), [Best Claude Code Plugins 2026](https://www.turbodocx.com/blog/best-claude-code-skills-plugins-mcp-servers)

---

## 9. Configuration Reference

### Environment Variables

| Variable | Default | Effect |
|---|---|---|
| `MAX_THINKING_TOKENS` | 31,999 | Cap on extended thinking tokens per request |
| `MAX_MCP_OUTPUT_TOKENS` | 25,000 | Cap on MCP tool output tokens |
| `CLAUDE_CODE_SUBAGENT_MODEL` | (inherits parent) | Model for subagents |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | 0 | Enable agent teams |

### Settings.json (Cost-Optimized Template)

```json
{
  "model": "sonnet",
  "env": {
    "MAX_THINKING_TOKENS": "10000",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
    "MAX_MCP_OUTPUT_TOKENS": "15000"
  }
}
```

### Key Commands

| Command | Purpose |
|---|---|
| `/usage` | Token usage for current session and Pro/Max usage patterns |
| `/clear` | Reset context between tasks |
| `/compact [instructions]` | Manual compaction with optional focus |
| `/context` | See what is consuming context space |
| `/model` | Switch model |
| `/effort` | Set thinking effort level |
| `/mcp` | View/manage MCP servers |
| `/btw` | Side question that does not enter conversation history |
| `/rewind` or `Esc+Esc` | Restore to checkpoint or selectively summarize |

### Automation Safeguards

For CI/CD and unattended runs:
- `--max-turns N` — limit number of agent loop iterations
- `--timeout-minutes N` — hard time limit
- `--allowedTools "Edit,Bash(git commit *)"` — restrict tool access
- `--permission-mode auto` — classifier-based auto-approval with abort on repeated blocks

---

## 10. Actionable Checklist

### Immediate Wins (do today)

- [ ] Set default model to Sonnet in settings.json
- [ ] Set `MAX_THINKING_TOKENS` to 10000
- [ ] Set `CLAUDE_CODE_SUBAGENT_MODEL` to haiku
- [ ] Run `/mcp` and disable unused MCP servers
- [ ] Audit CLAUDE.md — keep under 200 lines, move specialized content to skills
- [ ] Start using `/clear` between unrelated tasks

### Medium-Term (this week)

- [ ] Add a PreToolUse hook to filter test output to failures only
- [ ] Create skills for specialized workflows (PR review, migrations, etc.)
- [ ] Install code intelligence plugins for your primary language
- [ ] Configure status line to show context usage continuously
- [ ] Set up custom compaction instructions in CLAUDE.md
- [ ] Replace MCP servers with CLI tools where possible (gh, aws, etc.)

### Ongoing Habits

- [ ] Monitor `/usage` regularly — know your per-session spend
- [ ] `/compact` at 70% capacity, not when auto-compact triggers at 95%
- [ ] Use subagents for codebase exploration, test running, log analysis
- [ ] Use plan mode for complex tasks (prevents expensive re-work)
- [ ] Never switch models in the main conversation — use subagents
- [ ] Scope prompts precisely — vague requests trigger broad scanning
- [ ] Provide verification targets (tests, expected output) so Claude self-corrects in one pass
- [ ] After 2 failed corrections: `/clear` and restart with a better prompt

### What NOT to Do

- Do NOT embed timestamps or dynamic data in CLAUDE.md
- Do NOT add/remove MCP servers mid-session (breaks cache)
- Do NOT switch models in the main conversation (breaks cache)
- Do NOT let sessions accumulate unrelated context
- Do NOT ask Claude to reformat something it already produced (doubles cost)
- Do NOT read entire large files when you only need a section
- Do NOT leave agent teams running idle (they still consume tokens)

---

## Confidence Assessment

| Finding | Confidence | Source |
|---|---|---|
| Prompt caching mechanics and what breaks it | Very High | Claude Code engineering team, official docs |
| Token costs by operation category | High | Official docs, multiple corroborating sources |
| Compaction behavior and what survives | High | Official docs, GitHub issues with team responses |
| Model selection cost differences | High | Official pricing, docs |
| Subagent token trade-offs | High | Official docs, community benchmarks |
| Hook-based optimization patterns | High | Official docs, verified community implementations |
| Third-party plugin savings claims | Medium | Community claims, not independently verified |
| Specific dollar amounts ($6/dev/day average) | Medium | Official but will vary significantly by usage pattern |
| MAX_THINKING_TOKENS impact estimate (~70% reduction) | Medium | Community measurement, plausible but context-dependent |

---

## Sources

### Official Anthropic Documentation
- [Manage costs effectively — Claude Code Docs](https://code.claude.com/docs/en/costs)
- [Best Practices — Claude Code Docs](https://code.claude.com/docs/en/best-practices)
- [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Prompt caching — Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Tool use with prompt caching](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-use-with-prompt-caching)
- [Effort — Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp)
- [Create custom subagents](https://code.claude.com/docs/en/sub-agents)

### Engineering/Technical Analysis
- [Claude Code Cache Design — 90% Cost Cut](https://tonylee.im/en/blog/claude-code-cache-design-90-percent-cost-cut)
- [Claude Code Token Limits — Faros.ai](https://www.faros.ai/blog/claude-code-token-limits)
- [Claude Code Token Management 2026 — Richard Porter](https://richardporter.dev/blog/claude-code-token-management)
- [Hitting the Brakes on Claude Code — Preslav Rachev](https://preslav.me/2025/07/26/claude-code-token-burn-slow-down-hooks/)
- [Stop Wasting Tokens — Medium](https://medium.com/@jpranav97/stop-wasting-tokens-how-to-optimize-claude-code-context-by-60-bfad6fd477e5)

### Community Tools
- [RTK Token Optimizer](https://mcpmarket.com/tools/skills/rtk-token-optimizer)
- [Toonify MCP](https://github.com/PCIRCLE-AI/toonify-mcp)
- [Token Optimizer MCP](https://github.com/ooples/token-optimizer-mcp)
- [claude-token-efficient CLAUDE.md](https://github.com/drona23/claude-token-efficient)

### Community Guides
- [6 Ways I Cut My Claude Token Usage in Half — Sabrina.dev](https://www.sabrina.dev/p/6-ways-i-cut-my-claude-token-usage)
- [18 Claude Code Token Management Hacks — MindStudio](https://www.mindstudio.ai/blog/claude-code-token-management-hacks)
- [Managing Costs — Steve Kinney](https://stevekinney.com/courses/ai-development/cost-management)
- [Claude Code Sub-Agents — DEV Community](https://dev.to/onlineeric/claude-code-sub-agents-burn-out-your-tokens-4cd8)
