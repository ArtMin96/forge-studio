# token-efficiency

Token-waste prevention. One active hook catches duplicate file reads at `PreToolUse`; the `/token-audit` skill scans for the wider pattern set on demand.

## What it does

Reading the same file twice in one session is one of the most common token sinks. The `track-duplicate-reads.sh` hook fires before every `Read` and warns when the file is already in the session's read history. The audit skill covers the rest of the pattern surface — oversized outputs, tool-call density, large pasted blocks — but as on-demand reports, not always-on guards.

## When to use

- A session feels expensive and you want to know why
- You're doing a token-usage post-mortem on a long task
- You want passive duplicate-read warnings while you work

## How it works

```text
 PreToolUse (Read) ──► track-duplicate-reads.sh   warn if the file was already read this session
 /token-audit       ──► on-demand scan: duplicates, oversized outputs, tool-call density,
                                         large pastes — ranked findings + top 3 fixes
```

## Skills

| Skill | Purpose |
|---|---|
| `/token-audit` | On-demand session scan — duplicate reads, oversized outputs, tool-call density, large pasted blocks. Compact findings table + top three optimization recommendations |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `PreToolUse` (`Read`) | track-duplicate-reads | Warn before a file is read twice in the same session |

## Disable

`/plugin disable token-efficiency@forge-studio`. You lose the duplicate-read warning — `/audit-context` from `context-engine` still gives you a manual checkpoint.
