# rtk-optimizer

Auto-installs [rtk-ai/rtk](https://github.com/rtk-ai/rtk) — Rust Token Killer — and registers its global Bash rewrite hook.

## What it does

Bash output piped into Claude Code is a major token sink. `rtk` rewrites shell output before it hits the model: deduplicates lines, compresses whitespace, truncates predictable noise, and preserves error markers. Drops typical command output by 30–60% without losing signal.

This plugin installs `rtk` on first session and wires it into Claude's Bash hook. A second `SessionStart` hook surfaces a remediation warning if the binary or hook drifts.

## When to use

You always want it on if you run `rg`, `find`, `npm test`, large `git log`, or any command that prints hundreds of lines.

Skip if your project has tight Bash output already (always compact, scripted commands).

## How it works

```text
 SessionStart ──► rtk-bootstrap.sh    idempotent: installs rtk + registers a global
                                      Bash hook on first run; fast-path no-op on
                                      subsequent sessions
 SessionStart ──► rtk-healthcheck.sh  verifies the binary + hook each session;
                                      warns on drift
```

The Bash hook runs on every Bash tool call: input → command → rtk-rewritten output → Claude.

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `SessionStart` | rtk-bootstrap | Install + register global Bash hook (idempotent) |
| `SessionStart` | rtk-healthcheck | Verify binary + hook each session; warn on drift |

## Configuration

| Variable | Effect |
|---|---|
| `FORGE_RTK_DISABLED=1` | Skip install and bootstrap |

## Disable

`/plugin disable rtk-optimizer@forge-studio`. The binary and Bash hook persist; remove `~/.local/bin/rtk` and unregister the hook in user settings to fully purge.
