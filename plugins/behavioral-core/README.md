# behavioral-core

Behavioral steering through hooks. Sixteen principle-based rules injected into every turn, plus mechanical guards against destructive commands and out-of-scope edits.

## What it does

Personality and discipline are usually negotiated in the system prompt and forgotten by turn 20. This plugin keeps them load-bearing: rules are re-emitted via `UserPromptSubmit` on every turn, destructive commands are blocked at `PreToolUse`, and a self-review nudge fires after long stretches without verification.

## When to use

You always want it on. The rules sit at the bottom of every prompt and cost ~150 tokens. Disable individually if a specific rule conflicts with project policy — drop the matching file from `rules.d/`.

## How it works

```text
 UserPromptSubmit
       │
       ▼
 behavioral-anchor.sh ──► reads rules.d/*.txt ──► injects into context
                          │
                          ▼
                     scope-guard.sh   blocks Edit/Write outside .claude/scopes/<task>.md allowlist
                     block-destructive.sh   denies rm -rf /, force-push, db drops, etc.
                     output-style-check.sh  warns on banned phrasings
                     self-review-nudge.sh   nudges verification after N edits without test
```

Rules live in `rules.d/`. Each is a plain text file. Edit, add, or remove — the hook reads the directory each turn.

## Skills

| Skill | Purpose |
|---|---|
| `/scope` | Write `.claude/scopes/<task>.md` with allowlist + budget. `scope-guard.sh` reads it on every edit |
| `/timebox` | Hard message ceiling for a task. Brevity rule reads remaining count each turn |
| `/safe-mode` | Toggle the safe-mode flag. Once set, every Bash/Write/Edit is denied until cleared |
| `/rules-audit` | Scan transcript for sycophancy, scope creep, filler, drift — report violations |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `SessionStart` | output-style-check | Validate the active output style against the rule set |
| `UserPromptSubmit` | behavioral-anchor | Inject rules into context each turn |
| `PreToolUse` (`Bash`) | block-destructive | Deny dangerous commands |
| `PreToolUse` (`Edit\|Write`) | scope-guard | Block edits outside the active scope allowlist |
| `PostToolUse` (`Write\|Edit`) | self-review-nudge | Nudge verification after long edit streaks |

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `FORGE_SAFE_MODE_THRESHOLD` | 5 | Consecutive failures before auto-entering safe mode |

## Disable

`/plugin disable behavioral-core@forge-studio` — but you'll lose the destructive-command guard. Pick another guard before disabling.
