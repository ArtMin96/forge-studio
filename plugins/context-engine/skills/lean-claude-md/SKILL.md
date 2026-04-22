---
name: lean-claude-md
description: Trim a CLAUDE.md file to only the lines that change behavior. Applies the 30-line principle from Claude Code's creator.
when_to_use: When CLAUDE.md feels bloated, compliance has dropped, or the file has grown beyond 100 lines.
disable-model-invocation: true
argument-hint: [path-to-claude-md]
allowed-tools:
  - Read
  - Write
  - Glob
---

# Lean CLAUDE.md: Every Line Must Earn Its Place

Based on Boris Cherny's (Claude Code creator) workflow: ~100 lines that outperform 500-line files. The key: every rule exists because it solved a real problem.

## Process

1. **Read the CLAUDE.md** at the path in $ARGUMENTS (default: `./CLAUDE.md`)
2. **For every line, ask:** "If I remove this, would Claude make mistakes?"
   - If YES → keep it
   - If NO → mark for removal
3. **Check for redundancy with Claude's defaults:**
   - Claude already reads files before editing (don't need to say so)
   - Claude already uses git (don't need to explain git workflows)
   - Claude already follows language conventions (don't need to specify them)
   - Claude already writes tests (don't need generic test instructions)
4. **Check for lines that should be hooks instead:**
   - "Always run linter" → should be a PostToolUse hook
   - "Never force push" → should be a PreToolUse blocking hook
   - If it says "always" or "never", it might belong in a hook
5. **Apply primacy/recency placement:**
   - Most-violated rules at the TOP (first 5 lines)
   - Same critical rules at the BOTTOM (last 5 lines)
   - Less critical in the middle

## Output

Present two versions:
1. **Annotated original**: Each line marked [KEEP], [REMOVE], or [→ HOOK]
2. **Trimmed version**: The lean CLAUDE.md with only the keepers

Ask before overwriting the original. Suggest saving the original as `CLAUDE.md.backup` first.

## The 30-Line Test
If your trimmed version is still over 100 lines, you're probably including things Claude already does. Be more aggressive.
