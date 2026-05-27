# Verify

`/verify` is the evidence gate for task completion. Before a task can be marked done, it runs the declared verification commands — tests, lint, type-check, build, or behavioral spot-check — captures the actual output, and compares results against `.claude/features.json` entries or the `/contract` criteria. It refuses to mark done unless every gate produced evidence: not "I think it works," but a quoted command result or a file reference you can audit later. When verification fails, it emits a per-criterion structured gradient (Dimension / Direction / Magnitude) and, when the gap exceeds the agent's autonomy, an Escalation Brief that names the options and recommends one.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/verify
```

No arguments. The skill reads the active plan's Contract section and `.claude/features.json` automatically to determine what to verify.

## Why you need it

"I believe it works" is not evidence. A model that has just written code has strong priors that the code is correct — it wrote it, after all — and those priors do not update reliably from reading the code again. The only reliable signal is running the actual verification command and quoting the actual output. Without that, a clean-looking diff can be a broken one, a passing test can be one that doesn't cover the changed line, and a "done" status can be a wish rather than a fact.

`/verify` closes the trust-then-verify gap by making evidence mandatory rather than optional. The `COVERED` and `UNCOVERED` fields in the output make its scope falsifiable: a downstream reader can tell exactly which criteria this gate exercised versus which were assumed. The Escalation Brief pattern handles the cases where the gap is real but the fix requires human input — rather than silently failing or blindly proceeding, the skill names the options and waits for a decision.

## When to use it

- Before committing, merging, or telling the user "fixed" — this is the primary use case.
- At the end of every task in the `/orchestrate` pipeline, where it serves as the per-task evidence gate.
- Whenever `.claude/features.json` exists and has `pending` or `in_progress` entries that need to be gated before the session ends.

Do not use it for deep adversarial review — that is `/challenge`, which runs in a fork after verify passes. Do not skip the convergence check just because tasks look complete — use `/safe-mode` if convergence is genuinely ambiguous.

## Best practices

- **Quote, don't paraphrase.** The skill's instructions are explicit: "Tests: 42 passed, 0 failed (0.83s)" is evidence; "Tests pass successfully" is not. If you cannot quote real output, verification has not happened.
- **Run features.json entries, not just the suite.** If `.claude/features.json` exists, run the `verify_cmd` for each `pending` or `in_progress` entry individually. The broader test suite passing does not mean a specific feature's verify_cmd passed.
- **Respect the convergence criterion.** If the active plan has a `## Convergence` section, run the convergence check before claiming done. A `met: false` result overrides all other green gates — the sprint is not done.
- **Use the Escalation Brief when stuck.** When the verdict is `VERIFIED: No` and the fix requires a decision you cannot make alone — ambiguous criteria, conflicting plan vs. HEAD, missing test fixtures — emit the brief rather than guessing. It names what is blocked and waits for instruction.
- **Clear the evaluation gate after a PASS.** When `VERIFIED: Yes` and an active plan exists, write the plan name to `~/.claude/evaluation-gate.flag` as the skill instructs. This allows `git commit` to proceed without a pre-commit warning.

## How it improves your workflow

`/verify` is the closing bracket on every unit of work. It converts the act of finishing a task from a subjective judgment ("I'm pretty sure this is right") into a recorded artifact ("here is the command output that proves it"). That artifact is what makes code review faster, what makes regression detection reliable, and what makes the history of a session auditable after the fact. In the `/orchestrate` pipeline it is the gate that stops a failing task from contaminating the next one — evidence before assertions, every time.

## Related

- [`challenge.md`](challenge.md) — the deeper adversarial review that runs after verify passes; not a substitute for verify
- [`gate-report.md`](gate-report.md) — session quality summary; reads the gate file that verify writes
- [`verify-refs.md`](verify-refs.md) — checks reference existence in prose; verify checks runtime correctness
- [`../agents/contract.md`](../agents/contract.md) — re-reads the plan's success criteria that verify gates against
- [`../workflow/orchestrate.md`](../workflow/orchestrate.md) — the pipeline that calls verify as the per-task evidence gate
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
