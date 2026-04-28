---
name: worktree-team
description: Use when two or more streams of work must not interleave edits — concurrent feature branches, long-running research alongside implementation, or any time `/fan-out` would race because items share mutable state. Bootstraps N (max 5) parallel agents each in an isolated git worktree with a role-scoped CLAUDE.md and optional path ownership, so each role can only write to its declared subtree.
when_to_use: Reach for this when the request mentions running tasks "in parallel" with separate scopes, when planner/generator/reviewer must each have their own scratch space, or when previous attempts to coordinate via a single session produced merge conflicts. Do NOT use for one-shot batches that share no state — `/fan-out` is cheaper there.
disable-model-invocation: true
argument-hint: <role1,role2,...> [--owned <role>:<path>,<role>:<path>]
effort: high
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
---

# /worktree-team — Parallel Agents With Physical Isolation

Fan-out and pipeline both run inside one session. Sometimes what you want is N **separate sessions**, each with its own worktree, its own CLAUDE.md, and its own write scope. That's worktree-team.

## When to Use

- Two or more streams of work that must not interleave edits (e.g., one agent refactoring `src/api/`, another refactoring `src/ui/`).
- Long-running parallel research + implementation splits where you don't want either stream blocked on the other's context.
- Code review experiments where multiple agents attack the same problem in isolation for later comparison.

## When Not to Use

- In-session batch work → use `/fan-out`.
- Linear planner→generator→reviewer flow → use `/dispatch` with the existing pipeline pattern.
- Tasks that require shared intermediate state → worktrees make coordination harder, not easier.

## Protocol

### Step 1 — Confirm Preconditions

```bash
# Must be in a git repo
git rev-parse --show-toplevel >/dev/null || { echo "Not a git repo — abort."; exit 1; }

# Must have a clean-ish working tree (uncommitted changes would propagate)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Uncommitted changes in the main tree."
  echo "Worktrees inherit the working state. Commit, stash, or continue with caution."
fi
```

### Step 2 — Parse Roles

Default roles if none given: `planner`, `generator`, `reviewer`. Max 5 roles — parallel agents multiply token burn and coordination overhead past that point.

Role names must match lowercase-hyphenated pattern. Unknown roles fall back to a generic CLAUDE.md section.

### Step 3 — Create Worktrees

For each role:

```bash
SHORT_SHA=$(git rev-parse --short HEAD)
WORKTREE_DIR=".claude/worktrees/${ROLE}-${SHORT_SHA}"
mkdir -p "$(dirname "$WORKTREE_DIR")"
git worktree add "$WORKTREE_DIR" HEAD >/dev/null
```

Convention: `.claude/worktrees/<role>-<short-sha>`. Predictable path lets cleanup commands find them without a registry lookup.

### Step 4 — Compose Role-Scoped CLAUDE.md

For each role, write `<worktree>/CLAUDE.md` composed of:
1. The repo's `CLAUDE.md` contents (if it exists) — keeps project conventions.
2. A `## Role: <name>` section declaring this worktree's responsibility.
3. A `## Owned Directories` section listing directories the role may modify. Any Edit/Write outside these is out-of-scope.
4. A `## Coordination` section with the worktree root path so the agent knows where it is.

Template (populated per role):

```markdown
<repo CLAUDE.md contents>

---

## Role: <role>

You are the <role> in a worktree-team. You work in:

    <worktree absolute path>

## Owned Directories

<list from --owned flag or from a role-default table>

Do not modify files outside these directories. If a required change lies outside, STOP and hand off to the role that owns that path.

## Coordination

- This worktree is isolated from sibling worktrees.
- Siblings exist at: `.claude/worktrees/<other>-<short-sha>`
- Shared state (if any) lives at `.claude/worktrees/shared/` in the main repo. Writes to shared state must be atomic (append-only or rename-from-tmp).
- When you finish, commit to a role-named branch (`wt-<role>-<short-sha>`) and report.

## Tools Allowed

<default tool set per role — see table below>
```

Default tool sets by role:

| Role | Tools |
|---|---|
| planner | Read, Glob, Grep, Bash |
| generator | Read, Write, Edit, Bash, Glob, Grep |
| reviewer | Read, Grep, Glob, Bash |
| (other) | inherit from main agent |

