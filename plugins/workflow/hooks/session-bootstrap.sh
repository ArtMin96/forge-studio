#!/usr/bin/env bash
# SessionStart: surface the latest handoff and active plan so the session resumes
# in-context without the user typing /resume. Silent when there's nothing to report.
#
# Composes context-engine's handoff artifacts instead of duplicating their logic.

INPUT=$(cat 2>/dev/null || true)
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"' 2>/dev/null)

# Only fire on fresh startups or explicit resumes. On `compact`, context-engine's
# post-compact hook already handles state restoration; piling on is noise.
if [ "$SOURCE" != "startup" ] && [ "$SOURCE" != "resume" ]; then
  exit 0
fi

MSG=""

# Most recent handoff, if any.
HANDOFFS_DIR=".claude/handoffs"
if [ -d "$HANDOFFS_DIR" ]; then
  LATEST_HANDOFF=$(find "$HANDOFFS_DIR" -maxdepth 1 -name '*.md' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "$LATEST_HANDOFF" ]; then
    AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$LATEST_HANDOFF" 2>/dev/null || echo 0) ) / 86400 ))
    MSG="${MSG}[workflow] Last handoff: $(basename "$LATEST_HANDOFF") (${AGE_DAYS}d ago). Run /resume to load it."$'\n'
  fi
fi

# Active plan + unchecked item count.
PLANS_DIR=".claude/plans"
if [ -d "$PLANS_DIR" ]; then
  LATEST_PLAN=$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "$LATEST_PLAN" ]; then
    UNCHECKED=$(grep -c '^\s*- \[ \]' "$LATEST_PLAN" 2>/dev/null || echo 0)
    MSG="${MSG}[workflow] Active plan: $(basename "$LATEST_PLAN") (${UNCHECKED} unchecked items)."$'\n'
  fi
fi

if [ -n "$MSG" ]; then
  printf '%s' "$MSG"
fi

exit 0
