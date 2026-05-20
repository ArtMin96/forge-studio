#!/usr/bin/env bash
# Context Engine: Post-compaction belief audit.
# After each compaction, automatically checks the 5 most-recently-edited files
# for belief drift. Appends results to .claude/state/belief-audit-post-compact.log.
# Async — does not block the turn.

AUDIT_SCRIPT="${CLAUDE_PLUGIN_ROOT}/skills/belief-audit/scripts/audit.sh"
LOG_FILE="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/state/belief-audit-post-compact.log"

mkdir -p "$(dirname "$LOG_FILE")"

if [ ! -x "$AUDIT_SCRIPT" ]; then
  exit 0
fi

{
  printf '\n--- Post-compact belief audit %s ---\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  bash "$AUDIT_SCRIPT" 5 2>&1 || true
} >> "$LOG_FILE"

exit 0
