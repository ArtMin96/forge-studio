---
name: timebox
description: Set a message budget for the current task. Forces efficiency by tracking progress against budget. Use when you want focused, fast work.
disable-model-invocation: true
argument-hint: [message-count]
allowed-tools:
  - Read
  - Write
---

# Set Timebox

Set a message budget to force focused, efficient work.

## Steps

1. Parse the message count from `$ARGUMENTS`. Default to **15** if no number is provided.
2. Create the directory `.claude/scopes/` if it does not exist.
3. Write the file `.claude/scopes/.timebox` with this exact content:

```
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

> **Timebox reached. Wrap up now: commit what works, /handoff what doesn't.**

Stop working on the task. Do not send further implementation messages.
