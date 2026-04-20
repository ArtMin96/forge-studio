---
name: tdd-loop
description: Red-Green-Refactor loop with real-command completion gates. Use when building features or reproducing bugs test-first. Each phase runs in an isolated subagent context to prevent pollution.
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

A three-phase test-first loop. Each phase has a **completion gate that runs a real test command** — no "I think it passes" language is allowed.

Based on:
- mattpocock/skills `tdd`: vertical slicing (one test → one implementation), public-interface-only assertions, "never refactor while red."
- alexop.dev *Custom TDD Workflow for Vue*: context isolation per phase raised skill activation rates from ~20% to ~84%.

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

## After the Loop

- If this implements a plan item, mark it `[x]` in the plan file (so `turn-gate.sh` stops nudging).
- If the loop exposed a deeper issue, open a new plan item rather than scope-creeping this one.
- Do not declare done until Phase 3 gate passed. No exceptions.

## Why Context Isolation

Per alexop.dev's harness: each phase in its own forked context prevents the implementer from "remembering" the planner's assumptions, and prevents the refactorer from protecting the implementer's choices. Honest evaluation requires fresh eyes.
