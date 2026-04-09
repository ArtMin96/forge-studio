#!/usr/bin/env bash
# TaskCreated: Log task creation for the task guardian.

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.tool_input.subject // empty' 2>/dev/null)
TASK_ID=$(echo "$INPUT" | jq -r '.tool_result.id // .tool_result.taskId // empty' 2>/dev/null)

if [ -z "$TASK_SUBJECT" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TASKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-task-guardian}/${SESSION_ID}"
mkdir -p "$TASKDIR"
TASKFILE="${TASKDIR}/tasks.json"

# Initialize if needed
if [ ! -f "$TASKFILE" ]; then
  echo "[]" > "$TASKFILE"
fi

# Append task
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg id "${TASK_ID:-unknown}" \
   --arg subject "$TASK_SUBJECT" \
   --arg ts "$TIMESTAMP" \
   --arg status "pending" \
   '. += [{"id": $id, "subject": $subject, "created": $ts, "status": $status}]' \
   "$TASKFILE" > "${TASKFILE}.tmp" 2>/dev/null && mv "${TASKFILE}.tmp" "$TASKFILE"

exit 0
