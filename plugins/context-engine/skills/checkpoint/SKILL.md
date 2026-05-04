---
name: checkpoint
description: Use during long sessions when the conversation feels like it may have drifted, when an unrelated subgoal has appeared, or when tracking-error matters before the next major edit — runs a fast comparison of recent work against the original task statement, listing scope creep, context bloat, and unfulfilled acceptance criteria.
when_to_use: Reach for this every ~50 turns in a long session, after a long debugging detour, or when the user says "are we still on track?". Do NOT use for full session-quality audits with rule violations — that is `/rules-audit`; checkpoint stays small and fast.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
logical: drift report compares stated goal against current trajectory and recommends continue / refocus / split
---

# Session Checkpoint

Quick drift check: compare current work against the original plan. Keep this analysis SHORT.

## Instructions

1. **Find the plan or original task.** Check these locations in order:
   - `.claude/plans/` — use Glob to find any plan files, read the most recent
   - `.claude/handoffs/` — if no plan, check for a handoff that may describe the task
   - If neither exists, report: "No plan or handoff found. State your current task so I can track drift against it."

2. **Gather current work state:**
   ```bash
   git diff --stat
   git log --oneline -10
   ```

2b. **Plan-vs-actual file comparison** (if plan exists):
   - Read the plan file found in step 1
   - Extract file paths mentioned in the plan (look for backtick-quoted paths like `path/to/file.ext`, or paths in "Files to modify/create" sections)
   - Compare against `git diff --stat` output
   - Identify: files in diff but NOT in plan ("Unplanned"), and files in plan but NOT in diff ("Planned but untouched")

3. **Compare and analyze** (be terse):
   - What was planned vs. what's been done
   - Any files changed that weren't part of the plan (scope creep)
   - How many files/lines changed — is this proportional to the task?

4. **Report in this format:**

   ```
   ## Checkpoint

   **Drift detected:** {Yes/No}
   **Planned:** {1-line summary of original task}
   **Completed:** {brief list of what's done}
   **Unplanned files:** {files in diff but not in plan, or "None"}
   **Planned but untouched:** {files in plan but not in diff, or "None"}
   **Unplanned work:** {any scope creep beyond file drift, or "None"}
   **Context usage:** {rough estimate — low/medium/high based on session length}

   **Recommendation:** {one of:}
   - "On track. Keep going."
   - "Minor drift. Refocus on: {specific task}."
   - "Significant drift. Consider `/compact` to reclaim context."
   - "Session is heavy. Run `/progress-log` and start fresh."
   ```

5. **Keep the entire output under 150 words.** This checkpoint should not itself contribute to context bloat.
