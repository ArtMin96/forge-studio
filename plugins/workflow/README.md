# workflow

Hook-driven agentic orchestrator. Routes prompts to the right pattern, enforces sprint contracts, runs the TDD loop, and operates the self-evolution cycle over versioned harness resources.

## What it does

Three jobs, all hook-mediated:

1. **Routing** — every `UserPromptSubmit` is classified (single / pipeline / fan-out / TDD / auto) so multi-step work goes to the right pattern automatically.
2. **Lifecycle** — sprint-contract re-reads before generation, post-subagent handoff nudges, pre-compaction summaries.
3. **Self-evolution** — `propose → assess → commit → rollback` over versioned resources, with an append-only ledger and snapshot store.

Composes the `agents`, `evaluator`, `context-engine`, and `memory` plugins rather than duplicating their logic.

## When to use

You always want it on. Routing is the entry point — without it, the harness is reactive, not proactive.

## How it works

```text
 SessionStart       ──► session-bootstrap.sh   surface active plan, unchecked items, recent progress
 UserPromptSubmit   ──► route-prompt.sh        classify into single / pipeline / fan-out / TDD
                        (or route-prompt-llm.sh for hybrid/LLM mode)
 SubagentStop       ──► after-subagent.sh      append delta to spec.md, nudge handoff, mark features done
 PostToolUse        ──► plan-format-check.sh   validate .claude/plans/*.md format on every Edit/Write/MultiEdit
 Stop               ──► turn-gate.sh           surface unchecked plan items and context pressure every N turns
 PreCompact         ──► pre-compact-handoff.sh advisory nudge to run /progress-log before compaction
```

Self-evolution loop:

```text
 trace-evolve / router-tune / manual ──► proposal artifact
                                       ↓
                                  /evolve     orchestrates
                                       ↓
                              /assess-proposal (forked reviewer subagent)
                                       ↓
                                  user approval
                                       ↓
                              /commit-proposal  snapshot + write + ledger entry
```

Every step writes to `.claude/lineage/ledger.jsonl` (append-only). Snapshots live under `.claude/lineage/versions/<slug>/`.

## Hooks

| Hook | Event | When it fires | What it does |
|------|-------|---------------|-------------|
| session-bootstrap.sh | `SessionStart` | Every new session | Surfaces the active plan, unchecked plan items, and the last few lines of `claude-progress.txt` so the session opens with context |
| route-prompt.sh | `UserPromptSubmit` | Every user message | Shell-first classifier: maps prompt to single-agent / pipeline / fan-out / tdd-loop. Emits an advisory nudge only when confident (≥0.75). One-shot per unique (route, reason, prompt) within a session — use `FORGE_REMINDER_FORCE=1` to re-fire. Set `WORKFLOW_ROUTER_MODE=hybrid` or `llm` to escalate ambiguous prompts to an LLM classifier |
| after-subagent.sh | `SubagentStop` | After any subagent finishes | Nudges the next phase in planner→generator→reviewer→/verify. Appends a delta block to `.claude/spec.md`. Flips `features.json` entries to `done` when commit messages reference their `F<n>` id. Emits a `handoff_open` ledger entry with the current plan. Deduplicates per-phase nudges with a TTL (`FORGE_AFTER_SUBAGENT_TTL_SECS`, default 1800s) — `FORGE_REMINDER_FORCE=1` bypasses. Unknown `agent_type` values emit a warning to stderr (exit 1) |
| turn-gate.sh | `Stop` | Every N turns (default 3) | Checks for open handoffs past their age limit (`FORGE_HANDOFF_SKIP_SECS`, default 5400s), unchecked plan items in the most recent plan, context pressure above threshold (`WORKFLOW_HANDOFF_PCT`, default 75%), and recent unlogged commits. Set `WORKFLOW_TURN_GATE_INTERVAL` to change cadence |
| pre-compact-handoff.sh | `PreCompact` | Before context compaction | Advisory nudge to run `/progress-log` before the compaction discards tool outputs |
| plan-format-check.sh | `PostToolUse` (matcher `Edit\|Write\|MultiEdit`) | Immediately after any Edit/Write/MultiEdit on `.claude/plans/*.md` | Validates canonical plan format (`### Tasks` 3-hash + `#### T<n>` 4-hash). Warns on common drift (`## Tasks` 2-hash, `### T<n>` 3-hash, or Tasks heading without matching task headings) at write time so the orchestrator does not silently degrade to single-pass on a malformed plan. Advisory only (exit 1 warning) |

## Skills

