#!/usr/bin/env bash
# SubagentStop: nudge the next step in the planner → generator → reviewer → verify chain.
# Complements (does not duplicate) plugins/agents/hooks/contract-check.sh which already
# warns when the reviewer ignored the contract — we only cover the transitions between phases.
#
# Silent when agent_type is missing or unrecognized.

INPUT=$(cat 2>/dev/null || true)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)

if [ -z "$AGENT_TYPE" ]; then
  exit 0
fi

PLANS_DIR=".claude/plans"
HAS_ACTIVE_PLAN=0
if [ -d "$PLANS_DIR" ]; then
  if find "$PLANS_DIR" -maxdepth 1 -name '*.md' -mmin -180 2>/dev/null | grep -q .; then
    HAS_ACTIVE_PLAN=1
  fi
fi

case "$AGENT_TYPE" in
  planner|Plan)
    if [ "$HAS_ACTIVE_PLAN" = "1" ]; then
      echo "[workflow] Planner finished. Next: dispatch the generator. Ensure the plan has a ## Contract section before generating."
    fi
    ;;
  generator|agents:generator)
    if [ "$HAS_ACTIVE_PLAN" = "1" ]; then
      echo "[workflow] Generator finished. Next: dispatch the reviewer (read-only). Agent self-evaluation is unreliable."
    fi
    ;;
  reviewer|agents:reviewer|evaluator:adversarial-reviewer)
    echo "[workflow] Reviewer finished. Before claiming done: run /verify (evaluator plugin) with evidence — commands, outputs, diffs."
    ;;
esac

exit 0
