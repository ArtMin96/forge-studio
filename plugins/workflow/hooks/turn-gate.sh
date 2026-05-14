#!/usr/bin/env bash
set -euo pipefail
# Stop: at the end of Claude's turn, surface open loops — unchecked plan items,
# context pressure, long idle on in-progress work.
#
# Rate-limited: only fires every WORKFLOW_TURN_GATE_INTERVAL turns (default 3) so
# we don't nag every message. Anthropic noise-reduction principle: bound cadence.

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-default}"

# Session-local cookie under /tmp — purely rate-limits this hook's emission
# cadence via COUNT % INTERVAL below. Unrelated to handoff-age math, which
# uses wall-clock seconds (lib/handoff-state.sh).
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

# Scan open handoffs: age them out or match against a /verify invocation.
# Reads .claude/handoffs.jsonl — written by after-subagent.sh via handoff-state.sh.
HANDOFFS_FILE=".claude/handoffs.jsonl"
LEDGER_FILE=".claude/lineage/ledger.jsonl"
FORGE_HANDOFF_SKIP_SECS="${FORGE_HANDOFF_SKIP_SECS:-5400}"
LIB_DIR="$(dirname "$0")/../lib"

if [ -f "$HANDOFFS_FILE" ]; then
  # Collect all handoff_ids that have a handoff_open but no close event yet.
  while IFS= read -r line; do
    hid=$(echo "$line" | grep -o '"handoff_id":"[^"]*"' | cut -d'"' -f4)
    plan=$(echo "$line" | grep -o '"plan":"[^"]*"' | cut -d'"' -f4)
    [ -z "$hid" ] && continue

    # Skip if a close event already exists for this id.
    if grep -q "\"$hid\"" "$HANDOFFS_FILE" 2>/dev/null && \
       grep "\"$hid\"" "$HANDOFFS_FILE" | grep -qE '"event":"(handoff_close|handoff_resolved|handoff_skipped)"'; then
      continue
    fi

    # Check if the current prompt matches /verify <plan-basename-without-ext>.
    PLAN_SLUG="${plan%.md}"
    PROMPT_TEXT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
    if echo "$PROMPT_TEXT" | grep -qE "^/verify[[:space:]]+${PLAN_SLUG}([[:space:]]|$)"; then
      bash "${LIB_DIR}/handoff-state.sh" close "$hid" "handoff_resolved" 2>/dev/null || true
      if [ -d "$(dirname "$LEDGER_FILE")" ]; then
        ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        printf '{"ts":"%s","event":"handoff_resolved","handoff_id":"%s","plan":"%s"}\n' \
          "$ts" "$hid" "$plan" >> "$LEDGER_FILE" 2>/dev/null || true
      fi
      continue
    fi

    # Age check: if open handoff is older than FORGE_HANDOFF_SKIP_SECS, mark skipped.
    age=$(bash "${LIB_DIR}/handoff-state.sh" age "$hid" 2>/dev/null || echo 0)
    if [ "${age:-0}" -ge "$FORGE_HANDOFF_SKIP_SECS" ] 2>/dev/null; then
      bash "${LIB_DIR}/handoff-state.sh" close "$hid" "handoff_skipped" 2>/dev/null || true
      if [ -d "$(dirname "$LEDGER_FILE")" ]; then
        ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        printf '{"ts":"%s","event":"handoff_skipped","handoff_id":"%s","plan":"%s"}\n' \
          "$ts" "$hid" "$plan" >> "$LEDGER_FILE" 2>/dev/null || true
      fi
      MSG="${MSG}[handoff] Handoff for ${plan} was not verified within $((FORGE_HANDOFF_SKIP_SECS/60)) minutes. Appended handoff_skipped to ledger."$'\n'
    fi
  done < <(grep '"event":"handoff_open"' "$HANDOFFS_FILE" 2>/dev/null || true)
fi

# Unchecked plan items.
PLANS_DIR=".claude/plans"
if [ -d "$PLANS_DIR" ]; then
  _REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo '.')}"
  LATEST_PLAN=$(bash "${_REPO_ROOT}/plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)
  if [ -n "$LATEST_PLAN" ]; then
    UNCHECKED=$(grep -c '^\s*- \[ \]' "$LATEST_PLAN" 2>/dev/null || true)
    UNCHECKED=${UNCHECKED:-0}
    if [ "$UNCHECKED" -gt 0 ]; then
      MSG="${MSG}[workflow] Plan $(basename "$LATEST_PLAN") has ${UNCHECKED} unchecked items. Update the plan or reconcile before claiming done."$'\n'
    fi
  fi
fi

if [ -n "${CLAUDE_CONTEXT_WINDOW_USED_PCT:-}" ]; then
  PCT="$CLAUDE_CONTEXT_WINDOW_USED_PCT"
  THRESH="${WORKFLOW_HANDOFF_PCT:-75}"
  if [ "$PCT" -ge "$THRESH" ] 2>/dev/null; then
    MSG="${MSG}[workflow] Context at ${PCT}%. Run /progress-log (long-session) before compaction risks information loss."$'\n'
  fi
fi

# Net-new commits this session → suggest /progress-log at session end.
# Only fires once per WORKFLOW_TURN_GATE_INTERVAL window; combines with the cadence above.
if [ -d .git ]; then
  # Swallow non-zero: git log may fail in shallow clones; wc/tr always succeed on empty input.
  RECENT_COMMITS=$(git log --oneline --since="2 hours ago" 2>/dev/null | wc -l | tr -d ' ') || true
  if [ "${RECENT_COMMITS:-0}" -gt 0 ] 2>/dev/null; then
    # Only nudge if no fresh progress entry exists (<10 min).
    if [ ! -f claude-progress.txt ] || ! find claude-progress.txt -mmin -10 2>/dev/null | grep -q .; then
      MSG="${MSG}[workflow] ${RECENT_COMMITS} new commits this session. Run /progress-log before ending to persist state."$'\n'
    fi
  fi
fi

if [ -n "$MSG" ]; then
  printf '%s' "$MSG"
fi

exit 0
