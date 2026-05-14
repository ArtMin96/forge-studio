#!/usr/bin/env bash
set -euo pipefail
# UserPromptSubmit: graduated context-budget advisory based on
# CLAUDE_CONTEXT_WINDOW_USED_PCT. Fires every prompt; silent until 70%.
#
# Advisory only — Claude Code hooks cannot mutate conversation history.
# Per Terminal-Agents 2603.05344 p.25, the *signal architecture* is the value;
# the offload/prune/summarize actions are driven by the model's response to the
# signal in the next turn, not by this script directly.
#
# Four stages (env-overridable thresholds):
#   FORGE_BUDGET_WARN_PCT      (default 70) — capacity check, checkpoint suggestion
#   FORGE_BUDGET_OFFLOAD_PCT   (default 80) — stale tool output offload advisory
#   FORGE_BUDGET_PRUNE_PCT     (default 90) — aggressive prune advisory
#   FORGE_BUDGET_EMERGENCY_PCT (default 99) — compaction imminent
#
# Dedup: same stage within a session emits once. FORGE_REMINDER_FORCE=1 bypasses.

# Consume stdin (required by hook contract) — we don't need payload content.
cat > /dev/null

# No env var → nothing to act on.
PCT="${CLAUDE_CONTEXT_WINDOW_USED_PCT:-}"
if [ -z "$PCT" ]; then
  exit 0
fi

# Thresholds (all env-overridable).
WARN_PCT="${FORGE_BUDGET_WARN_PCT:-70}"
OFFLOAD_PCT="${FORGE_BUDGET_OFFLOAD_PCT:-80}"
PRUNE_PCT="${FORGE_BUDGET_PRUNE_PCT:-90}"
EMERGENCY_PCT="${FORGE_BUDGET_EMERGENCY_PCT:-99}"

# Determine the highest applicable stage (emit only the top one).
STAGE=""
if [ "$PCT" -ge "$EMERGENCY_PCT" ]; then
  STAGE="emergency"
elif [ "$PCT" -ge "$PRUNE_PCT" ]; then
  STAGE="prune"
elif [ "$PCT" -ge "$OFFLOAD_PCT" ]; then
  STAGE="offload"
elif [ "$PCT" -ge "$WARN_PCT" ]; then
  STAGE="warn"
fi

# Below all thresholds → silent.
if [ -z "$STAGE" ]; then
  exit 0
fi

# Dedup: track last-emitted stage per session. Same stage twice → silent.
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
REMINDERS_DIR=".claude/state/reminders"
mkdir -p "$REMINDERS_DIR" 2>/dev/null || true
STATE_FILE="$REMINDERS_DIR/budget-${SESSION_ID}"

LAST_STAGE=""
if [ -f "$STATE_FILE" ]; then
  LAST_STAGE=$(cat "$STATE_FILE" 2>/dev/null || true)
fi

if [ "$LAST_STAGE" = "$STAGE" ] && [ "${FORGE_REMINDER_FORCE:-0}" != "1" ]; then
  exit 0
fi

# Emit the advisory for the highest active stage.
case "$STAGE" in
  warn)
    printf '[long-session budget] context at %s%% — capacity check. Run /progress-log if you want a durable checkpoint.\n' "$PCT"
    ;;
  offload)
    printf '[long-session budget] context at %s%% — old tool outputs are candidates for offload. Consider replacing large Read/Grep outputs older than the last 5 turns with brief references; commit a /progress-log entry to persist net state.\n' "$PCT"
    ;;
  prune)
    printf '[long-session budget] context at %s%% — prune-and-summarize zone. Beyond the last 10 turns, keep only sticky decisions. Run /progress-log NOW.\n' "$PCT"
    ;;
  emergency)
    printf '[long-session budget] context at %s%% — EMERGENCY. Compaction imminent; run /progress-log before it fires to preserve state.\n' "$PCT"
    ;;
esac

printf '%s' "$STAGE" > "$STATE_FILE"

exit 0
