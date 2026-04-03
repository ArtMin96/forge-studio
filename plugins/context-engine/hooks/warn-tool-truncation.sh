#!/usr/bin/env bash
# Context Guardian: Warn when tool output may be truncated.
# PostToolUse hooks receive JSON on stdin with tool_result field.

INPUT=$(cat)

# Extract the tool output text
OUTPUT=$(echo "$INPUT" | jq -r '.tool_result.output // empty' 2>/dev/null)

if [ -z "$OUTPUT" ]; then
  exit 0
fi

# Check output length (50K char truncation boundary)
OUTPUT_LEN=${#OUTPUT}
THRESHOLD=45000

if [ "$OUTPUT_LEN" -ge "$THRESHOLD" ]; then
  echo "Tool result may be truncated (${OUTPUT_LEN} chars, limit ~50K). Re-run with narrower scope if results seem incomplete."
fi

exit 0
