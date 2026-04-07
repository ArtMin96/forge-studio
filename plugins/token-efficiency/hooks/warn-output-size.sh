#!/usr/bin/env bash
# PostToolUse(Bash): Warn when command output is very large, wasting context tokens.

INPUT=$(cat)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_result.output // empty' 2>/dev/null)

if [ -z "$OUTPUT" ]; then
  exit 0
fi

LINE_COUNT=$(echo "$OUTPUT" | wc -l)

if [ "$LINE_COUNT" -gt 100 ]; then
  echo "Large output (${LINE_COUNT} lines). Consider piping through head/tail/grep to reduce context usage."
fi

exit 0
