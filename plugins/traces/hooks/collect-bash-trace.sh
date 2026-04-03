#!/usr/bin/env bash
# Traces: Collect Bash tool execution traces.
# Logs command, exit code, and truncated output to session trace file.
# Inspired by Meta-Harness: proposer reads 40% execution traces per iteration.

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

# Extract command and output from hook payload
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exitCode // .tool_response.exit_code // "0"' 2>/dev/null)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // .tool_response // empty' 2>/dev/null | head -c 500)

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Append trace entry as JSONL
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg type "bash" \
  --arg cmd "$COMMAND" \
  --arg exit "$EXIT_CODE" \
  --arg out "$OUTPUT" \
  --arg cwd "$(pwd)" \
  '{timestamp: $ts, type: $type, command: $cmd, exit_code: $exit, output_preview: $out, cwd: $cwd}' \
  >> "$TRACE_FILE" 2>/dev/null

exit 0
