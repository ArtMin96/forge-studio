# Workflow Lifecycle

The development cycle as an **event-driven pipeline**. Hooks fire automatically; skills are manual escape hatches. This replaces the previous manual ritual (`/morning`, `/eod`, `/weekly`, `/route`, `/plan`, `/implement`, `/explore`) with composition of existing plugins.

## How It Runs

```
SessionStart ─► session-bootstrap.sh
                 ├─ surface latest handoff (context-engine)
                 └─ list unchecked items in active plan

UserPromptSubmit ─► route-prompt.sh (shell classifier)
                     ├─ tdd intent      → nudge /tdd-loop
                     ├─ feature build   → nudge /dispatch → planner→generator→reviewer
                     ├─ batch same-op   → nudge /fan-out
                     ├─ narrow change   → nudge execute-directly
                     └─ low confidence  → optional LLM fallback (route-prompt-llm.sh)

SubagentStop ─► after-subagent.sh
                 ├─ planner done    → generator next (contract must be written)
                 ├─ generator done  → reviewer next (self-review is unreliable)
                 └─ reviewer done   → run /verify before claiming done

Stop ─► turn-gate.sh (every 3 turns)
         ├─ unchecked plan items   → reconcile before done
         └─ context pressure ≥75%  → /handoff nudge

PreCompact ─► pre-compact-handoff.sh
               └─ auto-compact imminent → /handoff nudge (advisory; does NOT block)
```

## Hook ↔ Composed Plugin Map

| Event | Hook (this plugin) | Composed plugins | Result |
|---|---|---|---|
| Session starts | `session-bootstrap.sh` | `context-engine:/resume`, plan file globs | Prior handoff surfaced; active plan shown |
| Prompt submitted | `route-prompt.sh` | `agents:/dispatch`, `agents:/fan-out`, this plugin's `/tdd-loop` | Pattern auto-selected |
| Subagent finishes | `after-subagent.sh` | `agents:/contract`, `evaluator:/verify` | Sprint-contract protocol enforced |
| Turn ends | `turn-gate.sh` | `context-engine:/handoff` (nudge) | Plan + budget reconciled |
| Auto-compact pending | `pre-compact-handoff.sh` | `context-engine:/handoff` | State persisted before potential loss |

## Skills Retained (Manual Entry Points)

| Skill | Plugin | Purpose |
|---|---|---|
| `/orchestrate` | workflow | Manually choose a pattern (single / pipeline / fan-out / tdd / auto) |
| `/tdd-loop` | workflow | RED → GREEN → REFACTOR with real-command gates (+ optional Phase 4 Reflect) |
| `/status` | workflow | On-demand snapshot: plan, handoff, traces, pressure, router stats |
| `/zoom-out` | workflow | "Give me the map" — higher-level perspective on unfamiliar code |
| `/evolve` | workflow | SEPL orchestrator: propose → assess → commit self-improvement cycle |
| `/commit-proposal` | workflow | Apply an approved proposal; snapshot prior version; ledger entry |
| `/rollback` | workflow | Reverse a commit; restore prior snapshot; ledger entry |
| `/reflect` | workflow | Reflect-Memorize: three-line sprint insight → memory topic |
| `/router-tune` | workflow | Analyze router miss-fires, emit threshold/regex proposals |

## Self-Evolution Loop (SEPL)

Closed-loop operator from *Autogenesis: A Self-Evolving Agent Protocol* (arXiv:2604.15034). See `docs/lineage.md` for the full protocol.

```
signal source ──► /trace-evolve (traces)         propose draft
                  or /router-tune (workflow)     ─────────┐
                                                          ▼
                  /evolve (workflow) ──► writes propose ledger entry
                                                          │
                                                          ▼
                  /assess-proposal (evaluator, forked reviewer)
                  ├─ pass → user approval prompt
                  ├─ fail → report, loop continues
                  └─ writes assess ledger entry
                                                          │
                                                          ▼
                  on approval: /commit-proposal
                  ├─ snapshot prior version to .claude/lineage/versions/
                  ├─ apply change
                  └─ writes commit ledger entry
                                                          │
                                              (reversible any time)
                                                          ▼
                                                      /rollback
```

