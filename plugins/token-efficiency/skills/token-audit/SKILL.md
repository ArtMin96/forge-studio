---
name: token-audit
description: Audit current session for token waste patterns. Identifies duplicate reads, large outputs, excessive tool calls, and recommends optimizations.
disable-model-invocation: true
model: haiku
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

Audit the current session for token waste. Run each check, then present findings in a compact table, followed by top 3 recommendations.

## Checks

**1. Duplicate reads**
```bash
ls /tmp/claude-reads-* 2>/dev/null | head -5
# For the current session dir, count files with >1 read
SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
ls /tmp/claude-reads-${SESSION_ID}/ 2>/dev/null | wc -l
```
Count how many unique files were read. Note any that were read multiple times (file exists = at least one read; the hook warns on the second).

**2. Edit churn**
```bash
SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
for f in /tmp/claude-edits-${SESSION_ID}/*; do echo "$(cat $f) edits: $f"; done 2>/dev/null | sort -rn | head -5
```
Files with high edit counts indicate re-work that burns context.

**3. MCP overhead**
```bash
claude mcp list 2>/dev/null | wc -l
```
Each MCP server injects instructions into every request. Count active servers — >3 is notable overhead.

**4. CLAUDE.md size**
```bash
wc -l CLAUDE.md 2>/dev/null || wc -l ~/.claude/CLAUDE.md 2>/dev/null
```
Anthropic recommends keeping CLAUDE.md under 200 lines. Over 200 = injected into every request at full cost.

## Output format

Present findings as a compact table:

| Check | Finding | Status |
|-------|---------|--------|
| Duplicate reads | N files re-read | ok / warn |
| Edit churn | Top file: N edits | ok / warn |
| MCP servers | N active | ok / warn |
| CLAUDE.md size | N lines | ok / warn |

Then list **Top 3 recommendations** based on actual findings. Be specific — name the file or server if relevant. Keep recommendations to one line each.
