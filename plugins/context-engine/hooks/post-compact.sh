#!/usr/bin/env bash
# Context Engine: Post-compaction context recovery.
# Re-injects essential pointers after compaction so the model
# can quickly restore working context.

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/pre-compact-state.md"

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

OUTPUT+="- Full state: ${STATE_FILE}"$'\n'
OUTPUT+="[/Post-Compaction Recovery]"

echo "$OUTPUT"
exit 0
