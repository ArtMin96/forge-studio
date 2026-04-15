#!/usr/bin/env bash
# PreToolUse(Edit|Write): Scope compliance check.
# Warns when editing files outside the active scope's file list.
# Non-blocking: provides additionalContext, does not deny.

INPUT=$(cat)
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$TARGET" ]]; then
  exit 0
fi

SCOPES_DIR=".claude/scopes"

if [[ ! -d "$SCOPES_DIR" ]]; then
  exit 0
fi

# Find the most recently modified .md file that is less than 2 hours old
recent_scope=$(find "$SCOPES_DIR" -maxdepth 1 -name '*.md' -mmin -120 -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn \
  | head -1 \
  | cut -d' ' -f2-)

if [[ -z "$recent_scope" ]]; then
  exit 0
fi

# Extract the task name from the first non-empty line, strip leading #s and spaces
task_name=$(grep -m 1 -v '^\s*$' "$recent_scope" 2>/dev/null | sed 's/^#*\s*//')

if [[ -z "$task_name" ]]; then
  exit 0
fi

# Extract lines between ## Files and next ## section
files_section=$(sed -n '/^##[[:space:]]*Files/,/^##/{/^##[[:space:]]*Files/d; /^##/d; p;}' "$recent_scope" 2>/dev/null)

# If there is no Files section, nothing to check — exit silently
if [[ -z "$files_section" ]]; then
  exit 0
fi

TARGET_BASENAME=$(basename "$TARGET")

# Check if the full path or basename appears anywhere in the Files section
if echo "$files_section" | grep -qF "$TARGET" || echo "$files_section" | grep -qF "$TARGET_BASENAME"; then
  exit 0
fi

# Target file is not in the Files section — emit additionalContext warning
jq -n --arg task "$task_name" --arg base "$TARGET_BASENAME" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: ("File " + $base + " is outside active scope '" + $task + "'. Acknowledge scope expansion if intended.")
  }
}'

exit 0
