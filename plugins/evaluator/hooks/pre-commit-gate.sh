#!/usr/bin/env bash
# Evaluation Gate: Warn when committing planned work without running /verify.
# Exit 1 = warn (non-blocking). Set FORGE_EVALUATION_GATE=0 to disable.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only trigger on git commit commands
if ! echo "$COMMAND" | grep -qE '^git\s+commit'; then
  exit 0
fi

# Check if gate is disabled
if [ "${FORGE_EVALUATION_GATE:-1}" = "0" ]; then
  exit 0
fi

# Find the most recent plan file
PLAN_DIR="${HOME}/.claude/plans"
if [ ! -d "$PLAN_DIR" ]; then
  exit 0
fi

LATEST_PLAN=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)
if [ -z "$LATEST_PLAN" ]; then
  exit 0
fi

PLAN_NAME=$(basename "$LATEST_PLAN" .md)

# Check if plan is recent (modified within last 24 hours)
if [ "$(uname)" = "Darwin" ]; then
  PLAN_AGE=$(( $(date +%s) - $(stat -f %m "$LATEST_PLAN") ))
else
  PLAN_AGE=$(( $(date +%s) - $(stat -c %Y "$LATEST_PLAN") ))
fi

# Only gate on plans modified within last 24 hours (86400 seconds)
if [ "$PLAN_AGE" -gt 86400 ]; then
  exit 0
fi

# Check if gate has been cleared for this plan
GATE_FILE="${HOME}/.claude/evaluation-gate.flag"
if [ -f "$GATE_FILE" ]; then
  CLEARED_PLAN=$(cat "$GATE_FILE" 2>/dev/null)
  if [ "$CLEARED_PLAN" = "$PLAN_NAME" ]; then
    exit 0
  fi
fi

# Gate not cleared — warn
echo "Evaluation gate: Active plan '${PLAN_NAME}' detected but /verify not run. Consider /verify before committing."
exit 1