| Skill | Slash command | What it does | When to use |
|-------|---------------|-------------|-------------|
| orchestrate | `/orchestrate [pattern]` | Manual entry into the agentic workflow — overrides automatic routing. `pipeline` iterates each `#### T<n>` task with its own generator→reviewer→/verify cycle | When you have a multi-task plan and want the full pipeline with contract checking |
| tdd-loop | `/tdd-loop <desc>` | Red→Green→Refactor with three real-command completion gates | When you want test-first discipline enforced mechanically, not by convention |
| status | `/status` | Snapshot: active plan, last progress entry, recent traces, context pressure, router stats | Quick orientation at the start of a session or after a context gap |
| evolve | `/evolve` | Self-evolution cycle: proposal → assess → user approval → commit | When proposing a harness change that needs adversarial review before applying |
| commit-proposal | `/commit-proposal` | Apply an assessed proposal. Refuses unless verdict is `pass` and user approved | After `/evolve` + `/assess-proposal` return pass |
| rollback | `/rollback` | Restore a snapshot; append rollback entry to ledger | When a committed proposal made things worse |
| router-tune | `/router-tune` | Analyze router miss-fires; emit a proposal tweaking thresholds or regex | When route-prompt.sh keeps routing the same prompt type incorrectly |
| living-spec | `/living-spec` | Initialize `.claude/spec.md` from a plan's `## Contract`; subagent deltas append automatically | At the start of a sprint that will run multiple subagents |
| reflect | `/reflect` | After a sprint, emit a three-line insight (worked / surprised / watch); routes to `/remember` if durable | After completing a meaningful unit of work |
| zoom-out | `/zoom-out` | One-screen map of relevant modules + callers + the layer above the current file | When you need structural context before editing |

## Helper scripts

`skills/orchestrate/scripts/parse-tasks.sh <plan-path>` — deterministic task extractor for `/orchestrate pipeline`. Reads the `### Tasks` section and emits `T1`, `T2`, ... one per line. Used to avoid in-context parse errors when the plan has many tasks.

`skills/orchestrate/scripts/find-active-plan.sh` — single source of truth for "which plan is active." All hooks and skills call this instead of doing their own `find … -printf '%T@'` mtime sort.

### Plan picker convention

Plans are picked in natural numeric-prefix order (`sort -V`): `s1-…` before `s2-…` before `s3-…`, regardless of file modification time. A plan is considered complete when all feature-gate entries in `.claude/gate/features.json` whose `id` starts with the plan's sprint prefix (e.g. `s3`) have `passed: true`; the first non-complete plan is returned. If all plans appear complete per the gate, the script falls back to mtime-newest and emits a stderr warning.

Override the picker entirely by setting `FORGE_ACTIVE_PLAN_OVERRIDE=<absolute-path>` — when set and the file exists, that path is returned unconditionally.

## Environment variables

| Variable | Default | Effect |
|----------|---------|--------|
| `FORGE_ACTIVE_PLAN_OVERRIDE` | _(unset)_ | Path to a plan file; when set and readable, the plan picker returns it unconditionally |
| `FORGE_HANDOFF_SKIP_SECS` | `5400` | Age (seconds) after which an open handoff is auto-closed as skipped |
| `FORGE_REMINDER_FORCE` | `0` | Set to `1` to re-fire suppressed nudges unconditionally |
| `FORGE_AFTER_SUBAGENT_TTL_SECS` | `1800` | Dedup TTL for after-subagent nudges |
| `WORKFLOW_ROUTER_MODE` | `shell` | Router mode: `shell` (deterministic), `hybrid` (escalate uncertain to LLM), `llm` (always LLM) |
| `WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` | `0.75` | Below this confidence, hybrid mode escalates to LLM |
| `WORKFLOW_ROUTER_DIRECTIVE_THRESHOLD` | `0.90` | At/above this confidence, the advisory nudge is upgraded to a directive block ("ROUTE SELECTED / EXECUTE / WHY") that prompts immediate action. `single-agent` routes are exempt to avoid noise on narrow fixes |
| `WORKFLOW_ROUTER_DIRECTIVE_MODE` | `on` | `off` reverts to advisory-only behavior bit-for-bit. Use as the override hatch when directive output is interfering |
| `WORKFLOW_TURN_GATE_INTERVAL` | `3` | How often (in turns) the turn-gate fires |
| `WORKFLOW_HANDOFF_PCT` | `75` | Context-use percentage at which turn-gate warns about compaction |

## Typical workflow

When you type `/orchestrate pipeline` with an active plan:

1. `parse-tasks.sh` extracts task IDs (`T1`, `T2`, ...) from the plan's `### Tasks` section.
2. For each task, a generator subagent runs. `after-subagent.sh` fires on `SubagentStop`, appends a spec delta, and nudges you to dispatch the reviewer.
3. After the reviewer, `after-subagent.sh` nudges `/verify`.
4. `turn-gate.sh` fires every 3 turns to flag unchecked items and context pressure.
5. Once all tasks pass, `pre-compact-handoff.sh` reminds you to log progress before compaction.

## Disable

`/plugin disable workflow@forge-studio`. Routing reverts to manual; the SEPL loop becomes unavailable. Other plugins keep working but lose their orchestrator.
