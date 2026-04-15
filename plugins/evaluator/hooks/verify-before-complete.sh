#!/usr/bin/env bash
# Stop: Verify before claiming done. Fires when Claude finishes responding.
# Checks if edits were made without test/verification evidence.
# Shared state: reuses test-nudge edit counter and verified-since-edit flag.
#
# Exit 2 = block the stop (Claude continues). Stderr becomes Claude's feedback.
# Must check stop_hook_active to prevent infinite loops.

INPUT=$(cat)

# Guard: if this hook already triggered a continuation, let Claude stop
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-test-nudge}/${SESSION_ID}"
COUNTFILE="${TRACKDIR}/edit-count"

if [ ! -f "$COUNTFILE" ]; then
  exit 0
fi

COUNT=$(cat "$COUNTFILE")

if [ "$COUNT" -gt 0 ] && [ ! -f "${TRACKDIR}/verified-since-edit" ]; then
  echo "Changes made without verification. Run tests or demonstrate the fix works before claiming done." >&2
  exit 2
fi

exit 0