### Step 5 — Emit Launch Instructions

The skill does **not** spawn the child Claude Code sessions. It emits the commands the user (or an outer orchestration script) runs:

```
Worktrees ready. Launch commands:

cd .claude/worktrees/planner-<sha>   && claude --agent planner
cd .claude/worktrees/generator-<sha> && claude --agent generator
cd .claude/worktrees/reviewer-<sha>  && claude --agent reviewer
```

Rationale: the user controls when to attach; the skill stays read-first and predictable.

### Step 6 — Write Active Role Registry

Write `.claude/agents/active-roles.json` (not per-worktree — this file lives in the main repo):

```json
{
  "roles": [
    {"name": "planner",   "worktree": ".claude/worktrees/planner-abc1234",   "owned": ["src/"]},
    {"name": "generator", "worktree": ".claude/worktrees/generator-abc1234", "owned": ["src/api/"]},
    {"name": "reviewer",  "worktree": ".claude/worktrees/reviewer-abc1234",  "owned": []}
  ],
  "created": "<ISO 8601 UTC>",
  "sha": "<short sha>"
}
```

This file is what the `directory-ownership` hook reads to decide whether a write is in scope. Without this file the hook stays silent.

## Cleanup

When the team finishes:

```bash
git worktree remove .claude/worktrees/<role>-<sha>
```

Or `git worktree list` + `git worktree prune` to clean up after crashes.

Remove `.claude/agents/active-roles.json` when the team is disbanded, or the `directory-ownership` hook will keep enforcing a stale scope.

## Output Format

```
## Worktree Team Ready

Base commit: <short sha>
Roles: <n>

| Role | Worktree | Owned |
|------|----------|-------|
| planner   | .claude/worktrees/planner-<sha>   | <paths> |
| generator | .claude/worktrees/generator-<sha> | <paths> |
| reviewer  | .claude/worktrees/reviewer-<sha>  | <paths> |

Launch commands:
<...>

Cleanup: `git worktree remove <path>` per role when done.
```

## Rules

- Max 5 roles. Reject more with a clear error.
- If a worktree path already exists, fail loudly — do not overwrite.
- Never commit from within the skill. Commits are the role's job inside its worktree.
- The `directory-ownership` hook activates only when `.claude/agents/active-roles.json` is present and `FORGE_DIRECTORY_OWNERSHIP=1`. Users who opt out keep single-agent behavior unchanged.
- `--owned` is optional. If omitted, roles with defaults (planner/generator/reviewer) get no owned-directory restriction (enforcement requires an explicit list).

## Execution Checklist

- [ ] Parsed roles from `<role1,role2,...>` — abort if more than 5
- [ ] Resolved current `HEAD` short SHA for worktree naming
- [ ] For each role: confirmed `.claude/worktrees/<role>-<sha>/` does not already exist (else fail loud)
- [ ] Created the worktree on a fresh branch (`<role>/<short-task>`) — never reuse a branch already checked out elsewhere
- [ ] Wrote a role-scoped `CLAUDE.md` into each worktree
- [ ] If `--owned` provided: wrote `.claude/agents/active-roles.json` and confirmed `FORGE_DIRECTORY_OWNERSHIP=1`
- [ ] Emitted launch commands and explicit `git worktree remove` cleanup per role

## Known Failure Modes

- **Stale worktree path collision.** A previous run that crashed before cleanup leaves `.claude/worktrees/<role>-<sha>/` on disk; bootstrap then aborts with "path exists". Resolve with `git worktree remove --force <path>` before re-running, never overwrite.
- **Roles starve when one writes outside `--owned`.** `directory-ownership.sh` denies the write but the role keeps trying — visible as a hot loop in trace logs. The fix is to widen the `--owned` glob for that role, not to disable the hook.
- **Branch already checked out elsewhere.** `git worktree add` refuses to mount a branch that another worktree already has. Use a fresh branch name (e.g. `<role>/<short-task>`) instead of reusing one.
- **Forgetting `git worktree remove` after merge.** Old worktrees pile up under `.claude/worktrees/` and confuse future bootstraps. Every successful run should end with explicit cleanup commands shown in the output.
