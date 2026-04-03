#!/usr/bin/env bash
# Context Engine: Pre-compaction context preservation.
# Saves critical state before compaction destroys working memory.
# The model can re-read this file after compaction to restore context.

STATE_DIR="${HOME}/.claude"
STATE_FILE="${STATE_DIR}/pre-compact-state.md"

OUTPUT="## Pre-Compaction Reminder"$'\n'
OUTPUT+="Context is about to be compacted. After compaction:"$'\n'
OUTPUT+="- Re-read any files you were actively editing"$'\n'
OUTPUT+="- Check .claude/pre-compact-state.md for saved context"$'\n'

# Check if there's an active scope (scope skill creates files in .claude/scopes/)
SCOPES_DIR="${STATE_DIR}/scopes"
LATEST_SCOPE=""
if [[ -d "$SCOPES_DIR" ]]; then
  LATEST_SCOPE=$(find "$SCOPES_DIR" -maxdepth 1 -name '*.md' -mmin -120 -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  if [[ -n "$LATEST_SCOPE" ]]; then
    OUTPUT+="- Active scope saved: ${LATEST_SCOPE}"$'\n'
  fi
fi

# Check if there's an active plan
PLAN_DIR="${STATE_DIR}/plans"
if [[ -d "$PLAN_DIR" ]]; then
  LATEST_PLAN=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)
  if [[ -n "$LATEST_PLAN" ]]; then
    OUTPUT+="- Active plan: ${LATEST_PLAN}"$'\n'
  fi
fi

# Check for handoff files
HANDOFF_DIR="${STATE_DIR}/handoffs"
if [[ -d "$HANDOFF_DIR" ]]; then
  LATEST_HANDOFF=$(ls -t "$HANDOFF_DIR"/*.md 2>/dev/null | head -1)
  if [[ -n "$LATEST_HANDOFF" ]]; then
    OUTPUT+="- Latest handoff: ${LATEST_HANDOFF}"$'\n'
  fi
fi

# Save state file for post-compact recovery
{
  echo "# Pre-Compact State ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  echo ""
  echo "Working directory: $(pwd)"
  [[ -n "$LATEST_SCOPE" ]] && echo "Active scope: ${LATEST_SCOPE}"
  [[ -n "$LATEST_PLAN" ]] && echo "Active plan: ${LATEST_PLAN}"
  [[ -n "$LATEST_HANDOFF" ]] && echo "Latest handoff: ${LATEST_HANDOFF}"
  echo ""
  echo "## Git State"
  BRANCH=$(git branch --show-current 2>/dev/null)
  [[ -n "$BRANCH" ]] && echo "Branch: ${BRANCH}"
  DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "Uncommitted changes: ${DIRTY}"
  if [[ "$DIRTY" -gt 0 ]]; then
    echo ""
    echo "### Modified files"
    git status --porcelain 2>/dev/null | head -20
  fi
} > "$STATE_FILE" 2>/dev/null

echo "$OUTPUT"
exit 0
