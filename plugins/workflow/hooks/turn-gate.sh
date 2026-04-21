#!/usr/bin/env bash
# Stop: at the end of Claude's turn, surface open loops — unchecked plan items,
# context pressure, long idle on in-progress work.
#
# Rate-limited: only fires every WORKFLOW_TURN_GATE_INTERVAL turns (default 3) so
# we don't nag every message. Anthropic noise-reduction principle: bound cadence.

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-default}"

COUNTFILE="/tmp/claude-workflow-turn-${SESSION_ID}"
COUNT=$(cat "$COUNTFILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

INTERVAL="${WORKFLOW_TURN_GATE_INTERVAL:-3}"
# Only run checks every N turns.
if [ $((COUNT % INTERVAL)) -ne 0 ]; then
  exit 0
fi

MSG=""

# Unchecked plan items.
PLANS_DIR=".claude/plans"
if [ -d "$PLANS_DIR" ]; then
  LATEST_PLAN=$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -mmin -360 -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "$LATEST_PLAN" ]; then
    UNCHECKED=$(grep -c '^\s*- \[ \]' "$LATEST_PLAN" 2>/dev/null || echo 0)
    if [ "$UNCHECKED" -gt 0 ]; then
      MSG="${MSG}[workflow] Plan $(basename "$LATEST_PLAN") has ${UNCHECKED} unchecked items. Update the plan or reconcile before claiming done."$'\n'
    fi
  fi
fi

# Context pressure → handoff nudge. Thresholds align with context-engine defaults.
if [ -n "${CLAUDE_CONTEXT_WINDOW_USED_PCT:-}" ]; then
  PCT="$CLAUDE_CONTEXT_WINDOW_USED_PCT"
  THRESH="${WORKFLOW_HANDOFF_PCT:-75}"
  if [ "$PCT" -ge "$THRESH" ] 2>/dev/null; then
    MSG="${MSG}[workflow] Context at ${PCT}%. Run /handoff (context-engine) before compaction risks information loss."$'\n'
  fi
fi

if [ -n "$MSG" ]; then
  printf '%s' "$MSG"
fi

exit 0
