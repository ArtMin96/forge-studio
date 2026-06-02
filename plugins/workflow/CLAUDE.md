# workflow — local conventions

Read together with: ./README.md and ./LIFECYCLE.md

## What this plugin owns

The agentic-workflow router (`route-prompt.sh`), sprint-contract enforcement (`after-subagent.sh`), TDD loop, session bootstrap, handoff nudges. Self-evolution SEPL loop (`/evolve` → `/assess-proposal` → `/commit-proposal` → `/rollback`).

## Non-obvious invariants

- **Hooks are advisory.** `route-prompt.sh` and `after-subagent.sh` print text suggestions; they never invoke skills. The model reads the suggestion and decides. No exit-2 / blocking from this plugin.
- **`find-active-plan.sh` is the single source of truth.** All hooks and skills resolve "the active plan" via `skills/orchestrate/scripts/find-active-plan.sh` — never re-implement an `ls -t .claude/plans/*.md | head -1` shortcut. mtime-newest is the wrong default for users who keep multiple incremental plans (e.g. `s1-foo.md`, `s2-foo.md`, `s3-foo.md`): editing a later plan would otherwise jump it ahead of an earlier, still-incomplete one.
- **Canonical plan filename format: `s<N>-<slug>.md`** (e.g. `s1-confirmed-bugs.md`, `s7-stability-and-docs-refresh.md`). The `s<N>` prefix is what `find-active-plan.sh:68` greps via `^s[0-9]+` to look up gate-completion state in `.claude/gate/features.json`. Any other prefix sorts correctly via `sort -V` but cannot be auto-skipped when its features pass — the script falls back to "treat as active." Use `FORGE_ACTIVE_PLAN_OVERRIDE=<path>` for one-off out-of-band plans.
- **Invocation contract.** Skills call `bash plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh` from repo root. This plugin's own hooks call it via `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/find-active-plan.sh` (same-plugin, direct). Cross-plugin hooks (agents, evaluator) call it via `${CLAUDE_PLUGIN_ROOT}/workflow-orchestrate/scripts/find-active-plan.sh` — a per-consumer symlink to `../workflow/skills/orchestrate`, because `${CLAUDE_PLUGIN_ROOT}/../<other-plugin>/...` is stripped from the plugin cache. Returns the absolute plan path on stdout or empty string + exit 0 when no plan exists — always check `[[ -z "$PLAN_PATH" ]]` before using.
- **Router env vars are layered.** `WORKFLOW_ROUTER_MODE` (shell/hybrid/llm) gates whether the LLM fallback fires. `WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` (0.75) gates the advisory output. Higher-confidence routes may upgrade to directive output via `WORKFLOW_ROUTER_DIRECTIVE_THRESHOLD` (0.90, env-gated by `WORKFLOW_ROUTER_DIRECTIVE_MODE`).
- **Per-session dedup at `route-prompt.sh:166-189`.** Same prompt → same route → same reason fires only once per session unless `FORGE_REMINDER_FORCE=1`. Both advisory and directive modes share the suppression.
- **Classifications JSONL is append-only.** Writes go through `plugins/_lib/jsonl-append.sh` to survive concurrent subagent classification.

## Files to read first when changing this plugin

1. `hooks/route-prompt.sh` — classifier + dedup + advisory/directive output
2. `hooks/after-subagent.sh` — phase-transition nudges + spec-delta append
3. `skills/orchestrate/SKILL.md` and `skills/orchestrate/scripts/parse-tasks.sh` — pipeline driver
4. `LIFECYCLE.md` — diagram of the event chain (the actual ground truth, not the README intro)

## Cross-plugin dependencies

- `agents:/dispatch`, `agents:/contract`, `agents:/fan-out` — the patterns the router recommends
- `evaluator:/verify` — invoked at the end of every orchestrate task
- `long-session:/progress-log` — what `pre-compact-handoff.sh` and `turn-gate.sh` nudge toward
