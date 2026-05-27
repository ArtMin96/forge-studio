# Postmortem

`/postmortem` turns a recently fixed bug into a durable prevention record. It runs a structured autopsy: one-sentence description of what happened, root-cause chain (immediate cause, what allowed it to exist, any deeper design issue), classification into one of seven bug categories (state management, type mismatch, boundary error, logic error, integration, configuration, concurrency), a "could it have been caught earlier?" analysis pointing at a missing test or lint rule, and one concrete prevention recommendation. The output is a short `POSTMORTEM` block — not a five-hundred-word essay.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/postmortem null check missing on the user API response parser
```

The argument is an optional short description of the bug. If omitted, the skill infers it from context.

## Why you need it

Fixing a bug and moving on is the default. It is also how the same class of bug appears twice in six months. The fix is a patch on the symptom; the postmortem is the analysis that reveals the structural gap — the missing test, the untyped boundary, the absent validation — that allowed the symptom to exist. Without that analysis, the fix is complete but the lesson is lost.

`/postmortem` is deliberately short. It does not ask for a thorough narrative; it asks for the root-cause chain, a category, and one prevention action. That constraint forces specificity: "be more careful" is not an acceptable prevention recommendation, but "add an integration test for the user endpoint with an empty-payload response" is. The specificity is what makes the lesson reusable — it becomes a test to write, a lint rule to enable, or a validation to add, not just a note to self.

## When to use it

- After the fix is in and verified, before closing the loop on the work.
- After a `/safe-mode` exit — safe-mode is the reactive lockdown; postmortem is the after-the-fact analysis that turns the incident into a guardrail.
- After any non-trivial bug where the fix took more than a few minutes, especially if the bug had a wider blast radius than expected.
- Whenever the user wants to convert a recent failure into a durable lesson.

Do not use it as a way to debug a still-open bug — debugging happens first; postmortem is the after-the-fact analysis. Do not use it for adversarial pre-fix review — use `/challenge` for that; postmortem runs after the failure, not during it.

## Best practices

- **Run it while the context is fresh.** The root-cause chain is hardest to reconstruct after the session ends. Run the postmortem before `/progress-log` or compaction.
- **Be specific about the prevention action.** The output template asks for one concrete recommendation. Resist the urge to list several; the one most likely to prevent recurrence is the right answer.
- **File the missing test, don't just note it.** If the "could it have been caught earlier?" analysis points at a missing test, write that test in the same session. A postmortem that recommends a test but doesn't produce it is half-done.
- **Classify the category accurately.** The seven-category taxonomy is not decorative — it helps you notice patterns across postmortems. Three consecutive "type mismatch" entries in the same module is a signal that the module needs a stricter boundary.

## How it improves your workflow

Bugs are expensive twice: once when they occur, and once when a similar bug occurs because the first one left no trace. `/postmortem` makes every non-trivial fix pay dividends beyond the immediate patch by extracting a reusable prevention action. Over time, the accumulation of those actions — tests written, rules added, validations inserted — shifts the baseline quality of the codebase rather than merely restoring it.

## Related

- [`challenge.md`](challenge.md) — adversarial review before a change ships; postmortem is the analysis after a bug slips through
- [`verify.md`](verify.md) — the evidence gate that should catch issues before they become bugs
- [`gate-report.md`](gate-report.md) — session quality summary; review before committing to catch issues before they become postmortem candidates
- [`../behavioral-core/safe-mode.md`](../behavioral-core/safe-mode.md) — the reactive lockdown that postmortem is the intended follow-up to after a safe-mode exit
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
