# Reflect

`/reflect` is the Reflect-Memorize closure in the `workflow` plugin — it runs at the end of a successful sprint, compresses the plan contract, test results, and git diff into a three-line insight (what worked, what surprised, what to watch), and routes that insight to `/remember` for persistence across sessions. It takes about 30 seconds and converts one-time sprint experience into durable harness memory.

This skill is for successful outcomes. If the sprint ended in failure or produced a regression worth investigating, use `/postmortem` instead.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/reflect
```

An optional `[plan-path]` argument points to a specific plan file. When omitted, the skill resolves the active plan automatically.

## Why you need it

Every sprint produces experience — what the contract actually required, what turned out to be harder than expected, what edge case will probably bite the next person who touches this code. Without a deliberate step to capture that experience, it evaporates at the end of the session. The next sprint starts with the same assumptions. The same surprises recur.

`/reflect` makes the capture deliberate and cheap. Three lines, each under 120 characters, no hedging, no code snippets — just the conceptual insight that did not exist in the plan. The deduplification step means you are not just accumulating notes; you are building a set of distinct, non-redundant lessons that `/session-resume` and other memory-aware skills can surface in future sessions when the same territory comes up again.

The `/remember` integration is what makes the insight durable. Without it, the three lines live only in this session. With it, they are versioned, ledger-tracked, and available in every future session via the memory plugin.

## When to use it

- Immediately after `/tdd-loop` reports green for a non-trivial sprint — this is the primary trigger.
- After a non-trivial feature lands and the plan had a `## Contract` section worth reflecting on.
- When you notice a working pattern worth preserving — a deployment trick, an architectural invariant, a surprising performance characteristic.

Do not use it for failures or incidents — those go to [`/postmortem`](../evaluator/postmortem.md). `/reflect` is the successful-outcome reflection only. Do not run it for one-line fixes or sprints with no contract section — there is nothing to reflect against, and the skill will skip silently.

## Best practices

- **Be specific in the "Worked" line.** "Contract held" is too vague. "Count-drift contract held — install.sh, plugin descriptors, and docs all agreed with count.sh after the sweep" is evidence. Specificity is what makes the memory useful months later.
- **Name the surprise, not the solution.** The "Surprised" line should describe what you discovered, not what you did about it. The solution lives in git. The insight is the thing that was not in the plan.
- **Make "Watch" a signal, not a task.** The "Watch" line should be a leading indicator of future breakage, not a to-do item. "Retry logic assumes idempotency — test non-idempotent consumers before changing the retry policy" is a signal. "Add idempotency tests" is a task that belongs in the next plan.
- **Let it skip cleanly.** If the sprint had no contract, no git history, or the insight duplicates an existing topic, the skill skips without creating anything. This is correct behavior — do not force a reflection when there is nothing to reflect.
- **Enable auto-reflect on TDD sprints.** Set `WORKFLOW_TDD_REFLECT=1` to have `/tdd-loop` call this skill automatically at Phase 4. This is the lowest-friction way to accumulate sprint memory without having to remember to invoke it manually.

## How it improves your workflow

`/reflect` is the mechanism that prevents Forge Studio from being a stateless tool. Each invocation adds a node to the memory graph that connects a sprint's outcome to its plan, its test results, and the specific surprises that emerged during implementation. Over sessions, that graph becomes the practical institutional knowledge of your codebase — not documentation you wrote once and forgot to update, but lessons extracted from real sprints, deduplicated against each other, and surfaced automatically when the relevant territory appears again.

## Related

- [`/tdd-loop`](tdd-loop.md) — automatically calls this skill when `WORKFLOW_TDD_REFLECT=1` after Phase 3 gates green
- [`../evaluator/postmortem.md`](../evaluator/postmortem.md) — use instead for failed sprints; reflect is for successes only
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — session-to-session handoff; reflect writes to memory, not to the progress log
- [Architecture](../../architecture.md) — memory and behavioral steering in the 8-component harness model
