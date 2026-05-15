# traces — local conventions

Read together with: ./README.md

## What this plugin owns

Execution-trace collection (Bash, Edit/Write, failures, user turns, session summaries) + the trace-mining skills (`trace-compile`, `trace-stats`, `trace-review`, `trace-clarification`, `trace-evolve`, `reasoning-tilt`). Output feeds `forge-meta:/evolve` and `evaluator:/assess-proposal`.

## Non-obvious invariants

- **One JSONL per session, per concern.** Bash traces, file traces, failure traces, and user-turn traces each go to their own `~/.claude/traces/<session_id>/<kind>.jsonl`. Don't merge in-flight — trace-compile assembles them at read time.
- **collect-*.sh hooks are silent on the happy path.** They never print to stderr/stdout; the only side effect is the trace file. Anything visible from these hooks is a regression.
- **Session summaries trigger on Stop, not SessionEnd.** `session-summary.sh` runs at every Stop event, but only writes when net-new traces accumulated. SessionEnd-only would lose data on crashes.
- **trace-clarification reads, never writes the trace.** Mining skills are read-only over the trace corpus; only the collectors write. Keeps the audit trail trustworthy.

## Files to read first when changing this plugin

1. `hooks/hooks.json` — the 6-script collector chain across 4 events (SessionStart, UserPromptSubmit, PostToolUse, Stop)
2. `hooks/collect-bash-trace.sh` — the canonical collector pattern; others mirror it
3. `skills/trace-compile/SKILL.md` — the assembler that downstream skills depend on; its output schema is the contract

## Cross-plugin dependencies

- `forge-meta:/evolve` — consumes `trace-evolve` proposals
- `evaluator:/prediction-audit` — reads the same trace corpus to score forecast accuracy
- `workflow:route-prompt.sh` — its `classifications.jsonl` is one of the trace sources
