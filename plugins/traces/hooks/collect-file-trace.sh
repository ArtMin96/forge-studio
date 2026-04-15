#!/usr/bin/env bash
# Traces: Collect file modification traces.
# Logs file path and change type for Write/Edit tool uses.

# Skip if traces disabled
[[ "${FORGE_TRACES_ENABLED:-1}" == "0" ]] && exit 0

TRACE_DIR="${HOME}/.claude/traces"
mkdir -p "$TRACE_DIR"

SESSION_DATE=$(date +%Y-%m-%d)
DIR_HASH=$(echo "$(pwd)" | md5sum | cut -c1-8)
TRACE_FILE="${TRACE_DIR}/${SESSION_DATE}-${DIR_HASH}.jsonl"

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg type "file" \
  --arg tool "$TOOL_NAME" \
  --arg path "$FILE_PATH" \
  --arg cwd "$(pwd)" \
  '{timestamp: $ts, type: $type, tool: $tool, file_path: $path, cwd: $cwd}' \
  >> "$TRACE_FILE" 2>/dev/null

exit 0
