#!/usr/bin/env bash
# Context Engine: Pre-compaction guard (v2.1.105+).
# Blocks compaction when critical context would be lost.
# Must run synchronously (async hooks cannot block).
#
# Blocks when:
#   1. State file is currently being written (race condition)
#   2. Uncommitted changes exist with no handoff (data loss risk)
#   3. Active plan has incomplete tasks (work in progress)
#
# Silent when safe (back-pressure principle).

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/pre-compact-state.md"
HANDOFF_DIR="${STATE_DIR}/handoffs"
PLAN_DIR="${STATE_DIR}/plans"

block() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    decision: "block",
    reason: $reason
  }'
  exit 0
}

# Check 1: State file being written (lock file present from async pre-compact.sh)
LOCK_FILE="${STATE_FILE}.lock"
if [[ -f "$LOCK_FILE" ]]; then
  block "Context state file is currently being saved. Retry compaction in a few seconds."
fi

# Check 2: Uncommitted changes with no recent handoff
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "${DIRTY:-0}" -gt 5 ]]; then
    HAS_HANDOFF=false
    if [[ -d "$HANDOFF_DIR" ]]; then
      LATEST_HANDOFF=$(find "$HANDOFF_DIR" -maxdepth 1 -name '*.md' -mmin -60 2>/dev/null | head -1)
      [[ -n "$LATEST_HANDOFF" ]] && HAS_HANDOFF=true
    fi
    if [[ "$HAS_HANDOFF" == "false" ]]; then
      block "Compaction blocked: ${DIRTY} uncommitted changes with no recent handoff. Run /handoff first to preserve context, then compact."
    fi
  fi
fi

# Check 3: Active plan with incomplete tasks
SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TASKFILE="${CLAUDE_PLUGIN_DATA:-/tmp/claude-task-guardian}/${SESSION_ID}/tasks.json"
if [[ -d "$PLAN_DIR" ]] && [[ -f "$TASKFILE" ]]; then
  LATEST_PLAN=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)
  if [[ -n "$LATEST_PLAN" ]]; then
    INCOMPLETE=$(jq -r '[.[] | select(.status != "completed")] | length' "$TASKFILE" 2>/dev/null)
    if [[ "${INCOMPLETE:-0}" -gt 3 ]]; then
      block "Compaction blocked: active plan with ${INCOMPLETE} incomplete tasks. Complete current phase or /handoff before compacting."
    fi
  fi
fi

# All clear — silent exit (back-pressure: success is silent)
exit 0
