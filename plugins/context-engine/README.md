# context-engine

Context window management. Tracks pressure, detects drift, warns on edits that will balloon the context, and triggers safe-mode after repeated tool failures.

## What it does

Long sessions silently degrade as the context fills with stale tool output, partial reads, and forgotten subgoals. This plugin watches for the warning signs and surfaces them — large file reads, MCP overhead, plan-vs-current drift, compaction events — so you can act before performance falls off.

## When to use

- Sessions routinely cross 100K tokens
- You hit `/compact` reactively instead of proactively
- CLAUDE.md has grown past 100 lines and rule compliance has dropped
- A session that started clean now feels "off"

## How it works

```text
 SessionStart       ──► env bootstrap, MCP-instruction monitor
 UserPromptSubmit   ──► track context pressure, system-reminder weight, task-guardian
 PostToolUse (Read) ──► large-file warning + edit tracking
 PostToolUse (Bash) ──► tool-output truncation warning
 PostToolUse (Edit) ──► edit thrashing detector
 PostToolUseFailure ──► consecutive-failure counter (writes .claude/safe-mode at threshold)
 PreCompact         ──► pre-compaction guard + summary (saves what matters)
 PostCompact        ──► restore essentials, re-check budget
```

Six `PostToolUse` hooks cover the most common token sinks (large file reads, tool-output truncation, edit tracking, edit thrashing, plan-mode entry, consecutive-failure reset). Duplicate-read detection lives in the `token-efficiency` plugin.

## Skills

| Skill | Purpose |
|---|---|
| `/audit-context` | Measure CLAUDE.md size, system reminder weight, MCP cost, top per-skill description offenders |
| `/checkpoint` | Compare recent work against the original task — list scope creep + bloat |
| `/lean-claude-md` | Trim CLAUDE.md using the every-line-must-earn-its-place principle |
| `/token-pipeline` | 5-stage Token Transformation pass — emits a concrete next action (`/compact`, `/lean-claude-md`, fresh session) |
| `/context-tricks` | Reference card — guided compaction, partial compaction, side-question dispatch, checkpointing |

## Hooks

Seven events, sixteen scripts.

| Event | Matcher | Hook | Effect |
|---|---|---|---|
| `SessionStart` | `*` | env-bootstrap | Surface relevant env vars and project flags into the session |
| `SessionStart` | `*` | mcp-instruction-monitor | Measure MCP server overhead; warn on excess instructions |
| `UserPromptSubmit` | `*` | track-context-pressure | Sample token pressure each turn; flag thresholds |
| `UserPromptSubmit` | `*` | track-system-reminders | Track cumulative system-reminder weight |
| `UserPromptSubmit` | `*` | task-guardian | Re-anchor the active task; warn on drift |
| `TaskCreated` | `*` | task-guardian-log | Record new task to the task-guardian log |
| `PostToolUse` | `Read` | check-large-file | Flag oversized file reads |
| `PostToolUse` | `Bash\|Grep` | warn-tool-truncation | Flag commands whose output will likely truncate |
| `PostToolUse` | `Edit\|Read` | track-edits | Maintain the per-session edit history |
| `PostToolUse` | `Edit` | detect-thrashing | Detect repeated edits to the same file (fix-fix-fix loops) |
| `PostToolUse` | `EnterPlanMode` | plan-mode-enter | Plan-mode hygiene: enforce read-before-plan, surface context budget |
| `PostToolUse` | `*` | consecutive-failure-reset | Reset the failure counter on any successful tool call |
| `PostToolUseFailure` | `*` | consecutive-failure-guard | After N failures, write `.claude/safe-mode` (read by behavioral-core) |
| `PreCompact` | `*` | pre-compact-guard | Block compaction when essential context would be lost |
| `PreCompact` | `*` | pre-compact | Emit a structured summary before compaction runs |
| `PostCompact` | `*` | post-compact | Restore essentials and re-check the budget after compaction |

Duplicate-read detection lives in the `token-efficiency` plugin.

## Disable

`/plugin disable context-engine@forge-studio`. You'll lose the pressure-tracking and safe-mode trigger — pair with another guard if you do.
