---
name: fan-out
description: Apply the same operation to multiple files or components simultaneously using parallel subagents.
when_to_use: When the same operation must be applied to multiple independent files (e.g., bulk migration, batch refactor across controllers).
disable-model-invocation: true
---

# /fan-out — Parallel Batch Processing

## When to Use

- Same operation on multiple independent files (e.g., add auth middleware to 8 controllers)
- Bulk migration (e.g., update import paths across 12 modules)
- Parallel exploration (e.g., search 5 different subsystems for a pattern)

## Protocol

### Step 1: Define the operation
Describe the operation as a template:
```
Operation: <what to do>
Files: <list of targets>
Constraints: <what NOT to change>
```

### Step 2: Validate independence
Before fan-out, confirm:
- [ ] Each file can be modified independently
- [ ] No file depends on changes to another file in this batch
- [ ] The operation is the same for each file (parameterized, not custom)

If changes are interdependent → use pipeline instead.

### Step 3: Dispatch subagents
Launch subagents with:
- **Batch size:** 3-5 files per agent (sweet spot for review quality)
- **Context:** Each agent gets the operation template + its file list
- **Isolation:** Use `isolation: worktree` for write operations to prevent conflicts
- **Tools:** Match to operation type:
  - Read-only exploration: `Read, Glob, Grep, Bash`
  - Write operations: `Read, Write, Edit, Bash, Glob, Grep`

### Step 4: Synthesize results
After all agents complete:
1. Collect results from each agent
2. Check for conflicts or inconsistencies
3. Present unified summary to user

## Limits

- Max 5 parallel agents (more is hard to review)
- Max 8 files per agent (context quality degrades beyond this)
- Always verify one result manually before trusting the batch
