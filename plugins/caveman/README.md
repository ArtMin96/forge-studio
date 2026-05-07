# caveman

Compressed output style. Drops articles, filler, and pleasantries from every reply. Cuts response tokens ~65% with no loss of technical content.

## What it does

Wraps Claude Code's `output-styles` mechanism. The skill registers a system style at session start, so every reply is filtered: `the` → dropped, `just / really / basically / actually / simply` → dropped, "Great question!" / "You're absolutely right" → dropped. Code blocks and exact error strings are untouched.

## When to use

- You're paying for output tokens and want fewer of them
- Verbose replies are slowing you down on a long session
- You want the model to default to fragments and short synonyms

Skip if you need pretty prose, customer-facing drafts, or full explanations for someone learning the codebase.

## How it works

```text
 SessionStart ──► caveman-init.sh      reads .claude/caveman-mode (lite|full|ultra)
                                       writes the matching output-style file
 PostCompact  ──► caveman-restore.sh   re-asserts after compaction wipes context
```

Three intensity levels:

| Mode | Behavior |
|---|---|
| `lite` | No filler, but full sentences |
| `full` | Drop articles, fragments OK (default) |
| `ultra` | Telegraphic, single-noun replies |

Switch mid-session with `/caveman lite|full|ultra`. Claude Code's output-style mechanism keeps the chosen mode active for the rest of the session; `caveman-restore.sh` re-asserts it after compaction.

## Skills

| Skill | Purpose |
|---|---|
| `/caveman` | Change intensity mid-session |

## Hooks

| Event | Hook | Effect |
|---|---|---|
| `SessionStart` | caveman-init | Apply the configured mode |
| `PostCompact` | caveman-restore | Restore after compaction |

## Disable

`/plugin disable caveman@forge-studio` — replies revert to default verbosity.
