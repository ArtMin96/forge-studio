#!/usr/bin/env bash
# Context Engine: Pre-compaction guard (v2.1.105+).
# Blocks compaction when critical context would be lost.
# Must run synchronously (async hooks cannot block).
#
# Blocks when:
#   1. State file is currently being written (race condition)
#   2. Uncommitted changes exist with no recent /progress-log entry (data loss risk)
#   3. Active plan has incomplete tasks (work in progress)
#
# Silent when safe (back-pressure principle).

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/pre-compact-state.md"
PROGRESS_FILE="claude-progress.txt"
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
    HAS_PROGRESS=false
    if [[ -f "$PROGRESS_FILE" ]] && find "$PROGRESS_FILE" -mmin -60 2>/dev/null | grep -q .; then
      HAS_PROGRESS=true
    fi
    if [[ "$HAS_PROGRESS" == "false" ]]; then
      block "Compaction blocked: ${DIRTY} uncommitted changes with no recent claude-progress.txt entry. Run /progress-log first to preserve context, then compact."
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
      block "Compaction blocked: active plan with ${INCOMPLETE} incomplete tasks. Complete current phase or /progress-log before compacting."
    fi
  fi
fi

# All clear — silent exit (back-pressure: success is silent)
exit 0
