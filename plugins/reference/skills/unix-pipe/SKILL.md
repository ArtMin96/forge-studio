---
name: unix-pipe
description: Use when the user wants to automate Claude into scripts, pipelines, or CI/CD workflows — covers headless mode, stdin/stdout piping, JSON output formats, and Claude-as-a-CLI-tool patterns. Reference-style passive skill, applied inline whenever automation comes up.
when_to_use: Reach for this when teaching headless usage, building a CI gate, or composing Claude with other shell tools. Do NOT use for in-session orchestration — that's `/orchestrate` and `/dispatch`; unix-pipe is for *outside* the interactive session.
disable-model-invocation: true
logical: reference content surfaced explaining headless / piping patterns; no execution side effects
---

# Unix Pipe: Claude as a CLI Tool

Claude Code follows Unix philosophy — it's composable with other tools.

## Headless Mode (-p flag)
Run without interactive session:
```bash
claude -p "explain this error" < error.log
claude -p "write a migration for adding email_verified_at to users" > migration.php
claude -p "review this diff for security issues" < <(git diff)
```

## Piping
```bash
# Analyze build errors
cat build-error.txt | claude -p 'explain root cause and fix' > analysis.txt

# Generate commit message from diff
git diff --staged | claude -p 'write a concise commit message'

# Review a file
cat src/auth.php | claude -p 'review this for security vulnerabilities'
```

## Output Formats
```bash
claude -p "prompt" --output-format text         # Plain text (default)
claude -p "prompt" --output-format json         # Structured JSON
claude -p "prompt" --output-format stream-json  # Streaming JSON (for real-time)
```

## CI/CD Integration
```bash
# In GitHub Actions or CI pipeline
claude --permission-mode auto -p "fix all lint errors and commit"

# With tool restrictions
claude -p "review code" --allowedTools "Read,Grep,Glob"
```

## npm Scripts Integration
```json
{
  "scripts": {
    "ai:review": "git diff --staged | claude -p 'review this diff'",
    "ai:commit": "git diff --staged | claude -p 'write commit message'",
    "ai:test": "claude -p 'generate tests for recently changed files'"
  }
}
```

## Verbose Mode for Debugging
```bash
claude -p "prompt" --verbose  # Show tool calls and reasoning
```
