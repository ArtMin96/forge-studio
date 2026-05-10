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
 SessionStart       ──► session-bootstrap.sh   warm caches, surface plan if present
 UserPromptSubmit   ──► route-prompt.sh        classify into single / pipeline / fan-out / TDD
                       (or route-prompt-llm.sh hybrid mode for ambiguous prompts)
 SubagentStop       ──► after-subagent.sh     append delta to spec.md, nudge handoff
 Stop               ──► turn-gate.sh           verify task gates before allowing the turn to end
 PreCompact         ──► pre-compact-handoff.sh save the active plan + features.json
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

## Skills

| Skill | Purpose |
|---|---|
| `/orchestrate` | Manual entry into the agentic workflow — overrides automatic routing. On `pipeline`, iterates per-task: one generator → reviewer → /verify cycle per `#### T<n>` heading; stops on first failure |
| `/status` | Active plan, last progress entry, recent traces, context pressure — one snapshot |
| `/tdd-loop` | Red → Green → Refactor with three real-command completion gates |
| `/evolve` | Run a self-evolution cycle: proposal → assess → user approval → commit |
| `/commit-proposal` | Apply an assessed proposal. Refuses unless verdict is `pass` and the user approved |
| `/rollback` | Restore a snapshot; log a rollback entry. History stays append-only |
| `/router-tune` | Analyze router miss-fires; emit a proposal tweaking thresholds or regex |
| `/living-spec` | Initialize `.claude/spec.md` from a plan's `## Contract`; subagent deltas append automatically |
| `/reflect` | After a sprint, emit a three-line insight (worked / surprised / watch); route to `/remember` if durable |
| `/zoom-out` | One-screen map of relevant modules + callers + the layer above the current file |

## Hooks

Five events covered. See `LIFECYCLE.md` in this plugin for the full per-event spec.

## Disable

`/plugin disable workflow@forge-studio`. Routing reverts to manual; the SEPL loop becomes unavailable. Other plugins keep working but lose their orchestrator.
