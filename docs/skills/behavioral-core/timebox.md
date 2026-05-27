# Timebox

`/timebox` puts a hard ceiling on how many messages the assistant spends on the current task. You give it a number; it writes a small budget file at `.claude/scopes/.timebox` with `budget`, `remaining`, and `started` fields. The brevity rule and `scope-guard.sh` read that file each turn, the remaining count is decremented and surfaced as you go, and when it hits zero the assistant stops and wraps up rather than spiralling.

It belongs to the `behavioral-core` plugin. Where [`/scope`](scope.md) bounds *where* the assistant may edit, `/timebox` bounds *how long* it may keep going.

---

## Install

```bash
/plugin install behavioral-core@forge-studio
```

```text
/timebox 10
```

The argument is the message budget. Omit it and the default is 15. The skill writes `.claude/scopes/.timebox` and confirms with the budget.

## Why you need it

Some tasks have no natural stopping point — a debugging session that keeps almost-working, a refactor that keeps finding "one more thing", an exploration that fans out indefinitely. Left unbounded, these burn tokens and context on diminishing returns, and the longer a session runs the more behavioral drift accumulates. `/timebox` forces the question "is this still worth another message?" to be answered explicitly, by a counter, instead of implicitly by exhaustion.

The countdown is visible. At 3 remaining it adds urgency; at 0 it tells the assistant to commit what works and `/progress-log` what doesn't. That converts an open-ended grind into a boxed effort with a defined exit.

## When to use it

Reach for it before a task with high overrun risk:

- Debugging spirals, perfectionist refactors, or anything where "just a bit more" tends to win.
- Focused, surgical work where you want speed over thoroughness.
- Spikes and experiments you've decided to cap regardless of outcome.

Do not use it for open-ended planning where you can't estimate a budget up front — guessing a number there just produces a meaningless ceiling. [`/scope`](scope.md), which carries its own file budget, is the better starting point for work whose shape isn't clear yet.

## Best practices

- **Set it before starting, not mid-spiral.** The value is committing to a ceiling while you're still calm about the task, not bolting one on once you're already frustrated.
- **Pick a number you'll respect.** A budget you reflexively extend at zero is theatre. If you keep overrunning, the estimate was wrong — re-scope rather than re-budget.
- **Honour the zero.** When the box is spent, the discipline is to commit what works and `/progress-log` the rest for a fresh session, not to push past the line in degraded context.
- **Combine with a scope.** `/timebox` (message ceiling) plus [`/scope`](scope.md) (file allowlist) bound both axes of a task at once.

## How it improves your workflow

`/timebox` makes the cost of continuation legible. Token and context budgets are usually invisible until they're gone; a live `[remaining/budget]` counter turns that into a decision you make on purpose. It reinforces the brevity rule — verbose, exploratory turns spend the budget faster, so the ceiling naturally pushes responses toward signal. The payoff is fewer runaway sessions, cleaner hand-offs at the boundary, and a habit of treating attention as the finite resource it is.

## Related

- [`/scope`](scope.md) — file allowlist + max-files budget; the spatial complement to timebox's temporal budget
- [`/rules-audit`](rules-audit.md) — high filler/padding counts often mean a session that needed a timebox
- [`/progress-log`](../long-session/progress-log.md) — what to run when the box is spent and work remains
- [Architecture](../../architecture.md) — behavioral steering in the 8-component harness model
