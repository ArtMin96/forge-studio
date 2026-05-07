# reference

Power-user playbooks. Three reference cards covering thinking modes, parallel execution, and unix-pipe automation — surfaced inline whenever those questions come up.

## What it does

Pure documentation skills. No hooks, no mutations. Each skill is a passive reference: when the conversation hits a relevant topic, the skill content is loaded and applied inline.

## When to use

- You're new to thinking modes and want to know when each is worth its cost
- You need to decide between worktrees, fan-out, or headless mode for a parallel task
- You want to wire Claude into a CI/CD pipeline or shell automation

## Skills

| Skill | Purpose |
|---|---|
| `/ultrathink` | Pick between low / medium / high / xhigh / max thinking effort. Cost vs quality per level |
| `/parallel-power` | Multi-session and parallel execution playbook — worktrees, fan-out, writer/reviewer splits, headless mode, queue-and-collect |
| `/unix-pipe` | Headless mode, stdin/stdout piping, JSON output formats. Claude as a CLI tool |

## Disable

`/plugin disable reference@forge-studio`. The skills become unavailable; no other functionality changes.
