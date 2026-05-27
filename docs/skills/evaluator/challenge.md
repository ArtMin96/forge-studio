# Challenge

`/challenge` is a two-stage, heavyweight code critique. Stage 1 is a structured self-review of the diff you just produced — answering whether it could be simpler, what breaks, which part is weakest, whether it matches the original request, and whether a staff engineer would approve it. Stage 2 retrieves evidence from git history: confirmers (past changes to the same files that succeeded) and challengers (reverted or fix-up commits that signal known anti-patterns). The critique runs in a forked general-purpose subagent so it cannot be unconsciously shaped by the implementation context that produced the code.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

After completing a feature or fix, run it without arguments — the skill reviews the most recent diff in context:

```text
/challenge
```

## Why you need it

Passing tests is a low bar. A change can be green across the full suite while still being overly complex, silently non-idempotent, subtly out of scope, or repeating an anti-pattern the repo already discovered and reverted twice. The person who wrote the code is the least-qualified reviewer: they know what they intended, so they tend to read what they meant rather than what they wrote.

`/challenge` forces an adversarial self-examination before the work reaches a human reviewer. The two-stage structure matters: Stage 1 catches what the author should have caught; Stage 2 retrieves actual project history to validate or refute the Stage 1 assessment. A stage-1 "looks clean" verdict that stage-2 reveals as repeating a known regression pattern is a qualitatively different finding than either stage alone would produce.

## When to use it

- After finishing a complex feature, especially one with multiple interacting components.
- For security-sensitive code — authentication, authorization, serialization, input handling — where "tests pass" is not enough.
- When the diff is larger than expected and you want to catch scope creep before the user does.
- Before requesting a human review, to clean up the obvious issues first.

Do not use it for SEPL proposal verdicts — use `/assess-proposal` for that gate; and do not use it when a quick diff check is all you need — `/verify` is cheaper and runs first.

## Best practices

- **Be ruthless in Stage 1.** The output template explicitly lists "Would a Staff Engineer approve this?" — answer that question honestly, not optimistically.
- **Don't skip Stage 2 on new files.** If there is no git history for a new file, say so explicitly in the report. Absence of history is not the same as absence of risk.
- **Act on scope-match failures.** If Stage 1 reveals additions beyond scope, remove them before continuing — do not note and ignore.
- **Treat high-churn files as elevated risk.** If `git log` shows a file has changed more than ten times in the last month, flag that explicitly in the Churn Risk line. High churn means higher probability of interaction with in-flight changes.
- **Read the challengers carefully.** A revert commit often contains a comment explaining why the approach failed. That explanation is worth more than any static analysis tool.

## How it improves your workflow

`/challenge` closes the gap between "I think this is correct" and "I know why this is correct." By forcing a structured self-interrogation before human review and grounding that interrogation in actual project history, it catches the class of issues that code review is least effective at finding: scope creep that looked like initiative, complexity that felt like thoroughness, and anti-patterns that were obvious in retrospect. The forked subagent context ensures the assessment is genuinely independent rather than a rationalization of choices already made.

## Related

- [`verify.md`](verify.md) — the cheaper, in-line evidence gate; run `/verify` first, then `/challenge` for deeper critique
- [`devils-advocate.md`](devils-advocate.md) — argues against a forward-looking design decision; `/challenge` reviews what was already written
- [`assess-proposal.md`](assess-proposal.md) — the SEPL-specific verdict gate for harness proposals
- [`postmortem.md`](postmortem.md) — run after a bug lands to extract a prevention lesson; `/challenge` runs before shipping
- [Architecture](../../architecture.md) — where evaluation fits in the 8-component harness model
