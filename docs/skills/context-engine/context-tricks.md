# Context Tricks

`/context-tricks` is the playbook for running long or complex Claude Code sessions without degrading context quality. It surfaces techniques for guided compaction, partial compaction, side-question dispatch, checkpointing, `@`-file references, session naming, and the discipline of knowing when to clear rather than continue. It belongs to the `context-engine` plugin, which provides context measurement, pressure management, and belief-state safety for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install context-engine@forge-studio
```

```text
/context-tricks
```

No arguments. The skill is a reference guide — it surfaces the relevant technique inline in response to context-management questions rather than producing a file artifact.

## Why you need it

Most context problems are not caused by a single large file or a runaway tool call. They accumulate from dozens of small decisions: letting compaction happen automatically instead of guiding it, asking a quick question that adds a hundred tokens of noise to the working context, waiting until 90% capacity to compact when the summary quality has already degraded. Each decision alone is minor; combined across a three-hour session they routinely cut working context in half.

The techniques in this skill address each failure mode individually, which means you can apply whichever one fits the moment rather than needing to restructure the entire session. Guided compaction, for example, costs five seconds to specify preservation instructions; those instructions directly improve the quality of what survives compaction. The `/btw` side-question pattern keeps one-off lookups from entering conversation history at all.

## When to use it

Reach for `/context-tricks` when the user is asking about session management, or when an ongoing session is approaching the point where these techniques would help:

- When asked "how do I keep context clean," "what's the best way to run a long session," or "should I `/compact` now."
- When onboarding someone to Claude Code who is not yet familiar with session discipline.
- When the current session is approaching 60–70% context and you want the right approach before compacting.
- When a risky operation is about to run and you want to set up a checkpoint-based recovery path first.

Do not use it for actually running an audit or drift check — `/context-tricks` is the playbook, not the operation. Use [`/audit-context`](audit-context.md) to measure overhead and get ranked recommendations, or [`/checkpoint`](checkpoint.md) to run an actual drift check.

## Best practices

- **Compact at 60–70%, not 90%.** At 60–70% context Claude still has clear recall of the full conversation and produces high-quality summaries. At 90%, quality has already degraded before compaction even runs. Watch the status line and act early.
- **Guide compaction explicitly.** Running `/compact preserve the current plan and test results` produces a far more useful summary than letting auto-compaction decide. Adding persistent guidance to CLAUDE.md (`When compacting, always preserve: current plan, test results, key decisions`) ensures every auto-compact applies the same instructions.
- **Use subagents for large file reads.** When a research step needs to read many files, dispatch it to a subagent. The subagent consumes its own context; only a short summary returns to your session. This can save hundreds of tokens compared to reading the files directly in the main session.
- **Use `@` references for targeted file inclusion.** Typing `@src/auth/middleware.ts refactor this` includes the file in the prompt immediately without a separate Read call and its associated overhead. Faster and more direct than asking Claude to read the file.
- **Name sessions and resume by name.** `claude -n "auth-refactor"` at the start and `claude --resume auth-refactor` later makes multi-day work on the same task resumable and organized, rather than starting from a fresh context with no history.

## How it improves your workflow

The techniques in `/context-tricks` collectively shift session management from reactive to proactive. Instead of waiting for context to fill and then scrambling to recover, you compact early (when summaries are accurate), isolate side questions (with `/btw`), isolate large reads (with subagents), and set recovery checkpoints before risky operations. The aggregate effect is that the useful portion of a long session stays large throughout: you arrive at the final turns with context headroom rather than exhausted budget. These techniques compose naturally with the rest of the context-engine plugin — use `/audit-context` to identify the biggest sources of overhead, apply the techniques here to keep them under control, and use [`/checkpoint`](checkpoint.md) or [`/token-pipeline`](token-pipeline.md) to monitor session health as work continues.

## Related

- [`/audit-context`](audit-context.md) — measures the actual token overhead of each context source; the diagnostic complement to this playbook
- [`/checkpoint`](checkpoint.md) — runs the mid-session drift check described in this playbook
- [`/token-pipeline`](token-pipeline.md) — structured in-flight pressure relief; use when context is actively filling
- [`/lean-md`](lean-md.md) — trims CLAUDE.md when the playbook's compaction guidance is not enough to offset its size
- [`../long-session/progress-log.md`](../long-session/progress-log.md) — the recommended pre-clear artifact that preserves session state
- [`../long-session/session-resume.md`](../long-session/session-resume.md) — session resumption patterns that pair with named sessions described here
- [Architecture](../../architecture.md) — where context management fits in the 8-component harness model
