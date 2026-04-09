#!/usr/bin/env bash
# Behavioral Core: After every code write, nudge self-review.
# Lightweight reminder — costs minimal tokens.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

echo "Self-check: Does this change do ONLY what was asked? Anything added that wasn't requested?"
exit 0
