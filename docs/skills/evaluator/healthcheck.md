# Healthcheck

`/healthcheck` gives you a one-command quality snapshot of your project. It auto-detects whether the codebase is PHP, JavaScript, TypeScript, or some combination, then runs the full appropriate pipeline for each: formatting check, static analysis, and tests. Each step reports `PASS`, `FAIL`, or `SKIP` with concrete details, and the output ends with an `HEALTHY` or `NEEDS ATTENTION` overall verdict. Pass `--quick` to skip the test suite and run only formatting and static analysis for a faster check.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/healthcheck
/healthcheck --quick
```

Use `--quick` when you want formatting and static analysis only, without running the test suite.

## Why you need it

Before committing or opening a PR, you typically want to know three things: is the code formatted, does static analysis pass, and do the tests pass. In a project with multiple languages these are separate commands with different output formats, and it is easy to forget one or to misread a partial failure as a full pass. Running them by hand also means you have to remember which tools the project uses — is it Pint or php-cs-fixer? Vitest or Jest? — and look up the right invocation.

`/healthcheck` collapses all of that into a single skill invocation. It detects `composer.json`, `package.json`, and `tsconfig.json` automatically and runs whichever pipelines apply. When something fails it shows you the first ten lines of the failing tool's output immediately, so you can act on it without hunting through logs.

## When to use it

- Before committing, when you want a full pass/fail across formatting, analysis, and tests without running each tool by hand.
- Before opening a pull request as a final sanity check.
- Whenever the user asks "is this healthy?" without specifying a tool.
- In `--quick` mode during active development when you want fast feedback on formatting and types between changes.

Do not use it for auditing Forge Studio's marketplace integrity — use `/validate-marketplace` or `/entropy-scan` for that; healthcheck targets the user's actual project code.

## Best practices

- **Fix failures in pipeline order.** Formatting failures are often the fastest to fix and can mask static analysis output. Fix `FAIL` steps top to bottom.
- **Use `--quick` for mid-session checks.** The full test suite can be slow. `--quick` gives you a useful signal in seconds when you are iterating; save the full run for pre-commit.
- **Act on the first ten lines.** The skill truncates failing tool output to ten lines to keep the report readable. Those ten lines are almost always enough to identify the issue; run the tool directly if you need the full output.
- **Run it before `/gate-report`.** Gate-report re-aggregates hook warnings; healthcheck actively runs the tools. The two complement each other: healthcheck confirms the project is clean, gate-report confirms the session produced no policy or scope violations.

## How it improves your workflow

The cost of a broken commit is a fix commit, a CI re-run, and a distracted review. `/healthcheck` moves the detection of those failures from the CI pipeline — where they are slow and public — to your local session, where they are fast and private. Because it auto-detects the project type and runs the appropriate tools, the cognitive overhead is near zero: one invocation, one verdict, concrete errors if anything fails.

## Related

- [`gate-report.md`](gate-report.md) — re-aggregates hook warnings from the session; pair with healthcheck before committing
- [`verify.md`](verify.md) — the evidence gate for task completion; healthcheck is the broader project-health check
- [`../behavioral-core/safe-mode.md`](../behavioral-core/safe-mode.md) — invokes healthcheck as the routine-health check when exiting a safe-mode lockdown
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
