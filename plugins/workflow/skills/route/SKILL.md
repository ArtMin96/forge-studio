---
name: route
description: Choose the right workflow pattern for a task based on Anthropic's agent research. Use before starting any non-trivial work to pick the optimal approach.
disable-model-invocation: true
argument-hint: <task-description>
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Route: Pick the Right Workflow Pattern

Based on Anthropic's "Building Effective Agents" research. The right pattern depends on the problem — using the same approach for everything is the #1 efficiency killer.

Analyze the task described in $ARGUMENTS and recommend ONE pattern:

## Pattern Decision Tree

### 1. Simple Fix (Direct Execution)
**When:** Single file, clear scope, you can describe the diff in one sentence.
**Examples:** Typo fix, rename a variable, add a log line, small bug fix.
**Action:** Skip planning. Just do it. Verify with a quick test or build.

### 2. Prompt Chaining (Sequential Phases)
**When:** Multi-file change with known files. Clear what needs to happen.
**Examples:** Add a new API endpoint, refactor a function used in 3 places.
**Action:** Explore → Plan (list exact files + changes) → Implement → Verify.

### 3. Routing (Explore First)
**When:** Uncertain scope. You don't know which files are involved yet.
**Examples:** "Fix the auth bug" (which auth? where?), "Improve performance" (of what?).
**Action:** Use a subagent to explore the codebase first. Based on findings, pick pattern 1 or 2.

### 4. Orchestrator-Workers (Parallel Subagents)
**When:** Large feature with independent subtasks. Multiple files that don't depend on each other.
**Examples:** Add validation to 10 API endpoints, migrate 5 components to new pattern.
**Action:** Create plan, break into independent tasks, dispatch subagents in parallel.

### 5. Evaluator-Optimizer (Iterative Refinement)
**When:** Quality-sensitive work where the first version won't be good enough.
**Examples:** Complex algorithm, security-critical code, public API design.
**Action:** Implement → Self-critique → Iterate → Verify. Use `/challenge` from self-critic plugin.

## Output Format

```
RECOMMENDED PATTERN: [Pattern Name]
REASON: [One sentence why this pattern fits]
FIRST STEP: [What to do right now]
```

Key principle from Anthropic: "Start simple. Add complexity only when it demonstrably improves outcomes."
