# TDD Loop

`/tdd-loop` drives a disciplined Red → Green → Refactor cycle for building new features or reproducing bugs test-first. It belongs to the `workflow` plugin. Each of its three phases has a real completion gate that runs an actual test command — not a confidence statement, a command with an exit code — and each phase runs in an isolated subagent context so the implementer cannot rely on the planner's assumptions and the refactorer cannot protect the implementer's choices. An optional fourth phase routes the sprint's lessons to persistent memory via `/reflect`.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/tdd-loop add rate-limiting to the billing API
```

The argument is the feature or bug description. It is passed to the Phase 1 subagent as its specification input.

## Why you need it

Test-first development prevents a specific class of error that is common in agentic coding: the implementation is written, then a test is written to match it, and the test passes because it was written to match the code rather than to describe the desired behavior. This is not testing — it is documentation of what was written, which may or may not be what was wanted.

`/tdd-loop` structurally prevents this by requiring a failing test to exist and pass the Phase 1 gate before any production code is written. The Phase 1 gate is explicit: the test must exit non-zero and the failure reason must match the expected behavior, not a syntax error or a missing import. Only after that gate passes does the Phase 2 subagent see the failing test output — and crucially, that subagent runs in a fresh context that does not include the Phase 1 reasoning, so it cannot anticipate beyond the test.

The context isolation between phases is the structural enforcement of honest evaluation. A refactorer that runs in the same context as the implementer has strong priors that the implementation is correct and may unconsciously protect it. A refactorer that starts fresh, seeing only the tests and the code, can evaluate honestly.

## When to use it

- When a feature or bugfix has acceptance criteria that can be expressed as failing tests before implementation — this is the primary use case.
- When the plan or `features.json` defines clear acceptance criteria and the feature is non-trivial enough to warrant the three-phase discipline.
- When you want to ensure that no implementation commit exists without a preceding RED commit.

Do not use it for exploratory spikes where no tests exist yet, pure-refactor work where tests are green and the change is structural (use [`/orchestrate pipeline`](orchestrate.md) for staged refactors), or one-line fixes where the TDD overhead is not justified. The exclusion exists because forcing a RED-GREEN cycle on a typo fix produces noise, not rigor.

## Best practices

- **Do not edit the test file in Phase 2.** The Phase 2 subagent may write production code only. Editing the test to make it pass is not passing the gate — it is destroying the gate. The Phase 3 full-suite run catches deletions by comparing assertion counts before and after.
- **One behavior per test in Phase 1.** The temptation to batch multiple assertions into one test is strong; resist it. One behavior per test means one red commit, one green commit, one attributable cause when a regression appears six sprints later.
- **Do not declare done until Phase 3 passes.** The Phase 2 gate confirms the new test passes. The Phase 3 gate confirms the full suite passes. Both gates are required. A Phase 2 green that has not been followed by a Phase 3 green is not done.
- **Use `WORKFLOW_TDD_REFLECT=1` to capture lessons automatically.** When this environment variable is set, `/tdd-loop` calls `/reflect` after Phase 3 passes, routing the sprint's three-line insight to memory without an extra manual step.
- **Detect the test runner once and reuse it.** The skill detects the test runner at the start (Pest, PHPUnit, npm test, or user-specified) and uses the same command throughout all three gates. Do not change the test command mid-loop.

## How it improves your workflow

`/tdd-loop` converts acceptance criteria from plan text into executable proof. When the sprint completes, you have not just code that looks right — you have a test that was written to fail, verified to fail for the correct reason, made to pass by the minimum possible implementation, and survived a full-suite refactor pass. That sequence is a chain of evidence that a later regression can be traced against: if the test breaks in a future sprint, you know exactly what behavior regressed and can see exactly the commit that introduced it. The per-phase context isolation is what keeps that evidence honest.

## Related

- [`/orchestrate`](orchestrate.md) — use for multi-task plans where staged pipeline dispatch fits better than a single TDD loop
- [`/reflect`](reflect.md) — called automatically after Phase 3 when `WORKFLOW_TDD_REFLECT=1`; captures the sprint's lessons for future sessions
- [`../evaluator/verify.md`](../evaluator/verify.md) — the evidence-gate skill; `/tdd-loop`'s completion gates operate on the same principle
- [`../agents/contract.md`](../agents/contract.md) — the contract re-read that prevents context decay; pairs with TDD when the feature is tracked in a plan
- [Architecture](../../architecture.md) — multi-agent decomposition and evaluation in the 8-component harness model
