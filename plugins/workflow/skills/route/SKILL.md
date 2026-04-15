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

## Adaptive Retrieval Strategy

After choosing a workflow pattern, recommend a **retrieval strategy** — what information to gather and how. Different task types benefit from different retrieval approaches (Meta-Harness, arXiv 2603.28052: domain-specific routing outperforms one-size-fits-all retrieval).

### Bug Fix Retrieval
- `git log --oneline --since="2 weeks" -- <file>` — recent changes that may have introduced the bug
- `git blame <file>` on the broken section — who changed what, when
- Grep for related error messages in traces (`~/.claude/traces/*.jsonl`)
- Check test files for the affected code — are there tests? Do they cover this case?

### New Feature Retrieval
- Grep the codebase for similar existing features — match their patterns
- Read the closest analogous component end-to-end before writing anything
- Check for shared utilities, base classes, or traits you should extend
- Look for migration patterns if the feature needs schema changes

### Refactor Retrieval
- Find all callers/dependents: `grep -rn "functionName\|ClassName" --include="*.php"`
- Check test coverage for affected code — are there tests that will catch regressions?
- `git log --oneline --diff-filter=M -20 -- <file>` — understand change velocity
- Identify the blast radius: how many files does this touch?

### Performance Fix Retrieval
- Check for N+1 queries, missing indexes, or unbounded loops in the affected path
- Look at similar performance fixes in git history: `git log --all --oneline --grep="perf\|slow\|optimize"`
- Profile data if available (logs, traces, APM)

### Documentation/Config Retrieval
- Read existing docs for the affected area — match the style
- Check related config files for patterns to follow
- Verify the change is consistent with README and any API specs

## Output Format

```
RECOMMENDED PATTERN: [Pattern Name]
REASON: [One sentence why this pattern fits]
RETRIEVAL: [Which retrieval strategy above + specific commands to run]
FIRST STEP: [What to do right now]
```

Key principle from Anthropic: "Start simple. Add complexity only when it demonstrably improves outcomes."
