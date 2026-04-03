#!/usr/bin/env bash
# Context Engine: Progressive context pressure tracking.
# 5-stage warnings calibrated to approximate context usage.
# Replaces fixed-threshold message counting with graduated urgency.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
COUNTFILE="/tmp/claude-context-pressure-${SESSION_ID}"

if [[ -f "$COUNTFILE" ]]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

# If Claude Code exposes actual context usage, prefer that over message heuristic
if [[ -n "${CLAUDE_CONTEXT_WINDOW_USED_PCT:-}" ]]; then
  PCT="$CLAUDE_CONTEXT_WINDOW_USED_PCT"
  if [[ "$PCT" -ge 92 ]]; then
    echo "[CONTEXT CRITICAL] ${PCT}% used. /handoff now or risk incoherent output."
  elif [[ "$PCT" -ge 85 ]]; then
    echo "[CONTEXT HIGH] ${PCT}% used. Strongly recommend /handoff and fresh session."
  elif [[ "$PCT" -ge 75 ]]; then
    echo "[CONTEXT ELEVATED] ${PCT}% used. Recommend /compact now. Quality starts degrading."
  elif [[ "$PCT" -ge 65 ]]; then
    echo "[CONTEXT MODERATE] ${PCT}% used. Consider /compact with instructions on what to preserve."
  elif [[ "$PCT" -ge 50 ]]; then
    echo "[CONTEXT NOTICE] ${PCT}% used. Working memory shrinking. Re-read files before editing."
  fi
  exit 0
fi

# Fallback: message-count heuristic (calibrated to ~200k token context window)
# Stage 1: ~50% context (~8 messages with typical tool use)
if [[ $COUNT -eq 8 ]]; then
  echo "[CONTEXT NOTICE] ~8 exchanges. Working memory shrinking. Re-read files before editing."

# Stage 2: ~65% context
elif [[ $COUNT -eq 15 ]]; then
  echo "[CONTEXT MODERATE] ~15 exchanges. Consider /compact with instructions on what to preserve."

# Stage 3: ~75% context
elif [[ $COUNT -eq 22 ]]; then
  echo "[CONTEXT ELEVATED] ~22 exchanges. Recommend /compact now. Quality starts degrading."

# Stage 4: ~85% context
elif [[ $COUNT -eq 30 ]]; then
  echo "[CONTEXT HIGH] ~30 exchanges. Strongly recommend /handoff and fresh session."

# Stage 5: ~92% context
elif [[ $COUNT -eq 40 ]]; then
  echo "[CONTEXT CRITICAL] ~40 exchanges. /handoff now or risk incoherent output."

# Repeat critical warning every 5 messages after stage 5
elif [[ $COUNT -gt 40 ]] && [[ $(( (COUNT - 40) % 5 )) -eq 0 ]]; then
  echo "[CONTEXT CRITICAL] ${COUNT} exchanges. You are well past safe limits. /handoff immediately."
fi

exit 0
