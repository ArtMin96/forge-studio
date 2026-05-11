#!/usr/bin/env bash
# Traces: Collect user prompt turn events.
# Logs prompt length, session ID, and timestamp to session trace file.
# Prompt content is intentionally not stored — length only.
# The trace file may be shared with /trace-review agents outside the machine;
# storing content would create a privacy risk.

# Skip if traces disabled
[[ "${FORGE_TRACES_ENABLED:-1}" == "0" ]] && exit 0

TRACE_DIR="${HOME}/.claude/traces"
mkdir -p "$TRACE_DIR"

# Session trace file — one per day per working directory
SESSION_DATE=$(date +%Y-%m-%d)
DIR_HASH=$(echo "$(pwd)" | md5sum | cut -c1-8)
TRACE_FILE="${TRACE_DIR}/${SESSION_DATE}-${DIR_HASH}.jsonl"

# Read tool input from stdin (hook receives JSON)
INPUT=$(cat)

# Extract prompt length and session ID — never the prompt content
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
PROMPT_LENGTH=${#PROMPT}
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# Append trace entry as JSONL
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg type "user_turn" \
  --argjson len "$PROMPT_LENGTH" \
  --arg sid "$SESSION_ID" \
  --arg cwd "$(pwd)" \
  '{timestamp: $ts, type: $type, prompt_length: $len, session_id: $sid, cwd: $cwd}' \
  >> "$TRACE_FILE" 2>/dev/null

exit 0
