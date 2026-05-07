# research-gate

Mechanical read-before-edit enforcement. Blocks `Edit` and `Write` on files that were not `Read` in the current session.

## What it does

A common failure mode: editing a file based on assumed contents, not actual contents. Industry data shows ~33% of edits go to files that were never read. This plugin prevents that — `Edit` and `Write` are denied unless the same file appears in the session's read history.

Once read, the file stays unlocked for the rest of the session. Re-reading on every edit is not required.

## When to use

You always want it on. The cost is one warning when you forget to read first; the benefit is catching mid-session hallucinated edits before they ship.

## How it works

```text
 PostToolUse (Read)        ──► record file path in session read-set
 PreToolUse (Edit/Write)   ──► check file in read-set
                              if absent: deny with explanation
                              if present: allow
```

The read-set is per-session. New session = clean slate.

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `PostToolUse` (`Read`) | track-file-reads | Record the file in the session read-set |
| `PostToolUse` (`Read\|Grep\|Glob`) | track-exploration | Track auxiliary exploration so partial-content reads count |
| `PreToolUse` (`Edit\|Write`) | require-read-before-edit | Deny edits to files not read this session |
| `PreToolUse` (`Edit\|Write`) | exploration-depth-gate | Require enough exploration for the file to count as "understood" |

## Disable

`/plugin disable research-gate@forge-studio`. You give up the safety net — pair with another guard or commit discipline before disabling.
