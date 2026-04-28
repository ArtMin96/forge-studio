---
name: tdd-loop
description: Use when building a new feature or reproducing a bug test-first — drives a Red-Green-Refactor loop with three real-command completion gates (failing test exists → test passes → no regressions). Each phase runs in an isolated subagent so context from one phase can't leak into the next and produce premature green.
when_to_use: Reach for this when the contract or features.json defines clear acceptance criteria and tests are the right verification. Do NOT use for exploratory spikes (no tests yet), pure-refactor work (`/orchestrate refactor`), or one-line fixes — TDD overhead isn't justified there.
disable-model-invocation: true
argument-hint: <feature-or-bug-description>
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# /tdd-loop — Red → Green → Refactor

A three-phase test-first loop. Each phase has a **completion gate that runs a real test command** — no "I think it passes" language is allowed. Each phase runs in an isolated subagent context so the implementer can't rely on the planner's assumptions and the refactorer can't protect the implementer's choices.

## Preconditions

1. Detect the test runner once:
   - If `composer.json` contains `pestphp/pest` → `./vendor/bin/pest`
   - Else if `composer.json` contains `phpunit/phpunit` → `./vendor/bin/phpunit`
   - Else if `package.json` has a `test` script → `npm test` or `pnpm test` (match the lockfile)
   - Else: ask the user for the test command. Do not guess.
2. Store the command in a local variable. Reuse it in every gate. Do not change it mid-loop.

## Phase 1 — RED

**Goal**: write exactly one failing test describing *one* behavior. No production code.

Instructions:
- Invoke the built-in `Plan` or `Explore` subagent with `context: fork` so this phase doesn't contaminate the next one. The subagent reads the feature/bug description from `$ARGUMENTS`, identifies the nearest existing test file to mirror its style, and writes the new test.
- Test asserts against the **public interface** only. No mocking of internals. No testing private helpers.
- One behavior per test. Resist the urge to batch.

**Completion gate (must run):**

```bash
<TEST_CMD> <path-to-new-test>
```

The gate passes **iff** the exit code is non-zero AND the failure reason matches the expected behavior (not a syntax error, not a missing file). If the test passes or errors for the wrong reason, stop and fix the test before proceeding. Do not move on.

## Phase 2 — GREEN

**Goal**: write the *minimum* production code that flips the failing test to passing. Nothing else.

Instructions:
- Fresh subagent context (`context: fork`, `agent: general-purpose`). It sees only the failing test output from Phase 1 — not your Phase 1 reasoning. This prevents anticipating beyond the test.
- No speculative helpers, no "while I'm here" refactors, no extra test cases.
- If you find yourself writing code the test doesn't require, stop and add a test for it first.

**Completion gate (must run):**

```bash
<TEST_CMD> <path-to-new-test>
```

Gate passes iff exit code is zero. If any other test regressed, revert your change and narrow the edit — one test at a time.

## Phase 3 — REFACTOR

**Goal**: clean the implementation while tests stay green.

Instructions:
- Fresh subagent context for honest evaluation. Invoke `agents:reviewer` (read-only tools by design) so the reviewer cannot "fix" problems by editing — forcing it to either flag or pass.
- Refactor checklist:
  - [ ] Extract duplicated logic
  - [ ] Clarify names
  - [ ] Collapse unnecessary conditionals
  - [ ] Align with nearby conventions
- If nothing warrants change, return `No refactoring needed` with a one-line reason. Do not invent work.

**Completion gate (must run):**

```bash
<TEST_CMD>
```

Run the **full** suite, not just the new test — refactors can break neighbors. Gate passes iff exit code is zero.

## Phase 4 — REFLECT (optional)

**Goal**: compress the sprint into a durable, three-line insight (worked / surprised / watch) routed to memory.

Gated by `WORKFLOW_TDD_REFLECT=1`. Default is off — don't nag on quick fixes. Invoke `/reflect` with the active plan path. It handles deduplication against existing memory topics and skips silently when the insight adds nothing.

Why this phase exists: without it, every RED→GREEN→REFACTOR cycle is thrown away. Reflection-to-memory is what converts a one-shot sprint into durable learning; this phase is that conversion.

## After the Loop

- If this implements a plan item, mark it `[x]` in the plan file (so `turn-gate.sh` stops nudging).
- If the loop exposed a deeper issue, open a new plan item rather than scope-creeping this one.
- Do not declare done until Phase 3 gate passed. No exceptions.

## Why Context Isolation

Each phase in its own forked context prevents the implementer from "remembering" the planner's assumptions and prevents the refactorer from protecting the implementer's choices. Honest evaluation requires fresh eyes.

## Execution Checklist

Paste this into the response on first turn and tick boxes as each step completes. Unchecked boxes block "done".

- [ ] Phase 1 (RED): wrote failing test on a clean working tree
- [ ] Phase 1 gate: ran the suite, observed the new test fail with the expected assertion message
- [ ] Phase 2 (GREEN): implemented just enough code; did not touch the test file
- [ ] Phase 2 gate: ran the suite, the new test now passes, no other tests regressed
- [ ] Phase 3 (REFACTOR): cleaned up shape without changing behavior
- [ ] Phase 3 gate: full suite green, assertion count not lower than before
- [ ] Plan item marked `[x]` (so `turn-gate.sh` stops nudging)
- [ ] Optional `/reflect` invoked if `WORKFLOW_TDD_REFLECT=1`

## Known Failure Modes

- **Premature green.** Phase 2 reports the test passes but the test is asserting the wrong thing or was edited mid-loop. Mitigation: Phase 1 must produce the failing test on a clean tree; Phase 2 may not edit the test file.
- **Test deleted, not fixed.** Pressure to reach green tempts a "fix" that deletes the assertion. Phase 3 must run the *full* suite, not just the new test, and must compare assertion counts before/after.
- **Refactor reintroduces failure.** Phase 3 changes shape and re-breaks the test added in Phase 1. The completion gate requires the original test plus the full suite to be green at the end of Phase 3.
- **Skill skipped on "trivial" change.** A one-liner gets shipped without TDD because it "felt obvious", and an edge case slips through. Mitigation lives in the `when_to_use` exclusion: TDD overhead is not justified for typo-class fixes, but acceptance-criteria changes must run the loop even if small.
