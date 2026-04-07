#!/usr/bin/env bash
# Context Guardian: Warn when tool output is large (token waste) or near truncation (data loss).
# PostToolUse hooks receive JSON on stdin with tool_result field.

INPUT=$(cat)

# Extract the tool output text
OUTPUT=$(echo "$INPUT" | jq -r '.tool_result.output // empty' 2>/dev/null)

if [ -z "$OUTPUT" ]; then
  exit 0
fi

# Check output length (50K char truncation boundary) — highest priority
OUTPUT_LEN=${#OUTPUT}
THRESHOLD=45000

if [ "$OUTPUT_LEN" -ge "$THRESHOLD" ]; then
  echo "Tool result may be truncated (${OUTPUT_LEN} chars, limit ~50K). Re-run with narrower scope if results seem incomplete."
  exit 0
fi

# Check line count (token waste for large but non-truncated output)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)

if [ "$LINE_COUNT" -gt 100 ]; then
  echo "Large output (${LINE_COUNT} lines). Consider piping through head/tail/grep to reduce context usage."
fi

exit 0
