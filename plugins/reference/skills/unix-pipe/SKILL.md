---
name: unix-pipe
description: Use Claude Code as a Unix utility. Headless mode, piping, CI/CD integration, output formats.
when_to_use: When automating Claude into scripts, pipelines, or CI/CD workflows.
disable-model-invocation: true
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
