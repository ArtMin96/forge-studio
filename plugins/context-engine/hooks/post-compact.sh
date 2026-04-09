#!/usr/bin/env bash
# Context Engine: Post-compaction context recovery.
# Re-injects essential pointers after compaction so the model
# can quickly restore working context.

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/pre-compact-state.md"
SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"

OUTPUT=""

# Only fire if pre-compact state was saved
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

OUTPUT+="[Post-Compaction Recovery]"$'\n'
OUTPUT+="Context was just compacted. Key pointers:"$'\n'

# Read and relay saved state
while IFS= read -r line; do
  case "$line" in
    "Active scope:"*) OUTPUT+="- ${line}"$'\n' ;;
    "Active plan:"*) OUTPUT+="- ${line}"$'\n' ;;
    "Latest handoff:"*) OUTPUT+="- ${line}"$'\n' ;;
    "Branch:"*) OUTPUT+="- Git ${line}"$'\n' ;;
    "Uncommitted changes:"*) OUTPUT+="- ${line}"$'\n' ;;
  esac
done < "$STATE_FILE"

# Restore active task list from task guardian
TASKFILE="${CLAUDE_PLUGIN_DATA:-/tmp/claude-task-guardian}/${SESSION_ID}/tasks.json"
if [[ -f "$TASKFILE" ]]; then
  INCOMPLETE=$(jq -r '[.[] | select(.status != "completed")] | length' "$TASKFILE" 2>/dev/null)
  if [[ "${INCOMPLETE:-0}" -gt 0 ]]; then
    TASKS=$(jq -r '[.[] | select(.status != "completed")] | .[] | "  - " + .subject' "$TASKFILE" 2>/dev/null)
    OUTPUT+="- Incomplete tasks (${INCOMPLETE}):"$'\n'
    OUTPUT+="${TASKS}"$'\n'
  fi
fi

# Restore files modified in session from traces
TRACE_DIR="${HOME}/.claude/traces"
SESSION_DATE=$(date +%Y-%m-%d)
DIR_HASH=$(echo "$(pwd)" | md5sum | cut -c1-8)
TRACE_FILE="${TRACE_DIR}/${SESSION_DATE}-${DIR_HASH}.jsonl"
if [[ -f "$TRACE_FILE" ]]; then
  MODIFIED=$(jq -r 'select(.type == "file") | .file_path' "$TRACE_FILE" 2>/dev/null | sort -u | tail -10)
  if [[ -n "$MODIFIED" ]]; then
    OUTPUT+="- Files modified this session:"$'\n'
    while IFS= read -r f; do
      OUTPUT+="  - ${f}"$'\n'
    done <<< "$MODIFIED"
  fi
fi

OUTPUT+="- Full state: ${STATE_FILE}"$'\n'
OUTPUT+="[/Post-Compaction Recovery]"

echo "$OUTPUT"
exit 0
