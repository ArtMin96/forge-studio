# Workflow Lifecycle

The daily development workflow as a connected cycle:

```
/morning ─── Review yesterday, plan today
    │
    ▼
/route ──── Analyze task, pick complexity pattern
    │
    ├── Simple Fix ──────────── Just do it
    ├── Prompt Chaining ─────── Sequential steps
    ├── Routing ─────────────── Branch by type
    ├── Orchestrator-Workers ── Parallel subagents
    └── Evaluator-Optimizer ─── Challenge + refine
    │
    ▼
/explore ── Subagent exploration, map the territory
    │
    ▼
/plan ───── Design approach, get approval
    │
    ▼
/implement ─ Execute the plan, verify each step
    │
    ▼
/verify ─── Challenge the work (evaluator plugin)
    │
    ▼
/eod ────── Summarize day, note blockers
    │
    ▼
/weekly ─── Retrospective, patterns, improvements
```

## Skill Reference

| Skill | Plugin | Purpose |
|-------|--------|---------|
| `/morning` | workflow | Review previous session, set today's goals, check blockers |
| `/route` | workflow | Analyze task complexity, recommend agent pattern |
| `/explore` | workflow | Launch subagents for codebase exploration |
| `/plan` | workflow | Design implementation approach, output plan for approval |
| `/implement` | workflow | Execute approved plan with verification at each step |
| `/verify` | evaluator | Challenge completed work via adversarial review |
| `/eod` | workflow | End-of-day summary: what was done, what's blocked, what's next |
| `/weekly` | workflow | Weekly retrospective: patterns, improvements, lessons |

## When to Use What

- **Starting the day:** `/morning` → sets context, reviews state
- **New task arrives:** `/route` → determines complexity level
- **Unfamiliar code:** `/explore` → safe read-only exploration before planning
- **Non-trivial feature:** `/plan` → get alignment before implementation
- **Executing plan:** `/implement` → structured execution with verification
- **After implementation:** `/verify` or `/challenge` → find problems before the user does
- **Wrapping up:** `/eod` → capture state for tomorrow's `/morning`
- **End of week:** `/weekly` → step back, see patterns, improve process
