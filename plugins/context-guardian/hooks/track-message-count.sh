#!/usr/bin/env bash
# Context Guardian: Track message count per session.
# Uses CLAUDE_SESSION_ID if available, falls back to a stable identifier.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
COUNTFILE="/tmp/claude-msgcount-${SESSION_ID}"

if [[ -f "$COUNTFILE" ]]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

if [[ $COUNT -eq 25 ]]; then
  echo "Context check: 25 messages in. Consider: /compact, /handoff, or start fresh."
elif [[ $COUNT -eq 40 ]]; then
  echo "Context warning: 40 messages. Quality is likely degrading. Strongly recommend /handoff and fresh session."
elif [[ $COUNT -eq 50 ]]; then
  echo "Context critical: 50 messages. You should /handoff NOW and start a fresh session."
fi

exit 0
