#!/usr/bin/env bash
# PostToolUse(Edit): Detect edit thrashing patterns.
# Warns when same file edited 5+ times or same region edited 3+ times.
# Different from track-edits.sh which tracks edits-without-re-reading.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ] || [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-thrashing}/${SESSION_ID}"
mkdir -p "$TRACKDIR"

SAFE_NAME=$(echo "$FILE_PATH" | md5sum | cut -c1-16)
COUNTFILE="${TRACKDIR}/${SAFE_NAME}.count"
REGIONFILE="${TRACKDIR}/${SAFE_NAME}.regions"

# Track per-file edit count
if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

# Track edited line regions (old_string first line as proxy)
LINE_HINT=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null | head -1 | md5sum | cut -c1-8)
if [ -n "$LINE_HINT" ]; then
  echo "$LINE_HINT" >> "$REGIONFILE"
  # Check for region oscillation (same region 3+ times)
  if [ -f "$REGIONFILE" ]; then
    REGION_HITS=$(grep -c "^${LINE_HINT}$" "$REGIONFILE" 2>/dev/null)
    if [ "$REGION_HITS" -ge 3 ]; then
      BASENAME=$(basename "$FILE_PATH")
      echo "Oscillating on ${BASENAME} — same region edited ${REGION_HITS} times. Stop. Re-read the whole function. What's the actual requirement?"
      exit 0
    fi
  fi
fi

# Check total edit count
if [ "$COUNT" -ge 5 ]; then
  BASENAME=$(basename "$FILE_PATH")
  echo "Thrashing detected on ${BASENAME} — ${COUNT} edits this session. Step back, re-read the full file, and reconsider approach."
fi

exit 0
