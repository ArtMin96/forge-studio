#!/usr/bin/env bash
# PostToolUseFailure: Track consecutive tool failures and escalate.
# After 3 consecutive failures, inject warning to break retry loops.
# Reset on PostToolUse success (tracked separately).
# Rationale (12-Factor Agent, HumanLayer, 2026): Agents with 50+ turns
# commonly lose focus and repeat failed approaches.

INPUT=$(cat)

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-failure-guard}/${SESSION_ID}"
mkdir -p "$TRACKDIR"

COUNTFILE="${TRACKDIR}/consecutive-failures"

if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

THRESHOLD="${FORGE_FAILURE_THRESHOLD:-3}"

if [ "$COUNT" -ge "$THRESHOLD" ]; then
  TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
  echo "${COUNT} consecutive tool failures (last: ${TOOL}). Stop. Re-read the error output. What assumption is wrong? Consider a different approach."
fi

exit 0
