#!/usr/bin/env bash
# Context Engine: System-reminder accumulation awareness.
# Piggybacks on track-context-pressure's exchange counter to warn
# when system-reminder noise is likely high.
# Claude Code wraps every hook output, attachment, skill discovery,
# and memory injection in <system-reminder> tags with no deduplication.
# In long conversations, identical content accumulates 30+ times.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
COUNTFILE="/tmp/claude-context-pressure-${SESSION_ID}"

if [[ ! -f "$COUNTFILE" ]]; then
  exit 0
fi

COUNT=$(cat "$COUNTFILE")
THRESHOLD=${FORGE_REMINDER_WARN_THRESHOLD:-15}

# Only warn once, at the threshold
if [[ "$COUNT" -eq "$THRESHOLD" ]]; then
  echo "System-reminder accumulation is likely high after ${COUNT} exchanges. Repeated hook injections stack without deduplication. If quality degrades, /compact to reset."
fi

exit 0
