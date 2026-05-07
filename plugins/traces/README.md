# traces

Execution trace collection and pattern analysis. Stores structured JSONL of bash, file, and failure events. Feeds the self-evolution loop with evidence, not opinions.

## What it does

Without a trace, every harness improvement is a guess. This plugin records what actually happens — every Bash invocation, every file edit, every tool failure, every session-end summary — into JSONL files under `~/.claude/traces/`. Skills slice that data into compiled summaries, failure clusters, and proposal artifacts that `/evolve` can consume.

## When to use

You always want it on. Hooks are passive collectors; skills are on-demand. The collected data is local-only and grows ~10–50KB per active session.

## How it works

```text
 PostToolUse (Bash)        ──► append to ~/.claude/traces/<date>-<cwd>.jsonl
 PostToolUse (Write|Edit)  ──► append file_path + intent to the same file
 PostToolUseFailure        ──► append failure record with stderr snippet
 StopFailure (rate_limit /
              server_error /
              auth_failed)  ──► log session that ended on a known error class
 SessionEnd                 ──► summary entry: counts, failure rate, files touched
```

Trace files roll daily, scoped per working directory. Old files are not auto-pruned — that's intentional, so monthly audits have history to work with.

## Skills

| Skill | Purpose |
|---|---|
| `/trace-stats` | Fast numeric summary — command counts, error rates, files modified, average tokens/turn. One screen, no analysis |
| `/trace-compile` | Compile raw JSONL into structured summary + error views |
| `/trace-review` | Pattern analysis — recurring failures, optimization opportunities |
| `/trace-evolve` | Cluster failure patterns; emit proposal artifacts for `/evolve` |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `PostToolUse` (`Bash`) | collect-bash-trace | Append Bash event to trace JSONL |
| `PostToolUse` (`Write\|Edit`) | collect-file-trace | Append file event |
| `PostToolUseFailure` | collect-failure-trace | Record failure context |
| `StopFailure` (`rate_limit\|server_error\|authentication_failed`) | log-stop-failure | Log on these failure classes only |
| `SessionEnd` | session-summary | Per-session aggregate |

## Configuration

| Variable | Effect |
|---|---|
| `FORGE_TRACES_DIR` | Override the default `~/.claude/traces/` location |

## Disable

`/plugin disable traces@forge-studio`. Existing trace files are kept; no new ones are written. `/evolve` loses one of its three proposal sources but still works with `/router-tune` and manual proposals.
