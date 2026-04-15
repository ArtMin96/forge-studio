#!/usr/bin/env bash
# PostToolUse: Reset consecutive failure counter on successful tool use.
# Companion to consecutive-failure-guard.sh (PostToolUseFailure).

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
COUNTFILE="${CLAUDE_PLUGIN_DATA:-/tmp/claude-failure-guard}/${SESSION_ID}/consecutive-failures"

# Only reset if counter exists and is non-zero
if [ -f "$COUNTFILE" ] && [ "$(cat "$COUNTFILE")" -gt 0 ] 2>/dev/null; then
  echo "0" > "$COUNTFILE"
fi

exit 0
