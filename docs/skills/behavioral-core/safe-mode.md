# Safe Mode

`/safe-mode` toggles a graceful-degradation lockdown. When the flag file `.claude/safe-mode` exists, `block-destructive.sh` denies **every** Bash, Write, and Edit until the flag is cleared — a forced human checkpoint. The flag is written automatically once consecutive tool failures hit `FORGE_SAFE_MODE_THRESHOLD` (default 5), or manually with `/safe-mode on`. `/safe-mode off` clears it, resets the failure counter, logs the exit to the ledger, and prompts you to run a postmortem. `/safe-mode status` reports the current state and, when present, a structured escalation brief.

It belongs to the `behavioral-core` plugin. Where [`/scope`](scope.md) and [`/timebox`](timebox.md) bound a task up front, `/safe-mode` is the reactive backstop: it halts mutation when the session has gone off the rails.

---

## Install

```bash
/plugin install behavioral-core@forge-studio
```

```text
/safe-mode status      # report current state
/safe-mode on [reason] # enter manually before a risky operation
/safe-mode off         # clear the lock, reset the counter, prompt /postmortem
```

## Why you need it

A failing agent rarely fails once. It retries, edits, retries again — and a chain of confident-but-wrong mutations can do real damage before anyone notices. `/safe-mode` puts a circuit breaker on that loop. After N consecutive failures the harness stops accepting destructive actions and hands control back to you with a brief explaining what it was doing, what tripped the breaker, and what the options are. You decide; the agent doesn't dig the hole deeper.

The manual form is just as useful: before a one-shot, hard-to-undo operation (a migration, a bulk delete), `/safe-mode on` makes the harness refuse mutations until you explicitly clear the lock — a deliberate "stop and think" you can set for yourself.

## When to use it

- **`/safe-mode off`** — after you've diagnosed the failure chain that auto-triggered the lock. Clearing it is the signal that a human has looked.
- **`/safe-mode on`** — right before a risky operation you want the harness to block until you consciously release it.
- **`/safe-mode status`** — to see whether the flag is set and read the escalation brief behind an auto-trigger.

Do not use it to skip a postmortem — clearing the flag without root-cause analysis defeats the whole point of the checkpoint. Do not use it for routine harness health checks; that's [`/healthcheck`](../evaluator/healthcheck.md). `/safe-mode` only toggles the destructive-edit lockdown.

## Best practices

- **Read the brief before clearing.** An auto-triggered flag carries a CONTEXT / TRIGGER / OPTIONS / RECOMMENDATION brief. That brief is the cheapest artifact in the failure — read it before you decide.
- **Run the postmortem.** `/safe-mode off` prompts [`/postmortem`](../evaluator/postmortem.md) for a reason: the failure that tripped the breaker is a lesson, and clearing the flag without capturing it guarantees a repeat.
- **Don't widen the lock here.** New blocking scopes belong in `block-destructive.sh`, the enforcement layer — `/safe-mode` only flips the switch it already reads.
- **Trust the safer default.** A malformed flag file is treated as active, and `/safe-mode off` still clears it. When in doubt, the lock stays on.

## How it improves your workflow

`/safe-mode` is the "block in the moment" guard that completes behavioral-core's steer→block→audit loop. Forward-looking rules and [`/scope`](scope.md) reduce the chance of trouble; `/safe-mode` contains it when it happens anyway. By bounding the blast radius of a failure chain to the moment it's detected — and forcing a human decision plus a postmortem before work resumes — it turns a potential cascade into a single, recoverable stop. The cost is one deliberate "clear and review" step; the benefit is that no failing session quietly mutates its way into a much bigger mess.

## Related

- [`/scope`](scope.md) · [`/timebox`](timebox.md) — proactive task bounds; `/safe-mode` is the reactive backstop
- [`/postmortem`](../evaluator/postmortem.md) — the intended follow-up after every `/safe-mode off`
- [`/healthcheck`](../evaluator/healthcheck.md) — for routine harness health, not lockdown
- [`/rules-audit`](rules-audit.md) — after-the-fact discipline audit; `/safe-mode` is real-time enforcement
- [Architecture](../../architecture.md) — graceful degradation in the 8-component harness model
