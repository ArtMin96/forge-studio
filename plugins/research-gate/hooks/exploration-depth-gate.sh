#!/usr/bin/env bash
# PreToolUse(Edit|Write): Warn if editing before sufficient exploration.
# IDE-Bench: 8+ exploratory calls before first edit = 8.7x success rate.
# Non-blocking (JSON additionalContext warning). Read-before-edit remains the hard block.
# Disables after first edit passes (only initial exploration matters).
# Configurable threshold via FORGE_EXPLORE_DEPTH (default 6).

if [ "${FORGE_RESEARCH_GATE:-1}" = "0" ]; then
  exit 0
fi

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
DEPTHDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-research-gate}/${SESSION_ID}"

# Check if gate already passed (first edit completed)
GATEFILE="${DEPTHDIR}/depth-gate-passed"
if [ -f "$GATEFILE" ]; then
  exit 0
fi

# Write to a new file — skip gate check (matches require-read-before-edit logic)
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ "$TOOL_NAME" = "Write" ] && [ -n "$FILE_PATH" ] && [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Read exploration count
COUNTFILE="${DEPTHDIR}/explore-count"
if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi

THRESHOLD="${FORGE_EXPLORE_DEPTH:-6}"

if [ "$COUNT" -lt "$THRESHOLD" ]; then
  # Warn via JSON additionalContext (injected into Claude's context)
  jq -n --arg ctx "Only ${COUNT}/${THRESHOLD} exploratory calls before first edit. Low exploration depth is the largest driver of premature-edit failures. Consider reading more files before editing." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      additionalContext: $ctx
    }
  }'
  # Mark gate as passed (warn once, don't nag)
  mkdir -p "$DEPTHDIR"
  touch "$GATEFILE"
  exit 0
fi

# Sufficient exploration — mark gate as passed
mkdir -p "$DEPTHDIR"
touch "$GATEFILE"
exit 0
