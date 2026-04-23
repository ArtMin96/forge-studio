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
  # Configurable percentage thresholds
  P1=${FORGE_CONTEXT_PCT1:-50}
  P2=${FORGE_CONTEXT_PCT2:-65}
  P3=${FORGE_CONTEXT_PCT3:-75}
  P4=${FORGE_CONTEXT_PCT4:-85}
  P5=${FORGE_CONTEXT_PCT5:-92}
  if [[ "$PCT" -ge $P5 ]]; then
    echo "[CONTEXT CRITICAL] ${PCT}% used. /progress-log now or risk incoherent output."
  elif [[ "$PCT" -ge $P4 ]]; then
    echo "[CONTEXT HIGH] ${PCT}% used. Strongly recommend /progress-log and fresh session."
  elif [[ "$PCT" -ge $P3 ]]; then
    echo "[CONTEXT ELEVATED] ${PCT}% used. Recommend /compact now. Quality starts degrading."
  elif [[ "$PCT" -ge $P2 ]]; then
    echo "[CONTEXT MODERATE] ${PCT}% used. Run /token-pipeline (context-engine) to plan a reduction — Collection/Ranking/Compression/Budgeting/Assembly report."
  elif [[ "$PCT" -ge $P1 ]]; then
    echo "[CONTEXT NOTICE] ${PCT}% used. Working memory shrinking. Re-read files before editing."
  fi
  exit 0
fi

# Configurable thresholds via FORGE_* env vars (set in settings.json env section)
S1=${FORGE_CONTEXT_STAGE1:-8}
S2=${FORGE_CONTEXT_STAGE2:-15}
S3=${FORGE_CONTEXT_STAGE3:-22}
S4=${FORGE_CONTEXT_STAGE4:-30}
S5=${FORGE_CONTEXT_STAGE5:-40}

# Fallback: message-count heuristic (calibrated to ~200k token context window)
if [[ $COUNT -eq $S1 ]]; then
  echo "[CONTEXT NOTICE] ~${S1} exchanges. Working memory shrinking. Re-read files before editing."

elif [[ $COUNT -eq $S2 ]]; then
  echo "[CONTEXT MODERATE] ~${S2} exchanges. Run /token-pipeline (context-engine) to plan a reduction — Collection/Ranking/Compression/Budgeting/Assembly report."

elif [[ $COUNT -eq $S3 ]]; then
  echo "[CONTEXT ELEVATED] ~${S3} exchanges. Recommend /compact now. Quality starts degrading."

elif [[ $COUNT -eq $S4 ]]; then
  echo "[CONTEXT HIGH] ~${S4} exchanges. Strongly recommend /progress-log and fresh session."

elif [[ $COUNT -eq $S5 ]]; then
  echo "[CONTEXT CRITICAL] ~${S5} exchanges. /progress-log now or risk incoherent output."

# Repeat critical warning every 5 messages after stage 5
elif [[ $COUNT -gt $S5 ]] && [[ $(( (COUNT - S5) % 5 )) -eq 0 ]]; then
  echo "[CONTEXT CRITICAL] ${COUNT} exchanges. You are well past safe limits. /progress-log immediately."
fi

exit 0
