#!/usr/bin/env bash
# PostToolUseFailure: Track consecutive tool failures and escalate.
# At FORGE_FAILURE_THRESHOLD (default 3), inject a warning to break retry loops.
# At FORGE_SAFE_MODE_THRESHOLD (default 5), write .claude/safe-mode — a degraded-mode
# flag that block-destructive.sh reads to deny mutating tools until the user runs
# /safe-mode off. Both thresholds log to .claude/lineage/ledger.jsonl for audit.
#
# Rationale (TRAE §5.2.4 Graceful Degradation + 12-Factor Agent, HumanLayer):
# Agents with 50+ turns repeat failed approaches; a hard degradation step
# forces a human checkpoint before irreversible moves.
# Reset on PostToolUse success (tracked separately).

INPUT=$(cat)

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-failure-guard}/${SESSION_ID}"
mkdir -p "$TRACKDIR"

COUNTFILE="${TRACKDIR}/consecutive-failures"

if [ -f "$COUNTFILE" ]; then
  COUNT=$(cat "$COUNTFILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTFILE"

WARN_THRESH="${FORGE_FAILURE_THRESHOLD:-3}"
SAFE_THRESH="${FORGE_SAFE_MODE_THRESHOLD:-5}"
SAFE_FLAG=".claude/safe-mode"

TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)

# Emit warning once we cross the warn threshold (does not block).
if [ "$COUNT" -ge "$WARN_THRESH" ] && [ "$COUNT" -lt "$SAFE_THRESH" ]; then
  echo "${COUNT} consecutive tool failures (last: ${TOOL}). Stop. Re-read the error output. What assumption is wrong? Consider a different approach."
fi

# Cross into safe-mode: write flag + ledger entry. Only on the transition (first time
# we hit the threshold), not on every subsequent failure, to avoid flag thrash.
if [ "$COUNT" -ge "$SAFE_THRESH" ] && [ ! -f "$SAFE_FLAG" ]; then
  mkdir -p .claude .claude/lineage 2>/dev/null || true
  TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '{"entered_at":"%s","reason":"consecutive-failures","counter":%d,"last_tool":"%s"}\n' \
    "$TS" "$COUNT" "$TOOL" > "$SAFE_FLAG"
  printf '{"ts":"%s","operator":"safe-mode-enter","resource":"session/%s","trigger":"consecutive-failure-guard","evidence":"counter:%d last:%s","actor":"context-engine:consecutive-failure-guard"}\n' \
    "$TS" "$SESSION_ID" "$COUNT" "$TOOL" >> .claude/lineage/ledger.jsonl 2>/dev/null || true
  echo "SAFE MODE ENTERED after ${COUNT} consecutive failures. Write/Edit/destructive Bash are now blocked. Diagnose the root cause, then run: /safe-mode off"
fi

exit 0
