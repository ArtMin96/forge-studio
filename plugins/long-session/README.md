# long-session

Session-to-session continuity. An init script for the dev environment, an append-only progress log, and a machine-readable list of testable requirements.

## What it does

Multi-day work fragments. You finish a session, come back, and spend twenty minutes re-orienting. This plugin makes the orientation deterministic: `init.sh` recreates the dev state, `claude-progress.txt` is the durable record of what's done / in-progress / blocked, and `features.json` lists the testable requirements so verification stays grounded.

## When to use

- Work spans multiple sessions or days
- You want a single command to bring a fresh session up to speed
- You're using `/tdd-loop` or `/verify` and need machine-readable requirements

Skip if every task fits in one session.

## How it works

```text
 SessionStart ──► bootstrap-substrate.sh  ensure .claude/ scaffolding exists
                  surface-progress.sh     read claude-progress.txt + spec.md + features.json
                                          + .precompact-feedback.txt (memory plugin)
                                          and brief the new session
```

Three artifacts:

| File | Purpose |
|---|---|
| `init.sh` | Bootstraps the dev environment — install, build, test, run |
| `claude-progress.txt` | Append-only log: completions, in-progress, blockers, next steps |
| `.claude/features.json` | Testable requirements with `verify_cmd` per item |

`/feature-list` expands the latest plan's `## Contract` section into `features.json`. `/tdd-loop` and `/verify` consume that file.

## Skills

| Skill | Purpose |
|---|---|
| `/init-sh` | Generate an executable `init.sh` for the current project |
| `/progress-log` | Append the current session's net outcomes to `claude-progress.txt` |
| `/feature-list` | Expand plan contract → `features.json` |
| `/session-resume` | Brief the current session from the long-session artifacts |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `SessionStart` | bootstrap-substrate | Ensure `.claude/` scaffolding exists |
| `SessionStart` | surface-progress | Read `claude-progress.txt`, `features.json`, `spec.md`, plus the `memory` plugin's `.precompact-feedback.txt` snapshot so corrections from before the last compaction carry into the new session |

## Disable

`/plugin disable long-session@forge-studio`. The artifact files stay on disk; nothing reads them automatically.
