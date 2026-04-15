#!/usr/bin/env bash
# Behavioral Core: Periodic self-review nudge after code writes.
# Fires every Nth edit (default 3) instead of every single one.
# Opus 4.6 overtriggers on per-edit nudges — interval reduces over-caution.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-self-review}/${SESSION_ID}"
mkdir -p "$TRACKDIR"

COUNTFILE="${TRACKDIR}/edit-count"

if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

INTERVAL="${FORGE_SELF_REVIEW_INTERVAL:-3}"

if [ $((COUNT % INTERVAL)) -eq 0 ] && [ "$COUNT" -gt 0 ]; then
  echo "Self-check: Does this change do ONLY what was asked? Anything added that wasn't requested?"
fi

exit 0
