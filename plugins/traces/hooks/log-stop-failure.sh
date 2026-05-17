#!/usr/bin/env bash
# Traces: Log session stop failures (rate limits, API errors).
# Helps diagnose reliability issues across sessions.
set -euo pipefail

[[ "${FORGE_TRACES_ENABLED:-1}" == "0" ]] && exit 0

TRACE_DIR="${HOME}/.claude/traces"
mkdir -p "$TRACE_DIR"

SESSION_DATE=$(date +%Y-%m-%d)
DIR_HASH=$(echo "$(pwd)" | md5sum | cut -c1-8)
TRACE_FILE="${TRACE_DIR}/${SESSION_DATE}-${DIR_HASH}.jsonl"

INPUT=$(cat)

ERROR_TYPE=$(echo "$INPUT" | jq -r '.error_type // empty' 2>/dev/null)

if [[ -z "$ERROR_TYPE" ]]; then
  exit 0
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TURN_ID=$(printf '%s' "$INPUT" | bash plugins/_lib/turn-id.sh --from-stdin 2>/dev/null || true)
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg type "stop_failure" \
  --arg error_type "$ERROR_TYPE" \
  --arg cwd "$(pwd)" \
  --arg turn_id "$TURN_ID" \
  '{timestamp: $ts, type: $type, error_type: $error_type, cwd: $cwd, turn_id: $turn_id}' \
  >> "$TRACE_FILE" 2>/dev/null

exit 0
