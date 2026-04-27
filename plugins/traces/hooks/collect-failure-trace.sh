#!/usr/bin/env bash
# Traces: Collect tool failure traces.
# Logs tool name, input, error message, and whether it was a user interrupt.

[[ "${FORGE_TRACES_ENABLED:-1}" == "0" ]] && exit 0

TRACE_DIR="${HOME}/.claude/traces"
mkdir -p "$TRACE_DIR"

SESSION_DATE=$(date +%Y-%m-%d)
DIR_HASH=$(echo "$(pwd)" | md5sum | cut -c1-8)
TRACE_FILE="${TRACE_DIR}/${SESSION_DATE}-${DIR_HASH}.jsonl"

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
ERROR=$(echo "$INPUT" | jq -r '.error // empty' 2>/dev/null | head -c 500)
IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false' 2>/dev/null)
DURATION_MS=$(echo "$INPUT" | jq -r '.duration_ms // "null"' 2>/dev/null)
[[ -z "$DURATION_MS" ]] && DURATION_MS="null"

if [[ -z "$TOOL_NAME" ]]; then
  exit 0
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg type "tool_failure" \
  --arg tool "$TOOL_NAME" \
  --arg error "$ERROR" \
  --arg interrupt "$IS_INTERRUPT" \
  --arg cwd "$(pwd)" \
  --argjson dur "$DURATION_MS" \
  '{timestamp: $ts, type: $type, tool: $tool, error: $error, is_interrupt: $interrupt, cwd: $cwd, duration_ms: $dur}' \
  >> "$TRACE_FILE" 2>/dev/null

exit 0
