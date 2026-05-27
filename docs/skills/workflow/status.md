# Status

`/status` produces a compact, read-only situational report of where your session stands — the active plan, last progress entry, recent execution traces, context pressure level, router classification stats, and convergence criterion state if the active plan declares one. It belongs to the `workflow` plugin. The report is under 200 tokens and pulls exclusively from artifacts already written by other plugins; it creates no new state of its own.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/status
```

No arguments.

## Why you need it

After returning from a break, mid-session before deciding what to work on next, or when you want a quick sanity check without disrupting context, you need a single command that surfaces all the session-state signals in one place. Without it, you have to run `find-active-plan.sh` yourself, check `claude-progress.txt` manually, guess at context pressure, and recall whether the active plan's convergence criterion was last seen as met or unmet.

`/status` does all of that in one turn and formats the result as a six-line report that fits on a single screen. The convergence section is particularly useful mid-sprint: knowing that `convergence: met: false — gap: expected 20 plugins, count.sh reports 19` tells you exactly what is still missing before you make the final push to done.

## When to use it

- Any time you want a quick situational report without creating new artifacts — this is the primary use case.
- After returning from a break or switching context, before deciding what to work on next.
- As a mid-session sanity check: "Am I close to context limits? Is the convergence criterion met yet? Did the router classify the last few prompts the way I expected?"

Do not use it for writing state — that is [`/progress-log`](../long-session/progress-log.md), which records session-to-session handoff notes. `/status` is read-only.

## Best practices

- **Use it before `/compact` or `/clear`.** Knowing the active plan, unchecked task count, and context pressure before compacting gives you the information you need to decide whether to run `/progress-log` first.
- **Treat empty sections as signal.** The skill reports silently when a section has no data (`No active plan.`, `No progress recorded.`). Multiple empty sections at the start of a session mean you should probably run `/session-resume` before doing any work.
- **Pair the router stats with `/router-tune`.** The router section shows classification counts by pattern for the current session. If you see `single-agent:8 pipeline:0` in a session where you ran several multi-task sprints, the router is under-classifying pipeline work and `/router-tune` may be worth running once you have enough history.
- **Read context pressure early.** The pressure level is labeled by stage: Notice (below 40%), Moderate (40–60%), Elevated (60–75%), High (75–90%), Critical (above 90%). If you see Elevated or higher, consider whether you need `/compact` before starting the next task.

## How it improves your workflow

`/status` is the dashboard equivalent for an agentic session — a single read-only view that surfaces the signals you need to make good decisions about what to do next. By composing information from six different plugin artifacts into one compact report, it eliminates the round-trips of manually checking each artifact separately. The convergence line in particular converts a question that would otherwise require running a shell command and parsing its output ("is the sprint done yet?") into a one-line answer you get for free every time you ask for status.

## Related

- [`/convergence-check`](convergence-check.md) — the internal helper this skill calls to evaluate the active plan's convergence criterion
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — use instead for writing session-to-session handoff notes
- [`../long-session/session-resume.md`](../long-session/session-resume.md) — use to load progress notes at the start of a new session when `/status` shows stale state
- [`/router-tune`](router-tune.md) — use when router stats show a persistent misclassification pattern across sessions
- [Architecture](../../architecture.md) — context management and execution traces in the 8-component harness model
