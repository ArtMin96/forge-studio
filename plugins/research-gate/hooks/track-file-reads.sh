#!/usr/bin/env bash
# PostToolUse(Read): Record file reads for the research gate.
# State: /tmp/claude-research-gate-${SESSION_ID}/<md5hash>

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="/tmp/claude-research-gate-${SESSION_ID}"
mkdir -p "$TRACKDIR"

SAFE_NAME=$(echo "$FILE_PATH" | md5sum | cut -c1-16)
date +%s > "${TRACKDIR}/${SAFE_NAME}"

exit 0
