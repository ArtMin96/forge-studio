---
name: timebox
description: Use when the user says "timebox this", "spend at most N messages on it", or wants a hard ceiling on conversation length for the current task — writes a budget file at `.claude/scopes/.timebox` that the brevity rule and scope-guard read on every turn to count remaining messages.
when_to_use: Reach for this before a focused, exploratory, or boxed-in task where overrun risk is high (debugging spirals, perfectionist refactors). Do NOT use for open-ended planning where the budget can't be estimated up front — `/scope` (which carries its own budget) is the better starting point there.
disable-model-invocation: true
argument-hint: [message-count]
allowed-tools:
  - Read
  - Write
logical: .claude/scopes/.timebox file exists with budget, remaining, and started fields
---

# Set Timebox

Set a message budget to force focused, efficient work.

## Steps

1. Parse the message count from `$ARGUMENTS`. Default to **15** if no number is provided.
2. Create the directory `.claude/scopes/` if it does not exist.
3. Write the file `.claude/scopes/.timebox` with this exact content:

```yaml
budget: {N}
remaining: {N}
started: {ISO 8601 timestamp}
```

4. After creating the file, output:

> **Timebox set: {N} messages.** You have {N} messages to complete this task. No unnecessary exploration, no verbose explanations, no over-engineering. Be surgical.

## Ongoing Behavior

After each message, decrement the `remaining` count in `.claude/scopes/.timebox` and remind yourself:

> **[{remaining}/{budget} messages left]**

When `remaining` reaches **3**, add urgency:

> **[{remaining}/{budget}] — Running low. Start wrapping up.**

When `remaining` reaches **0**:

> **Timebox reached. Wrap up now: commit what works, /progress-log what doesn't.**

Stop working on the task. Do not send further implementation messages.
