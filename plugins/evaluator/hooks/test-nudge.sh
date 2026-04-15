#!/usr/bin/env bash
# PostToolUse(Edit|Write): Nudge to run tests after N edits.
# IDE-Bench: only 8% of post-edit transitions go to testing.
# Configurable via FORGE_TEST_NUDGE_INTERVAL (default 3).

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-test-nudge}/${SESSION_ID}"
mkdir -p "$TRACKDIR"

COUNTFILE="${TRACKDIR}/edit-count"

# Increment on Edit/Write
if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"
# Clear verification flag on new edit
rm -f "${TRACKDIR}/verified-since-edit" 2>/dev/null

INTERVAL="${FORGE_TEST_NUDGE_INTERVAL:-3}"
ESCALATION=$((INTERVAL * 2))

if [ $((COUNT % ESCALATION)) -eq 0 ] && [ "$COUNT" -gt 0 ]; then
  # Escalated: JSON additionalContext for stronger model attention
  jq -n --arg msg "${COUNT} edits without testing. Run tests before continuing — regression risk compounds with untested edits." '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $msg
    }
  }'
elif [ $((COUNT % INTERVAL)) -eq 0 ] && [ "$COUNT" -gt 0 ]; then
  echo "${COUNT} edits since last test run. Run tests now to catch regressions."
fi

exit 0
