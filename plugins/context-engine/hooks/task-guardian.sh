#!/usr/bin/env bash
# UserPromptSubmit: Remind about incomplete tasks.
# Reads task state logged by TaskCreated events.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TASKFILE="${CLAUDE_PLUGIN_DATA:-/tmp/claude-task-guardian}/${SESSION_ID}/tasks.json"

if [ ! -f "$TASKFILE" ]; then
  exit 0
fi

# Count incomplete tasks
INCOMPLETE=$(jq -r '[.[] | select(.status != "completed")] | length' "$TASKFILE" 2>/dev/null)
CURRENT=$(jq -r '[.[] | select(.status == "in_progress")][0].subject // empty' "$TASKFILE" 2>/dev/null)

if [ "${INCOMPLETE:-0}" -gt 0 ]; then
  MSG="You have ${INCOMPLETE} incomplete task(s)."
  if [ -n "$CURRENT" ]; then
    MSG="${MSG} Current: ${CURRENT}"
  fi
  echo "$MSG"
fi

exit 0
