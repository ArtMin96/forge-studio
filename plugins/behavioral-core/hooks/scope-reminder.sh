#!/usr/bin/env bash
# Focus Mode: Scope reminder injected before every tool use.
# Reads the most recent scope file and reminds Claude of active boundaries.

SCOPES_DIR=".claude/scopes"

# Exit silently if no scopes directory
if [[ ! -d "$SCOPES_DIR" ]]; then
  exit 0
fi

# Find the most recently modified .md file that is less than 2 hours old
recent_scope=$(find "$SCOPES_DIR" -maxdepth 1 -name '*.md' -mmin -120 -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn \
  | head -1 \
  | cut -d' ' -f2-)

# Exit silently if no recent scope found
if [[ -z "$recent_scope" ]]; then
  exit 0
fi

# Extract the first non-empty line as the task name
task_name=$(grep -m 1 -v '^\s*$' "$recent_scope" 2>/dev/null | sed 's/^#*\s*//')

if [[ -z "$task_name" ]]; then
  exit 0
fi

# Extract the Boundaries section content
boundaries=$(sed -n '/^##.*Boundaries/,/^##/{ /^##.*Boundaries/d; /^##/d; p; }' "$recent_scope" 2>/dev/null \
  | sed '/^\s*$/d' \
  | head -5)

if [[ -n "$boundaries" ]]; then
  echo "Active scope: ${task_name}. Stay within boundaries."
  echo "Boundaries: ${boundaries}"
else
  echo "Active scope: ${task_name}. Stay within boundaries."
fi

exit 0
