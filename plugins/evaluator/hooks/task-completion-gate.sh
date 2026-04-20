#!/usr/bin/env bash
# TaskCompleted: Verify before marking task done.
# Checks if edits were made without test/verification evidence.
# Shared state: reuses test-nudge edit counter and verified-since-edit flag.
#
# Exit 1 = warn (non-blocking). Stderr becomes Claude's feedback.
# Spec: HARNESS_SPEC.md forbids exit 2 outside PreToolUse/PreCompact.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-test-nudge}/${SESSION_ID}"
COUNTFILE="${TRACKDIR}/edit-count"

if [ ! -f "$COUNTFILE" ]; then
  exit 0
fi

COUNT=$(cat "$COUNTFILE")

if [ "$COUNT" -gt 0 ] && [ ! -f "${TRACKDIR}/verified-since-edit" ]; then
  echo "Task marked complete without verification evidence. Run tests or /verify." >&2
  exit 1
fi

exit 0
