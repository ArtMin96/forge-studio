---
name: context-tricks
description: Use when the user wants to learn techniques for long or complex sessions — covers guided compaction, partial compaction, side-question dispatch, checkpointing, and session discipline. Reference-style passive skill, applied inline whenever the conversation hits context-management questions.
when_to_use: Reach for this when the user asks "how do I keep context clean", "what's the best way to run a long session", or "should I /compact now"; also applicable when teaching or onboarding. Do NOT use to actually run an audit (`/audit-context`) or to make a real-time drift check (`/checkpoint`) — this skill is the playbook, not the operation.
disable-model-invocation: true
---

# Context Tricks: Master the Context Window

Context is your most precious resource. These techniques protect it.

## Guided Compaction
Don't let auto-compaction decide what to keep. Guide it:
```
/compact preserve the auth refactoring plan and test results
```
Add to CLAUDE.md for persistent guidance:
```
When compacting, always preserve: current plan, test results, key architectural decisions.
```

## Partial Compaction
Compress only part of the conversation:
1. `/rewind` — opens checkpoint menu
2. Select a message
3. Choose "Summarize from here"
This keeps recent context intact while compressing old context.

## /btw — Side Questions
Ask a quick question that doesn't enter conversation history:
```
/btw what's the syntax for Laravel's whereHas?
```
Answer comes back without polluting your working context.

## Checkpoints
Every Claude action creates a checkpoint. Use this aggressively:
- Try risky things. If they fail: `/rewind` → restore.
- Double-tap Escape or `/rewind` to open the menu.
- Restore conversation state, code state, or both.
- Checkpoints persist across sessions.

## @ File References
Include files instantly without waiting for Claude to read them:
```
@src/auth/middleware.php refactor this to use the new auth service
@src/api/ show me the API structure
```
Faster than waiting for Claude to Read the file. Paths can be relative or absolute.

## Session Discipline (The /clear Pattern)
```
Finish task → commit → /clear → new task
```
- Don't mix unrelated tasks in one session
- A clean session with a sharp prompt beats a messy 3-hour session
- The 5 seconds to clear saves 30+ minutes of diminishing returns
- After 2 failed corrections on the same issue: `/clear` and write a better prompt

## Session Naming
```
claude -n "auth-refactor"     # Start named session
/rename auth-refactor         # Rename during session
claude --resume auth-refactor # Resume by name later
```

## Compact at 60-70%, Not 90%
At 60-70% context, Claude still has clear recall of the full conversation. Compacting here produces BETTER summaries than waiting until 90% when quality has already degraded. Watch your status line.

## Subagents for Context Isolation
When you need to read many files for research:
```
Use a subagent to investigate src/auth/ and report what authentication patterns are used
```
The subagent reads 20 files. Only a 200-token summary returns to your session.
