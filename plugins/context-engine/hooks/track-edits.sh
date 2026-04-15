#!/usr/bin/env bash
# Edit Safety: Track edits per file. Warn after 3 edits without a re-read.
# Triggers on PostToolUse for Edit and Read.
# - Edit: increment counter for that file
# - Read: reset counter for that file

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-edits}/${SESSION_ID}"
mkdir -p "$TRACKDIR"

# Sanitize file path for use as filename
SAFE_NAME=$(echo "$FILE_PATH" | md5sum | cut -c1-16)

if [ "$TOOL_NAME" = "Read" ]; then
  # Reset counter on Read
  rm -f "${TRACKDIR}/${SAFE_NAME}"
  exit 0
fi

# Must be Edit — increment counter
if [ -f "${TRACKDIR}/${SAFE_NAME}" ]; then
  COUNT=$(cat "${TRACKDIR}/${SAFE_NAME}")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "${TRACKDIR}/${SAFE_NAME}"

if [ "$COUNT" -ge 3 ]; then
  BASENAME=$(basename "$FILE_PATH")
  echo "Edit safety: ${COUNT} edits to ${BASENAME} without re-reading. Re-read to verify current file state."
fi

exit 0
