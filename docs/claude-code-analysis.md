# Claude Code Source Analysis

This document is for users who want to understand how Claude Code's internal architecture affects model performance, and how Forge Studio compensates. It references Claude Code's source code — treat file path citations as supporting evidence, not required reading.

**Audience:** Advanced users and plugin developers. If you're new to Forge Studio, start with [Architecture](architecture.md) instead.

Terms like 'system-reminder', 'fire-and-forget', and 'ant-only' are defined in the [Glossary](architecture.md#glossary).

Analysis of Claude Code's internal source (`src/`) to understand how the harness architecture creates model performance degradation, compared against Forge Studio's approach.

## Degradation Mechanisms

### 1. System Prompt Bloat (14.5K-63.5K tokens)

**Source:** `src/constants/prompts.ts:444-577`

The system prompt is assembled from 20+ conditional sections via `getSystemPrompt()`. Before the model sees a single user message, it processes:

| Section | Tokens (est.) | Source |
|---------|--------------|--------|
| Static instructions (intro, system, tasks, actions, tools, tone, efficiency) | ~3,500 | `prompts.ts` |
| Dynamic sections (session guidance, memory, env, language, output style, MCP, scratchpad) | ~1,000-2,000 | `prompts.ts:491-555` |
| Tool schemas (30-54 tools x 300-2,000 tokens each) | ~10,000-50,000 | `tools.ts:193-251` |
| MCP server instructions | ~0-5,000 | `DANGEROUS_uncachedSystemPromptSection` |
| **Total** | **~14,500-63,500** | |

**Why it degrades:** More instruction surface means more competing directives. The model must reconcile overlapping guidance from static sections, dynamic sections, output styles, CLAUDE.md content, hooks, and system-reminders. Priority becomes ambiguous. Research shows instruction-following accuracy drops as instruction count increases.

### 2. Cache-Busting Dynamic Sections

**Source:** `src/constants/systemPromptSections.ts:32-38`

Two-tier caching strategy:
- `systemPromptSection()` — computed once, cached until `/clear` or `/compact`
- `DANGEROUS_uncachedSystemPromptSection()` — recomputed every turn, explicitly breaks prompt cache

MCP instructions are the primary cache-buster (`prompts.ts:513-520`):

```typescript
DANGEROUS_uncachedSystemPromptSection(
  'mcp_instructions',
  () => isMcpInstructionsDeltaEnabled() ? null : getMcpInstructionsSection(mcpClients),
  'MCP servers connect/disconnect between turns'
)
```

**Why it degrades:** Every MCP connect/disconnect invalidates ~20K tokens of cached system prompt. The model re-processes the entire prompt from scratch, losing warmed-up attention patterns. The `isMcpInstructionsDeltaEnabled()` gate provides a mitigation path (delta announcements via attachments instead), but it's feature-gated and not always enabled.

### 3. System-Reminder Accumulation

**Source:** `src/utils/messages.ts:3097-3098`, `src/utils/attachments.ts:266-276`

Every hook output, attachment, skill discovery, task list, memory file, and IDE context gets wrapped in `<system-reminder>` tags:

```typescript
export function wrapInSystemReminder(content: string): string {
  return `<system-reminder>\n${content}\n</system-reminder>`
}
```

There is no global deduplication. The `smooshSystemReminderSiblings` function (`messages.ts:1846-1852`) merges adjacent system-reminders within a single message, but not across messages.

Memory injection budget: 5 files/turn x 4KB = 20KB/turn (`attachments.ts:271-276`).

**Why it degrades:** The model treats system-reminders as authoritative context. Repeated injection of identical content wastes context budget and creates instruction echo chambers — the model over-indexes on frequently repeated directives while under-weighting less-repeated but equally important ones.

### 4. Tool Schema Inflation (30-54 tools)

**Source:** `src/tools.ts:193-251`

`getAllBaseTools()` registers tools conditionally:

| Category | Count | Gate |
|----------|-------|------|
| Always available (Agent, Bash, Read, Edit, Write, Glob, Grep, etc.) | ~17 | None |
| Feature-gated (Config, Tungsten, WebBrowser, REPL, Workflow, etc.) | ~20 | `USER_TYPE`, feature flags, optional imports |
| Task tools (Create, Get, Update, List) | 4 | `isTodoV2Enabled()` |
| Worktree tools | 2 | `isWorktreeModeEnabled()` |
| MCP tools | Unbounded | Connected MCP servers |

**Why it degrades:** Each tool schema costs 300-2,000 tokens. At 54 tools, potentially 50K tokens just for definitions. The model considers all available tools for every action, increasing decision complexity. Tool schema size often exceeds the actual instruction content.

### 5. Deferred Tool Hallucination

**Source:** `src/tools.ts:247-249`, tool search pipeline in `src/services/api/claude.ts`

Tools with `defer_loading: true` are stripped from API calls but announced in `<available-deferred-tools>` blocks. The model knows tool names exist but has no schema.

```typescript
// Include ToolSearchTool when tool search might be enabled (optimistic check)
// The actual decision to defer tools happens at request time in claude.ts
...(isToolSearchEnabledOptimistic() ? [ToolSearchTool] : []),
```

**Why it degrades:** The "optimistic check" can include `ToolSearchTool` when tool search isn't actually enabled at request time. The model sees deferred tool names and may hallucinate parameters instead of fetching the schema via `ToolSearchTool`. This is a known trade-off between schema size reduction and invocation accuracy.

### 6. Output Style Instruction Override

**Source:** `src/constants/outputStyles.ts:11-23`, `src/constants/prompts.ts:564-567`

Output styles can suppress the core software engineering instructions:

```typescript
outputStyleConfig === null || outputStyleConfig.keepCodingInstructions === true
  ? getSimpleDoingTasksSection()
  : null,
```

Custom output styles inject arbitrary, unvalidated text as first-class system prompt content. The `prompt` field in `OutputStyleConfig` has no constraints.

**Why it degrades:** A style with `keepCodingInstructions: false` removes the "Doing Tasks" section — the model loses guidance on file management, bug fixing, and feature development. This is intended for non-coding use cases but creates a silent failure mode.

### 7. Fire-and-Forget Background Mutations

**Source:** `src/query/stopHooks.ts:136-157`

Three background operations fire after every turn without blocking:

```typescript
void executePromptSuggestion(stopHookContext)        // Suggest next prompts
void extractMemoriesModule!.executeExtractMemories(  // Extract and write memory files
  stopHookContext, toolUseContext.appendSystemMessage,
)
void executeAutoDream(stopHookContext, ...)           // Auto-dream state processing
```

**Why it degrades:** These modify state (memory files, suggestions) that the next turn reads. If the user sends a message before extraction completes, the model sees stale memory. This is architecturally unresolvable in a fire-and-forget design — the only mitigation is "hope the user types slowly."

### 8. Feature Flag Explosion

**Source:** Throughout `src/constants/prompts.ts`, `src/tools.ts`

Known feature flags that modify the prompt: `PROACTIVE`, `KAIROS`, `KAIROS_BRIEF`, `COORDINATOR_MODE`, `EXTRACT_MEMORIES`, `TEMPLATES`, `TOKEN_BUDGET`, `EXPERIMENTAL_SKILL_SEARCH`, `CHICAGO_MCP`, `BREAK_CACHE_COMMAND`, `CACHED_MICROCOMPACT`, `HISTORY_SNIP`, plus `USER_TYPE === 'ant'` conditional blocks.

**Why it degrades:** 2^N possible instruction variants. Each flag conditionally includes/excludes prompt sections and tools. Contradictions between flag-gated sections are undetectable at the individual flag level. The model was trained/evaluated against specific combinations but deployed with different ones.

### 9. Volatile System Context

**Source:** `src/context.ts:116-149`

System context includes git status (capped at 2K chars), current date, and an optional cache-breaker. Git status is captured once at session start and never updated.

```typescript
return {
  ...(gitStatus && { gitStatus }),
  ...(feature('BREAK_CACHE_COMMAND') && injection
    ? { cacheBreaker: `[CACHE_BREAKER: ${injection}]` }
    : {}),
}
```

**Why it degrades:** Stale git status occupies permanent context. The model treats it as current truth. Current date injection means no cross-session prompt caching. The `BREAK_CACHE_COMMAND` feature explicitly injects content to bust the cache — a debugging mechanism that costs tokens when active.

---

## Head-to-Head: Claude Code vs Forge Studio

| Harness Component | Claude Code | Forge Studio | Analysis |
|-------------------|-------------|--------------|----------|
| **Behavioral steering** | Output styles + scattered system prompt instructions (~80% compliance in long conversations) | Modular `rules.d/` files + per-message hook re-injection (~100% compliance) | **Forge Studio wins.** Hooks fire at decision points. Instructions drift. |
| **Context management** | Automatic compression with no user visibility. `CACHED_MICROCOMPACT` feature clears old tool results silently. | 5-stage progressive warnings + pre/post-compact hooks that save/restore state | **Forge Studio wins.** Users get advance warning. State survives compaction. |
| **Memory** | Single MEMORY.md (200-line cap, 25KB limit) + fire-and-forget auto-extraction with race conditions | 3-tier architecture (index/topics/transcripts) with verified dates and staleness awareness | **Forge Studio wins.** Structured, staleness-aware, no race conditions. |
| **Tool management** | Deferred loading reduces active tool count. `ToolSearchTool` fetches schemas on demand. | N/A — relies on Claude Code's native mechanism | **Gap.** Forge Studio doesn't monitor or optimize tool count. |
| **Prompt cache** | Global/ephemeral split with `SYSTEM_PROMPT_DYNAMIC_BOUNDARY`. MCP instructions marked DANGEROUS_uncached. | N/A — relies on Claude Code's native mechanism | **Gap.** Forge Studio users are unaware of what busts their cache. |
| **Multi-agent** | `AgentTool` with `subagent_type` (explore, plan, general-purpose). Tool restrictions per agent type. | Planner/Generator/Reviewer triad with explicit capability isolation | **Forge Studio wins.** Explicit tool restriction boundaries. Reviewer can't edit. |
| **System-reminder control** | Unbounded accumulation + within-message smoosh heuristics | Hooks inject targeted context. No deduplication mechanism for accumulated reminders. | **Partial gap.** Forge Studio is cleaner per-injection but doesn't track total accumulation. |
| **Quality gates** | None built-in. Relies on user discipline. | Static analysis hooks (PHPStan, ESLint), adversarial-reviewer agent, pre-commit reminders | **Forge Studio wins.** Automated enforcement at write time. |
| **Edit safety** | Basic requirement: must read file before editing (enforced by Edit tool). | `track-edits` hook warns after 3 edits without re-reading. `check-large-file` warns on >500 line reads. | **Forge Studio wins.** Proactive drift detection beyond the basic read requirement. |
| **Trace collection** | Internal analytics (`logEvent`, `logForDiagnosticsNoPII`) — not user-visible | JSONL traces in `~/.claude/traces/` — grep-searchable, analyzable via skills | **Forge Studio wins.** User-visible execution diagnostics. |

---

## What Forge Studio Already Does Right

1. **Hooks over instructions** — The source confirms instructions degrade over long conversations. Hook-based behavioral anchoring is architecturally correct.

2. **Zero-cost skills** — All skills use `disable-model-invocation: true`. Claude Code's built-in output styles and features don't have this optimization — they're always active once enabled.

3. **Progressive context warnings** — Claude Code has automatic compression but zero user-visible warning. The 5-stage system gives users agency over their context budget.

4. **Capability-isolated agents** — The source's `AgentTool` restricts tools per agent type, but the restrictions are less explicit than Forge Studio's Planner (no write) / Generator (full write) / Reviewer (no write) triad.

5. **Edit tracking** — The source has no equivalent of the `track-edits` hook. Claude Code only enforces "must read before edit" — it doesn't track whether you've re-read after multiple edits.

6. **Destructive command blocking** — The source relies on permission modes and deny rules (configured per-user). Forge Studio's `block-destructive.sh` hook with `exit 2` is a harder, plugin-level block.

7. **Structured traces** — The source collects internal telemetry, but it's not user-facing. Forge Studio's JSONL traces enable retrospective analysis across sessions.

---

## What Claude Code Does That Forge Studio Should Address

### Addressed by Forge Studio

- **Output style safety** — Claude Code allows styles to suppress core instructions. Forge Studio inherits this risk without mitigation — addressed via `rules.d/60-output-style-safety.txt`.

- **Numeric length anchors** — Anthropic internally uses word-count targets (~1.2% token reduction). Replicated in `plugins/behavioral-core/hooks/rules.d/25-numeric-anchors.txt`.

- **Function result clearing awareness** — Claude Code silently evicts old tool results under context pressure. The `track-edits` hook warns after 3 edits without re-reading, mitigating silent context eviction.

### Open Gaps (not yet addressed)

1. **Tool count/schema budget** — Claude Code actively manages tool count via deferred loading. Forge Studio doesn't monitor total tool burden.

2. **Prompt cache awareness** — Claude Code has explicit cache boundary management. Forge Studio users don't know what actions bust their cache.

3. **System-reminder accumulation tracking** — Claude Code has within-message smooshing but no cross-message tracking. Neither does Forge Studio.

4. **MCP instruction impact** — Claude Code marks MCP instructions as explicitly dangerous for caching. Forge Studio doesn't warn about MCP overhead.

---

## Ant-Only Features Worth Replicating

### Anti-False-Claims Instruction (prompts.ts:237-241)

Gated by `USER_TYPE === 'ant'`. Added because false-claim rate jumped to 29-30% with Capybara v8 (vs 16.7% in v4). External users don't get this. The exact instruction:

> Report outcomes faithfully: if tests fail, say so with the relevant output; if you did not run a verification step, say that rather than implying it succeeded. Never claim "all tests pass" when output shows failures, never suppress or simplify failing checks (tests, lints, type errors) to manufacture a green result, and never characterize incomplete or broken work as done. Equally, when a check did pass or a task is complete, state it plainly — do not hedge confirmed results with unnecessary disclaimers, downgrade finished work to "partial," or re-verify things you already checked. The goal is an accurate report, not a defensive one.

**Replicated in:** `plugins/behavioral-core/hooks/rules.d/55-no-false-claims.txt`

### Numeric Length Anchors (prompts.ts:527-535)

Ant-only. ~1.2% output token reduction vs qualitative "be concise":

> Keep text between tool calls to ≤25 words. Keep final responses to ≤100 words unless the task requires more detail.

**Replicated in:** `plugins/behavioral-core/hooks/rules.d/25-numeric-anchors.txt`

---

## Token-Saving Settings

Environment variables and settings that reduce overhead:

| Setting | What it does | Token impact |
|---------|-------------|-------------|
| `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` | Disables fire-and-forget prompt suggestion after every turn | Saves background compute + potential context injection |
| `includeGitInstructions: false` | Removes ~2K tokens of git commit/PR workflow from Bash tool prompt | -2K tokens/session (if CLAUDE.md already covers git) |
| `promptSuggestionEnabled: false` | Disables prompt suggestion UI | Saves compute |
| `showClearContextOnPlanAccept: true` | Offers "clear context" when approving plans | Lets you start implementation with clean context |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | Disables built-in auto-memory extraction | Saves fire-and-forget background work (use marketplace memory plugin instead) |
| `ENABLE_TOOL_SEARCH=true` | Defers unused tool schemas | Saves ~500-2K tokens per deferred tool |

### Tool Search Details

`ENABLE_TOOL_SEARCH` has three modes:
- `true` — always defer MCP and `shouldDefer` tools
- `auto` (default) — defer when tool definitions exceed 10% of context window
- `auto:N` — defer when exceeding N% of context window (e.g., `auto:5` for 5%)
- `false` — no deferral, all tools loaded inline

### What `effortLevel` Does

Maps directly to `output_config.effort` in the API call:
- `low` — minimal reasoning compute
- `medium` — balanced
- `high` — more reasoning compute
- `max` — maximum reasoning (Opus 4.6 only for external users)

External users can only persist low/medium/high. `max` must be set per-session or via env var `CLAUDE_CODE_EFFORT_LEVEL=max`.
