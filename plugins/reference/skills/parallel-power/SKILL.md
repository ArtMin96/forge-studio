---
name: parallel-power
description: Use when the user asks "how do I run things in parallel", "should I use worktrees", or wants the playbook for multi-session and parallel execution — worktrees, fan-out, writer/reviewer splits, headless mode, queue-and-collect. Reference-style passive skill that surfaces examples inline.
when_to_use: Reach for this for explaining parallel patterns, before choosing between `/fan-out` vs `/worktree-team`, or when teaching. Do NOT use to actually dispatch the work — `/dispatch` picks the route, `/fan-out` and `/worktree-team` execute it.
disable-model-invocation: true
---

# Parallel Power: Do More at Once

## Pattern 1: Parallel Worktrees
Work on multiple features simultaneously with zero conflicts:
```bash
claude --worktree feature-auth     # Isolated copy, own branch
claude --worktree bug-fix-123      # Another isolated copy
claude --worktree                  # Auto-generated name
```
Each worktree gets its own branch from `origin/HEAD`. Changes are isolated.

**Switching worktrees:** Use `EnterWorktree` with a `path` parameter to jump into an existing worktree — no need to create a new one each time.

**Cleanup:** Automatic when no changes were made. Worktrees whose PRs were squash-merged are also auto-removed.

**Tip:** Copy `.env` and other gitignored files by creating `.worktreeinclude`:
```
.env
.env.local
config/secrets.json
```

## Pattern 2: Writer/Reviewer Split
Use SEPARATE sessions for writing and reviewing — fresh context prevents bias:
1. Session 1: Write the code
2. Session 2: `claude --resume` or new session → review the code
3. Fresh context means the reviewer isn't anchored to the implementation decisions

## Pattern 3: Fan-Out Batch Processing
Process multiple files with the same operation:
```bash
# Generate task list
claude -p "list all controllers that need auth middleware" > tasks.txt

# Process each
while read file; do
  claude -p "add auth middleware to $file" --allowedTools "Read,Edit"
done < tasks.txt
```

## Pattern 4: Orchestrator-Workers (Subagents)
For large features with independent subtasks:
- Create a plan with independent work items
- Ask Claude to dispatch subagents for each item
- Each subagent works in isolation, returns a summary
- Main session synthesizes results

**Sweet spot:** 3-5 parallel agents. More than that is hard to review.

**Tip:** `/proactive` is an alias for `/loop` — use either for recurring orchestration patterns.

## Pattern 5: Session Per Concern
Don't mix unrelated tasks. Instead:
- `claude -n "auth-refactor"` — session for auth work
- `claude -n "api-tests"` — session for test writing
- `claude -n "bug-4521"` — session for a specific bug
- Resume any with `claude --resume auth-refactor`
