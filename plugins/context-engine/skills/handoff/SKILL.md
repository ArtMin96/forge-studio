---
name: handoff
description: Generate a structured session handoff document for seamless context transfer to a fresh session.
when_to_use: When ending a session, switching tasks, or when context is getting full (>70% capacity).
disable-model-invocation: true
argument-hint: [topic]
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# Session Handoff

Generate a compact handoff document for seamless context transfer to a new session.

## Instructions

1. **Parse the topic** from `$ARGUMENTS`. If no argument is provided, default to `session`.

2. **Gather context** by running these commands:
   - `git diff --name-only` to get changed files
   - `git log --oneline -5` to get recent commits
   - `git status --short` to see uncommitted work

3. **Create the handoffs directory** if it doesn't exist:
   ```
   mkdir -p .claude/handoffs
   ```

4. **Generate the handoff document** at `.claude/handoffs/{YYYY-MM-DD}-{topic}.md` using today's date and the topic. Use the Write tool.

   The document MUST follow this exact structure:

   ```markdown
   # Handoff: {topic}
   Date: {YYYY-MM-DD}

   ## Done
   - {bullet points of completed work with file paths}

   ## In Progress
   - {what's partially done, current state}

   ## Blocked
   - {blockers or unknowns, or "None" if clear}

   ## Decisions
   - {key decisions made and WHY — rationale matters for future sessions}

   ## Files Changed
   - `{path}` — {one-line summary}

   ## Next Steps
   1. {prioritized list of what to do next}

   ## Gotchas
   - {anything the next session should watch out for}
   ```

5. **Keep the document under 200 tokens.** Be terse. Use short bullet points. File paths are more useful than prose. This is a reference document, not a narrative.

6. **Confirm** by outputting: "Handoff saved to `.claude/handoffs/{filename}`. Start a new session and run `/resume` to pick up where you left off."
