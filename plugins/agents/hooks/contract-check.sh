#!/usr/bin/env bash
set -euo pipefail
# SubagentStop: Check if sprint contract was verified when using pipeline.
# Warns if a planner-created contract exists but the reviewer hasn't validated it.
# Silent when no contract exists (non-pipeline usage).

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)

# Only check when reviewer agent stops (accepts any agent_type containing "review")
case "$AGENT_TYPE" in
  *review*) ;;
  *) exit 0 ;;
esac

# Check for active plan with contract section
PLANS_DIR=".claude/plans"
if [ ! -d "$PLANS_DIR" ]; then
  exit 0
fi

LATEST_PLAN=$(bash "${CLAUDE_PLUGIN_ROOT}/workflow-orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)

if [ -z "$LATEST_PLAN" ]; then
  exit 0
fi

# Check if plan has a Contract section
if grep -q "^## Contract" "$LATEST_PLAN" 2>/dev/null; then
  # Check if reviewer output mentions contract compliance
  RESULT=$(echo "$INPUT" | jq -r '.tool_result.stdout // empty' 2>/dev/null)
  if [ -n "$RESULT" ] && echo "$RESULT" | grep -qi "contract"; then
    exit 0
  fi
  echo "[agents] Sprint contract exists in $(basename "$LATEST_PLAN") but reviewer output doesn't mention contract compliance. Verify contract criteria were checked."
fi

exit 0
