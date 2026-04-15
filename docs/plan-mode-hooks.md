# Plan Mode Hooks

How Claude Code handles plan mode internally, and how marketplace plugins can hook into it.

**Audience:** Plugin developers and advanced users. You don't need this to use Forge Studio — it's reference material for understanding or extending plan mode behavior. For the hooks system in general, see [Architecture: Why Hooks Beat Instructions](architecture.md#why-hooks-beat-instructions).

---

## How Plan Mode Works in Claude Code

Plan mode has **two entry paths** that work differently:

### 1. Model-initiated: `EnterPlanMode` tool

When the model decides to enter plan mode, it calls the `EnterPlanMode` tool — a real SDK tool registered in the tool system (`src/tools/EnterPlanModeTool/EnterPlanModeTool.ts`).

```
Model calls EnterPlanMode → PreToolUse hooks fire → tool executes → PostToolUse hooks fire
```

The tool:
- Calls `handlePlanModeTransition(currentMode, 'plan')` to set internal state flags
- Calls `prepareContextForPlanMode()` to stash the previous permission mode as `prePlanMode`
- Applies permission update to set mode to `'plan'`
- Injects plan mode instructions (Phase 1-5 workflow) as system-reminders

**Hooks fire** because it goes through the standard tool execution pipeline.

### 2. User-initiated: `/plan` slash command

When the user types `/plan`, it's handled as a `local-jsx` command (`src/commands/plan/plan.tsx`). This is client-side UI code that directly mutates `appState.toolPermissionContext.mode` without going through the tool system.

```
User types /plan → client-side mode switch → plan mode instructions injected
```

**No hooks fire.** Local-jsx commands bypass the tool execution pipeline entirely. This is a Claude Code architectural constraint — no plugin can hook `/plan`.

### What both paths share

Both paths:
- Call `handlePlanModeTransition()` in `src/bootstrap/state.ts`
- Inject the same plan mode system-reminders (Phase 1-5 workflow)
- Store `prePlanMode` to restore when exiting

The same pattern applies to `ExitPlanMode` (tool) vs exiting via client UI.

---

## The Hook Mechanism

The `matcher` field in `hooks.json` uses regex to match tool names:

```json
{
  "matcher": "EnterPlanMode",
  "hooks": [
    {
      "type": "command",
      "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/plan-mode-enter.sh",
      "timeout": 5
    }
  ]
}
```

This is the same mechanism used by existing hooks:

| Matcher | Fires for |
|---------|-----------|
| `"Bash"` | Bash tool only |
| `"Write\|Edit"` | Write or Edit |
| `"EnterPlanMode"` | Plan mode entry (model-initiated only) |

Hook scripts receive JSON on stdin with `tool_name`, `tool_input`, and (for PostToolUse) `tool_response`. The hook's stdout is injected as a `<system-reminder>`.

---

## What the Plugin Does

**File:** `plugins/context-engine/hooks/plan-mode-enter.sh`

A `PostToolUse` hook matching `EnterPlanMode` that:

1. Scans `$HOME/.claude/plugins/cache/` for installed plugin skills
2. Filters to skills whose description contains "plan mode" or whose name is "plan"
3. Outputs a brief advisory listing those skills

The model sees this as a system-reminder and can invoke whichever skill fits. Currently matches:

- `/plan` — structured planning workflow (Problem → Approach → Changes → Risks → Verification)
- `/grill-me` — interrogates the user about every aspect of their plan/design

New skills automatically appear if their description mentions "plan mode".

### Why list skills instead of loading them?

Loading full skill content adds ~600 tokens. A brief advisory (~50 tokens) pointing the model to the Skill tool is cheaper and lets the model choose based on context.

---

## Limitations

| Scenario | Hooked? | Why |
|----------|---------|-----|
| Model calls `EnterPlanMode` | Yes | Real SDK tool, full pipeline |
| User types `/plan` | **No** | Client-side `local-jsx`, bypasses tools |
| Model calls `ExitPlanMode` | Could be | Same mechanism, add `"matcher": "ExitPlanMode"` |
| User exits plan via UI | **No** | Client-side state change |

The `/plan` gap cannot be fixed by any plugin. It would require a Claude Code source change — either making `/plan` go through the tool system, or adding a dedicated `PlanModeEnter` hook event type.

---

## Adding New Plan Mode Skills

To make a skill appear in the plan mode advisory, add "plan mode" to its description in the YAML frontmatter:

```yaml
---
name: my-skill
description: Use when the user is in plan mode and wants to...
---
```

The hook filters on `grep -qi "plan mode"` in the description field, or matches skills named exactly "plan".
