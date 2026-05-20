#!/usr/bin/env bash
# Context Engine: Post-edit belief snapshot.
# Records sha256 of disk content after each Edit/Write.
# The post entry becomes the new baseline for future /belief-audit calls.
# Registered as PostToolUse Edit|Write — observability only (exit 0 always).

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || true)
AGENT="${CLAUDE_AGENT_NAME:-main}"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

STATE_DIR="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/state"
mkdir -p "$STATE_DIR"

SHA=$(sha256sum -- "$FILE_PATH" 2>/dev/null | awk '{print $1}' || true)
if [ -z "$SHA" ]; then
  exit 0
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

jq -cn \
  --arg ts "$TS" --arg path "$FILE_PATH" --arg sha "$SHA" \
  --arg agent "$AGENT" --arg session "$SESSION_ID" \
  '{ts:$ts,path:$path,sha256:$sha,agent:$agent,op:"post",session_id:$session}' \
  >> "${STATE_DIR}/belief.jsonl"

exit 0
