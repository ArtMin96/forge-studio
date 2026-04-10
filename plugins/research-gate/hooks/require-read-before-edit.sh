#!/usr/bin/env bash
# PreToolUse(Edit|Write): Block edits to files not read in this session.
# Uses JSON permissionDecision output for blocking.
#
# Logic:
#   Edit  → always requires prior Read (edits only target existing files)
#   Write → requires prior Read only if file already exists (new files pass)
#
# Disable: set FORGE_RESEARCH_GATE=0 in settings.json env

if [ "${FORGE_RESEARCH_GATE:-1}" = "0" ]; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Write to a new file — no prior Read needed
if [ "$TOOL_NAME" = "Write" ] && [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-research-gate}/${SESSION_ID}"
SAFE_NAME=$(echo "$FILE_PATH" | md5sum | cut -c1-16)

if [ -f "${TRACKDIR}/${SAFE_NAME}" ]; then
  # File was read in this session — allow
  exit 0
fi

# File was NOT read — block with JSON output
BASENAME=$(basename "$FILE_PATH")
jq -n --arg reason "You must Read ${BASENAME} before editing. Research the file first, understand its content, then retry your edit." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
