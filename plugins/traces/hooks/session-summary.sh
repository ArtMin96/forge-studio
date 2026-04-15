#!/usr/bin/env bash
# Traces: Write session summary at session end.
# Aggregates trace entries into a readable summary.

# Skip if traces disabled
[[ "${FORGE_TRACES_ENABLED:-1}" == "0" ]] && exit 0

TRACE_DIR="${HOME}/.claude/traces"
mkdir -p "$TRACE_DIR"

SESSION_DATE=$(date +%Y-%m-%d)
DIR_HASH=$(echo "$(pwd)" | md5sum | cut -c1-8)
TRACE_FILE="${TRACE_DIR}/${SESSION_DATE}-${DIR_HASH}.jsonl"

if [[ ! -f "$TRACE_FILE" ]]; then
  exit 0
fi

# Count entries by type
BASH_COUNT=$(grep -c '"type":"bash"' "$TRACE_FILE" 2>/dev/null || echo 0)
FILE_COUNT=$(grep -c '"type":"file"' "$TRACE_FILE" 2>/dev/null || echo 0)
ERROR_COUNT=$(grep '"type":"bash"' "$TRACE_FILE" 2>/dev/null | grep -v '"exit_code":"0"' | wc -l | tr -d ' ')

# Get unique files modified
FILES_MODIFIED=$(grep '"type":"file"' "$TRACE_FILE" 2>/dev/null | jq -r '.file_path' 2>/dev/null | sort -u | wc -l | tr -d ' ')

# Write summary entry
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg type "session_end" \
  --arg bash_count "$BASH_COUNT" \
  --arg file_count "$FILE_COUNT" \
  --arg error_count "$ERROR_COUNT" \
  --arg files_modified "$FILES_MODIFIED" \
  --arg cwd "$(pwd)" \
  '{timestamp: $ts, type: $type, bash_commands: ($bash_count|tonumber), file_operations: ($file_count|tonumber), errors: ($error_count|tonumber), unique_files_modified: ($files_modified|tonumber), cwd: $cwd}' \
  >> "$TRACE_FILE" 2>/dev/null

exit 0
