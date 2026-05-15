# Agentic Workflow

The `workflow` plugin instruments a development session with hook-driven advisories. Every prompt is classified into a recommended pattern (single-agent / pipeline / fan-out / tdd-loop), each subagent transition prints a next-step nudge, and context-pressure thresholds trigger handoff reminders. The hooks **only emit text suggestions** — they do not invoke skills or dispatch subagents on their own. To actually run a pattern, the user (or the model on the user's behalf) types `/orchestrate <pattern>`, `/tdd-loop`, etc. Read the suggestion, decide, then invoke.

---

## Install

```bash
/plugin install workflow@forge-studio
```

Recommended companion plugins (the workflow leans on their skills):

```bash
/plugin install agents@forge-studio           # planner / generator / reviewer + /dispatch /fan-out /contract
/plugin install evaluator@forge-studio        # /verify /challenge /healthcheck
/plugin install context-engine@forge-studio   # /checkpoint /audit-context /token-pipeline
/plugin install long-session@forge-studio     # /progress-log /session-resume /init-sh /feature-list
/plugin install memory@forge-studio           # /remember /recall
```

Restart the session once. The hooks arm themselves on the next `SessionStart`.

---

## Quick Start — the 5-step workflow for a new big task

When you start a non-trivial task, type these in order. Each hands a durable artifact to the next so context loss between steps doesn't matter.

| # | Command | What it leaves on disk | Purpose |
|---|---|---|---|
| 1 | `/plan <description>` *(agents plugin)* | `.claude/plans/<slug>.md` with `## Contract` and `#### T1`/`T2`/... | Negotiate scope and success criteria before any code is written |
| 2 | `/living-spec` | `.claude/spec.md` initialized from the contract | Subagents share the same source of truth; `after-subagent.sh` appends deltas as each phase finishes |
| 3 | `/orchestrate pipeline` | per-task generator → reviewer → `/verify` cycles | Iterates each `T<n>` task with its own subagent context — no leakage between tasks |
| 4 | `/reflect` *(green)* OR `/postmortem` *(red)* | `.claude/memory/topics/<topic>.md` (reflect) or root-cause writeup (postmortem) | Capture what worked or why it failed; the lesson outlives the session |
| 5 | `/progress-log` | append to `claude-progress.txt` | Run before `/clear` or compact so the next session has continuity |

Step 1 is the only one you should always type explicitly. Steps 2-5 frequently surface as router or after-subagent suggestions; you can either follow the nudge or invoke them yourself.

### Split-plan workflow (multi-sprint feature)

If your task is big enough to fan out across sprints, you do **not** keep one giant plan file. The active-plan resolver (`plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh`) supports a numbered split:

```
.claude/plans/
├── s1-<slug>.md      # sprint 1
├── s2-<slug>.md      # sprint 2
└── s3-<slug>.md      # sprint 3
```

How auto-advance works (verbatim from `find-active-plan.sh:1-22`):

1. Files are enumerated in **natural numeric order** (`sort -V`), so `s2-foo.md` comes before `s10-bar.md`.
2. For each plan, the resolver consults `.claude/gate/features.json`. If **every** gate entry whose `id` starts with the plan's sprint prefix (e.g. `s2`) shows `"passed": true`, the plan is treated as complete and skipped.
3. The first non-complete plan is returned to `/orchestrate`.
4. If every plan looks complete, the resolver falls back to mtime-newest and emits a stderr warning.

So the cycle for a split feature is:

1. Write `s1-<slug>.md`, `s2-<slug>.md`, `s3-<slug>.md` up-front (or write one and add the next when the previous lands).
2. Run the 5-step workflow above against `s1`. The `/verify` step at the end of step 3 populates `.claude/gate/features.json` with `passed: true` entries tagged by sprint.
3. Re-run `/orchestrate pipeline`. The resolver auto-advances to `s2`.
4. Repeat until every sprint is done.

**Manual override**: pin a specific plan with `FORGE_ACTIVE_PLAN_OVERRIDE=.claude/plans/s3-<slug>.md /orchestrate pipeline`. Use this when you want to jump out of order — for a hotfix sprint you inserted, or when re-running a completed sprint.

**Gotchas:**

- Sprints without a numeric prefix (e.g. `feature-xyz.md`) sort lexically alongside `s<N>-` files; if you mix them, expect surprises in resolver order. Either prefix everything `s<N>-` or commit fully to non-prefixed names.
- The completion check matches by sprint prefix (`s5`), so a gate entry named `s5-T1-checkout` counts; one named `feat-checkout` does not. If your `/verify` outputs don't carry the prefix, the resolver will keep returning the same plan forever.
- The fallback to mtime-newest is a safety net, not a feature — if you see the stderr warning, it usually means the gate file is missing or outdated.

---

## How a session flows

The diagram below is the **logical flow**, not the wire-up. The `Route prompt` step is the only automatic hop — `route-prompt.sh` runs on every UserPromptSubmit and prints a recommended pattern. Every box downstream of `Route prompt` is invoked by the user typing the corresponding command (`/orchestrate single`, `/orchestrate pipeline`, `/orchestrate fan-out`, `/tdd-loop`, `/verify`, `/progress-log`).

```mermaid
flowchart LR
  A[SessionStart] --> B[Route prompt &#40;auto&#41;]
  B -->|narrow fix| C[/orchestrate single/]
  B -->|feature build| D[/orchestrate pipeline/]
  B -->|batch same-op| E[/orchestrate fan-out/]
  B -->|test-first| F[/tdd-loop/]
  C --> G[/verify/]
  D --> G
  E --> G
  F --> G
  G --> H{Context tight?}
  H -->|yes| I[/progress-log/]
  H -->|no| B
```

Five hook events drive the pipeline:

| Event | What the hook does |
|---|---|
| `SessionStart` | Surfaces the latest handoff and any unchecked items in the active plan. |
| `UserPromptSubmit` | Classifies the prompt (shell regex, optional Haiku fallback) and suggests the right pattern. |
| `SubagentStop` | Points the conversation at the next phase (planner → generator → reviewer → `/verify`). |
| `Stop` | Every N turns, reminds about unchecked plan items and context pressure. |
| `PreCompact` | Advises `/progress-log` before auto-compaction. |

Every hook is advisory. Nothing blocks. The model stays in charge.

---

## Configuration

All settings live under `env` in `~/.claude/settings.json` or the project's `.claude/settings.json`:

```json
{
  "env": {
    "WORKFLOW_ROUTER_MODE": "shell",
    "WORKFLOW_ROUTER_LLM_MODEL": "claude-haiku-4-5-20251001",
    "WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD": "0.75",
    "WORKFLOW_TURN_GATE_INTERVAL": "3",
    "WORKFLOW_HANDOFF_PCT": "75"
  }
}
```

| Variable | Default | Purpose |
|---|---|---|
| `WORKFLOW_ROUTER_MODE` | `shell` | `shell` (regex only, zero tokens), `hybrid` (shell first, Haiku when uncertain), `llm` (always Haiku). |
| `WORKFLOW_ROUTER_LLM_MODEL` | `claude-haiku-4-5-20251001` | Model the LLM fallback uses. |
| `WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` | `0.75` | In `hybrid`, shell results under this threshold escalate to the LLM. |
| `WORKFLOW_TURN_GATE_INTERVAL` | `3` | Stop-hook fires every N turns. Higher = quieter. |
| `WORKFLOW_HANDOFF_PCT` | `75` | Context pressure % that triggers the handoff nudge. |

The router also logs every classification to `/tmp/claude-router-<session_id>/classifications.jsonl` — useful for auditing accuracy and tuning.

### Token overhead per event

What to expect the plugin to cost, per event:

| Event | Tokens added | Notes |
|---|---|---|
| `SessionStart` | ~80–150 one-time | Handoff summary + unchecked plan item count. |
| `UserPromptSubmit` (shell mode) | 0 | Advisory emitted only when routing confidence is high. |
| `UserPromptSubmit` (hybrid escalation) | ~150 on escalation | Haiku classifier fires only when shell is uncertain. |
| `SubagentStop` | 0–40 | Phase-transition nudge. Silent when no plan is active. |
| `Stop` | 0–100 every N turns | Plan-item + pressure reminders. Silent on clean state. |
| `PreCompact` | 0–80 | Advisory on auto-compact only. Manual `/compact` is silent. |

Rate-limiting (`WORKFLOW_TURN_GATE_INTERVAL`) and silent-on-success hook behavior keep steady-state overhead near zero for short tasks.

---

## Skills

Four user-invocable skills. All start with `/`.

| Skill | Argument | What it does |
|---|---|---|
| `/orchestrate` | `[single\|pipeline\|fan-out\|tdd\|auto]` | Manually dispatches the active plan through the chosen pattern. Defaults to `auto`. |
| `/tdd-loop` | `<feature-or-bug-description>` | Runs RED → GREEN → REFACTOR with real-command completion gates. Each phase runs in an isolated subagent context. |
| `/status` | — | Compact situation report: active plan, last handoff, recent traces, context pressure, router stats. |
| `/zoom-out` | — | Asks for a higher-level map of an unfamiliar area of the codebase. |

---

## Examples

### 1. Narrow fix — the router stays out of the way

```text
> fix the typo "recieve" in UserProfile.vue
```

The shell classifier sees a narrow verb + short prompt → routes `single-agent`. The hook emits one line:

```text
[workflow router] route=single-agent confidence=0.85 reason=narrow change, single-file verb
Narrow change detected. Execute directly; skip the planner→generator→reviewer pipeline.
```

Claude edits the file, runs the project's test command, done. No planner, no reviewer, no extra tokens.

### 2. Feature build — full pipeline with a sprint contract

```text
> implement a subscription upgrade flow across the billing and notifications modules
```

Router classifies `pipeline`. Behavior you'll see:

1. The **planner** (read-only subagent) explores `app/Billing/` and `app/Notifications/`, writes `.claude/plans/subscription-upgrade.md` containing a `## Contract` section with testable criteria:

   ```md
   ## Contract
   - [ ] POST /billing/subscription/upgrade returns 200 with new plan_id
   - [ ] NotificationDispatcher emits subscription.upgraded event
   - [ ] Feature flag `BILLING_UPGRADE_V2` gates the new path
   Verification method: ./vendor/bin/pest --filter=SubscriptionUpgrade
   ```

2. `SubagentStop` fires → the workflow hook emits:
   ```
   [workflow] Planner finished. Next: dispatch the generator. Ensure the plan has a ## Contract section before generating.
   ```

3. `/orchestrate pipeline` reads the plan and iterates over its tasks (`#### T<n>` headings under `### Tasks`) in order. For each task:
   a. `/contract` re-reads the plan from disk (survives any context compaction).
   b. The **generator** (read-write subagent) implements **only the current task's scope** — its Files / Success criteria block. Per-task scoping keeps each subagent's tool-call surface small enough to stay under Anthropic's `maxTurns` / `task_budget` budget; multi-task sprints will not truncate mid-stream.
   c. The **reviewer** (read-only subagent) checks contract compliance for this task. It has no Write/Edit tools, so it must flag issues instead of "fixing" them (keeps evaluation honest).
   d. `/verify` confirms evidence-backed completion against this task's criteria.
   e. Optional commit before advancing to the next task.

4. On any task failure (verify exit ≠ 0, reviewer rejects, or generator produces less than the declared artifacts) the loop stops. The user fixes and resumes; subsequent tasks are not auto-attempted.

5. If `$CLAUDE_CONTEXT_WINDOW_USED_PCT ≥ 75`, the `Stop` hook suggests `/progress-log` so the decisions persist into the next session.

### 3. Fan-out — parallel batch

```text
> rename the Logger import across all components in every module of src
```

Router classifies `fan-out` (batch verb + "across all" + target nouns). Suggested:

```text
Parallel-safe batch detected. Consider /fan-out (agents plugin) with 3–5 workers per batch.
```

Run `/fan-out` from the agents plugin. It dispatches 3–5 subagents (the Anthropic sweet spot for review-able parallelism), each operating on a disjoint file list. When all return, the orchestrator merges and you run `/verify` once.

### 4. TDD loop — three phases, three real-command gates

```text
> /tdd-loop reproduce the bug where UserProfile.logout() leaves stale tokens
```

Phase output you will see:

```text
RED phase
  Writes tests/Feature/LogoutLeaksTokenTest.php asserting empty token cache after logout()
  Runs: ./vendor/bin/pest tests/Feature/LogoutLeaksTokenTest.php
  Gate passes: exit code non-zero, message matches "expected cache to be empty"

GREEN phase (fresh context)
  Edits UserProfile.php: adds TokenCache::forget($userId) to logout()
  Runs: ./vendor/bin/pest tests/Feature/LogoutLeaksTokenTest.php
  Gate passes: exit 0

REFACTOR phase (reviewer agent, read-only)
  Checklist: dup logic, naming, unnecessary conditionals
  Result: "No refactoring needed — single-line fix, matches existing TokenCache call sites"
  Runs full suite: ./vendor/bin/pest
  Gate passes: exit 0
```

If any gate fails, the phase stops and reports the real output. No "I think it passes" claims.

### 5. End-of-session handoff

Near the end of a long session, `Stop` fires after a turn and the hook emits:

```text
[workflow] Plan subscription-upgrade.md has 2 unchecked items. Update the plan or reconcile before claiming done.
[workflow] Context at 78%. Run /progress-log (context-engine) before compaction risks information loss.
```

You run `/progress-log billing-upgrade`. A `.claude/progress-logs/2026-04-20-billing-upgrade.md` is written with done / in-progress / blockers / decisions / next-steps. Next session, `SessionStart` surfaces it:

```text
[workflow] Last handoff: 2026-04-20-billing-upgrade.md (0d ago). Run /session-resume to load it.
[workflow] Active plan: subscription-upgrade.md (2 unchecked items).
```

`/session-resume` picks up where you left off.

### 6. Asking for an override

Sometimes the router picks wrong. Force the pattern explicitly:

```text
> /orchestrate tdd
```

The skill reads the active plan, ignores the router's classification, and hands off to `/tdd-loop`. Advisory hooks never block you from overriding.

---

## Checking live state

```text
> /status
```

Typical output:

```text
Plan:     subscription-upgrade.md (0d old, 5/7 done)
Handoff:  2026-04-20-billing-upgrade.md (0d ago) — /session-resume to load
Traces:   31 events, last: Bash pest --filter=SubscriptionUpgrade
Pressure: 62% (Moderate) — consider /compact
Router:   pipeline:3 single-agent:2 tdd-loop:1
```

Silent sections are omitted — no "None" spam.

---

## Gotchas and failure modes

| Situation | What happens | How to recover |
|---|---|---|
| Shell classifier can't decide | Router stays silent. No nudge, no cost. | Invoke `/orchestrate <pattern>` to force a dispatch. |
| `claude` CLI missing in hybrid mode | `route-prompt-llm.sh` returns empty; shell verdict is used. | Install the CLI or set `WORKFLOW_ROUTER_MODE=shell`. |
| Plan has no `## Contract` section | Subagent-transition nudges still fire, but carry less information. | Add the section. Contract-backed runs survive compaction; loose plans do not. |
| Subagent crashes mid-pipeline | State is on disk (`.claude/plans/*.md`). Nothing is lost. | Next turn, re-dispatch from the plan — don't restart. |
| `turn-gate.sh` warns every 3 turns and it's noisy | Bump `WORKFLOW_TURN_GATE_INTERVAL` to `5` or `10`. | Setting takes effect next session. |
| Auto-compaction imminent, handoff not yet written | `pre-compact-handoff.sh` emits an advisory. | Run `/progress-log` before the compaction fires. The hook does not block compaction. |

Hooks are advisory — none exit with code 2. They surface signals; the decision stays with you and Claude.

---

## See also

- [Architecture](architecture.md) — 7-component harness model + hook mechanics
- [Harness Spec](../HARNESS_SPEC.md) — Sprint Contract Protocol (§ Sprint Contract Protocol)
- [Settings](settings.md) — full env-var reference including the `WORKFLOW_*` variables
- [Lifecycle](../plugins/workflow/LIFECYCLE.md) — event → hook → composed-plugin map
