# Verify Refs

`/verify-refs` cross-checks every file path, function name, environment variable, package name, and URL claimed in your most recent assistant turn against the actual repository. For each claim it runs the appropriate check — `test -e` for paths, `git grep` for symbols and env vars, installed-package queries for package names — then reports a table of `YES / NO / SKIP` verdicts with the evidence. URLs are flagged for human verification rather than fetched automatically. The skill is advisory: it reports findings and offers corrections, but never silently rewrites the prior turn.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/verify-refs
```

No arguments. The skill scans the most recent assistant response automatically.

## Why you need it

Research on commercial LLMs documents that 3–13% of citation URLs are hallucinated, and code agents exhibit the same failure shape with file paths and symbol names — especially under context pressure as a session grows long. A summary that confidently names `plugins/agents/skills/contract/SKILL.md` when the file is actually at `plugins/agents/skills/contract/SKILL.md` but the function it attributes to that file doesn't exist is indistinguishable from a correct summary until someone reads the code.

`/verify-refs` makes hallucinated references visible before they reach a commit message, PR body, or user-facing summary. Because it checks every claim without filtering — paths, symbols, env vars, packages, URLs — it catches the full range of reference errors, not just the ones that feel suspicious. A clean verdict means you have evidence, not just confidence.

## When to use it

- Before pasting a PR body or commit message that names specific files, symbols, or endpoints.
- After a long summary of changes across multiple files, when context pressure increases hallucination risk.
- When the user asks "did you actually do X?" — run this first, then answer.
- After a context pressure warning (Stage 3 or higher), since reference hallucination risk climbs with context fill.

Do not use it for runtime verification (tests, lint) — that is `/verify`; verify-refs is purely a reference-existence sanity check.

## Best practices

- **Run it before every PR description.** PR bodies live in the permanent record. A hallucinated file path or function name in a PR description is more damaging than one in a conversation turn because it is harder to correct retroactively.
- **Act on every `NO` verdict.** The skill offers three responses to a missing reference: a correction if it can find the real path via grep, a retraction if the claim was wrong, or a surfaced ambiguity for the user. Choose one and apply it — do not ignore the `NO` and proceed.
- **Don't skip URLs.** The skill flags URLs as `SKIP` rather than fetching them automatically (to avoid slow, side-effecting network calls). That flag is a prompt to verify the URL yourself before using it, not a signal that it is probably fine.
- **Treat a `NO-REFS` result as success.** If the prior turn contained no file paths, symbols, or URLs, the skill returns `NO-REFS` silently. That is a legitimate outcome, not an error.

## How it improves your workflow

A single fabricated file path in a summary can send the next engineer on a five-minute search before they realize the file doesn't exist. At scale, across a session with dozens of turns, the cumulative cost of unverified references is significant — in reviewer time, in trust, and in the occasional bad patch applied to the wrong file. `/verify-refs` makes reference checking mechanical and cheap enough to run routinely, converting it from a manual skepticism exercise into a one-command gate.

## Related

- [`verify.md`](verify.md) — the runtime evidence gate (tests, lint, type-check); verify-refs is the reference-existence check that runs before committing summaries, not after running tests
- [`challenge.md`](challenge.md) — adversarial review of code; `/verify-refs` checks claims in prose, not code correctness
- [`gate-report.md`](gate-report.md) — session quality summary before commit; pair with verify-refs for complete pre-commit hygiene
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
