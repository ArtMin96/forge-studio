#!/usr/bin/env bash
# Pre-commit: Test reminder + evaluation gate.
# Reminds about tests, warns when committing planned work without /verify.
# Exit 1 = warn (non-blocking). Set FORGE_EVALUATION_GATE=0 to disable the gate check.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only trigger on git commit commands
if ! echo "$COMMAND" | grep -qE '^git\s+commit'; then
  exit 0
fi

# Check evaluation gate (if not disabled)
# Plans may live project-local (.claude/plans/, used by /contract /dispatch /feature-list
# /after-subagent.sh) or user-scope (~/.claude/plans/, Claude Code plan-mode default).
# Prefer project-local when present so per-repo plans take precedence.
if [ "${FORGE_EVALUATION_GATE:-1}" != "0" ]; then
  if [ -d ".claude/plans" ] && ls .claude/plans/*.md >/dev/null 2>&1; then
    PLAN_DIR=".claude/plans"
  else
    PLAN_DIR="${HOME}/.claude/plans"
  fi
  if [ -d "$PLAN_DIR" ]; then
    LATEST_PLAN=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)
    if [ -n "$LATEST_PLAN" ]; then
      PLAN_NAME=$(basename "$LATEST_PLAN" .md)

      # Check if plan is recent (modified within last 24 hours)
      if [ "$(uname)" = "Darwin" ]; then
        PLAN_AGE=$(( $(date +%s) - $(stat -f %m "$LATEST_PLAN") ))
      else
        PLAN_AGE=$(( $(date +%s) - $(stat -c %Y "$LATEST_PLAN") ))
      fi

      # Only gate on plans modified within last 24 hours (86400 seconds)
      if [ "$PLAN_AGE" -le 86400 ]; then
        GATE_FILE="${HOME}/.claude/evaluation-gate.flag"
        CLEARED=""
        if [ -f "$GATE_FILE" ]; then
          CLEARED=$(cat "$GATE_FILE" 2>/dev/null)
        fi

        if [ "$CLEARED" != "$PLAN_NAME" ]; then
          echo "Pre-commit: Active plan '${PLAN_NAME}' — /verify not run. Have you run tests? Consider /verify or /healthcheck before committing."
          exit 1
        fi
      fi
    fi
  fi
fi

# No active plan or gate cleared/disabled — gentle reminder
echo "Pre-commit reminder: Have you run tests? Consider /healthcheck before committing."
exit 0
