---
name: resume
description: Resume work from the latest handoff document. Use at the start of a new session to pick up where you left off.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Resume Session

Pick up where the last session left off by reading the most recent handoff document.

## Instructions

1. **Find the latest handoff document.** Use Glob to search for `.claude/handoffs/*.md`. Sort by filename (they are date-prefixed) and pick the most recent one. If no handoffs exist, report: "No handoff documents found in `.claude/handoffs/`. Nothing to resume."

2. **Read the handoff document** using the Read tool. This is your briefing.

3. **Check for uncommitted changes:**
   ```bash
   git status --short
   ```
   Report whether there are uncommitted changes and list them briefly.

4. **Check for failing tests** (best effort):
   - Look for common test scripts: check `package.json` for a `test` script, look for `Makefile` test targets, or `pytest`/`cargo test`/`go test` conventions.
   - If a test command is identified, run it and report pass/fail.
   - If no test command is found, note: "No test command detected — verify manually."

5. **Present the briefing** in this format:

   ```
   ## Session Briefing

   **Last handoff:** {filename} ({date})

   **Summary:** {1-2 sentence summary from the Done/In Progress sections}

   **Uncommitted changes:** {yes/no, brief list if yes}

   **Test status:** {pass/fail/unknown}

   **Next steps** (from handoff):
   1. {prioritized items from the handoff}

   **Gotchas:** {anything flagged in the handoff}

   Ready to continue. What would you like to tackle first?
   ```
