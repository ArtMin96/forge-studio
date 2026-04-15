#!/usr/bin/env bash
# PreToolUse(Read): Warn when the same file is read more than once in a session.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="/tmp/claude-reads-${SESSION_ID}"
mkdir -p "$TRACKDIR"

SAFE_NAME=$(echo "$FILE_PATH" | md5sum | cut -c1-16)
RECORD="${TRACKDIR}/${SAFE_NAME}"

if [ -f "$RECORD" ]; then
  FIRST_READ=$(cat "$RECORD")
  NOW=$(date +%s)
  AGE_MIN=$(( (NOW - FIRST_READ) / 60 ))
  BASENAME=$(basename "$FILE_PATH")
  echo "Duplicate read: ${BASENAME}. Already read ${AGE_MIN}m ago — content may still be in context."
else
  date +%s > "$RECORD"
fi

exit 0