Ledger: `.claude/lineage/ledger.jsonl` (append-only). Snapshots: `.claude/lineage/versions/<slug>/<version>`. Proposals: `.claude/lineage/proposals/`. Verdicts: `.claude/lineage/verdicts/`.

## Composed Skills (Live Elsewhere, Invoked by This Plugin)

| Skill | Plugin | When the workflow leans on it |
|---|---|---|
| `/dispatch` | agents | Pattern routing when the router says `pipeline` |
| `/contract` | agents | Re-read plan's `## Contract` before implementing |
| `/fan-out` | agents | Parallel batch (3–5 workers per Anthropic guidance) |
| `/verify` | evaluator | Evidence-based completion check |
| `/challenge` | evaluator | Draft verification critique |
| `/healthcheck` | evaluator | Auto-detect test/lint pipeline |
| `/handoff` | context-engine | Durable state capture |
| `/resume` | context-engine | Load latest handoff |
| `/remember` | memory | Persist decisions across sessions |

## Configuration

Set in `~/.claude/settings.json` or project `.claude/settings.json` under the `env` key:

| Variable | Default | Purpose |
|---|---|---|
| `WORKFLOW_ROUTER_MODE` | `shell` | `shell` / `hybrid` / `llm`. Controls the UserPromptSubmit classifier. |
| `WORKFLOW_ROUTER_LLM_MODEL` | `claude-haiku-4-5-20251001` | Model used by the LLM fallback when escalated. |
| `WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` | `0.75` | In `hybrid` mode, escalate to LLM when shell confidence falls below this. |
| `WORKFLOW_TURN_GATE_INTERVAL` | `3` | Turn-gate fires every N turns (reduces nag cadence). |
| `WORKFLOW_HANDOFF_PCT` | `75` | Context-pressure threshold triggering `/handoff` nudge. |
| `WORKFLOW_TDD_REFLECT` | `0` | When `1`, `/tdd-loop` runs a Phase 4 Reflect step after REFACTOR succeeds. |
| `WORKFLOW_EVOLVE_AUTOCOMMIT` | `0` | When `1`, `/commit-proposal` skips the approval prompt for `env/<VAR>` numeric deltas within ±20%. Off by default — enable only after the ledger is battle-tested. |

Router traces are written to `/tmp/claude-router-<session_id>/classifications.jsonl` — useful for auditing classification quality and tuning the shell ruleset.

## Migration From Manual Ritual

| Old skill | Replacement |
|---|---|
| `/morning` | `SessionStart` hook + `context-engine:/resume` |
| `/route` | `UserPromptSubmit` classifier + `agents:/dispatch` |
| `/explore` | Built-in `Explore` subagent (invoke via Task tool or `/orchestrate`) |
| `/plan` | `agents:planner` subagent + `.claude/plans/` file |
| `/implement` | `agents:generator` subagent + `agents:/contract` re-read |
| `/eod` | `Stop` hook + `context-engine:/handoff` when pressure is high |
| `/weekly` | Trigger via the harness `schedule` skill (reference plugin) with a cron expression, or run `/trace-evolve` from the traces plugin on demand |

Nothing is silently dropped — everything the old skills did is now either automated or covered by a more specialized plugin.

## Design Rationale

- **Hooks enforce, skills guide** (see `docs/architecture.md`). Mandatory steps go in hooks so model attention drift can't skip them.
- **Compose, don't duplicate**. Rebuilding `/verify`, `/handoff`, or the planner/generator/reviewer triad here would violate the single-source principle the other plugins already own.
- **File-based contracts survive compaction**. The plan's `## Contract` section is the durable steering signal — corroborated by *How to Train Your Advisor* (arXiv 2510.02453): small, file-backed advice docs transfer gains across model sizes.
- **Shell classifier first**. Zero token cost on the 95% of prompts where simple regex suffices. The LLM fallback exists for ambiguous cases and is opt-in via `WORKFLOW_ROUTER_MODE`.
- **Advisory over blocking**. None of these hooks exit 2 (no blocking). Blocking is owned by `behavioral-core` (destructive commands) and `research-gate` (read-before-edit); this plugin is orchestration, not enforcement.
