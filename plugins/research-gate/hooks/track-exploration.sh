#!/usr/bin/env bash
# PostToolUse(Read|Grep|Glob): Track exploratory tool calls.
# Increments counter used by exploration-depth-gate.sh.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
DEPTHDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-research-gate}/${SESSION_ID}"
mkdir -p "$DEPTHDIR"

COUNTFILE="${DEPTHDIR}/explore-count"

if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

exit 0
