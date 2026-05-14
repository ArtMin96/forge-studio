#!/usr/bin/env bash
set -euo pipefail
# SessionStart: surface recent progress + active plan so the session resumes
# in-context without the user typing /session-resume. Silent when nothing to report.
#
# Composes long-session's claude-progress.txt instead of duplicating its logic.

INPUT=$(cat 2>/dev/null || true)
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"' 2>/dev/null)

# Only fire on fresh startups or explicit resumes. On `compact`, context-engine's
# post-compact hook already handles state restoration; piling on is noise.
if [ "$SOURCE" != "startup" ] && [ "$SOURCE" != "resume" ]; then
  exit 0
fi

MSG=""

# Most recent progress-log entry, if any.
PROGRESS_FILE="claude-progress.txt"
if [ -f "$PROGRESS_FILE" ]; then
  AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$PROGRESS_FILE" 2>/dev/null || echo 0) ) / 86400 ))
  MSG="${MSG}[workflow] claude-progress.txt updated ${AGE_DAYS}d ago. Run /session-resume for full briefing."$'\n'
fi

# Active plan + unchecked item count.
PLANS_DIR=".claude/plans"
if [ -d "$PLANS_DIR" ]; then
  _REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo '.')}"
  LATEST_PLAN=$(bash "${_REPO_ROOT}/plugins/workflow/skills/orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)
  if [ -n "$LATEST_PLAN" ]; then
    UNCHECKED=$(grep -c '^\s*- \[ \]' "$LATEST_PLAN" 2>/dev/null || true)
    UNCHECKED=${UNCHECKED:-0}
    MSG="${MSG}[workflow] Active plan: $(basename "$LATEST_PLAN") (${UNCHECKED} unchecked items)."$'\n'
  fi
fi

if [ -n "$MSG" ]; then
  printf '%s' "$MSG"
fi

exit 0
