#!/usr/bin/env bash
set -euo pipefail
# PostToolUse: validate plan-file structure immediately after Write/Edit/MultiEdit on
# .claude/plans/*.md. Catches the canonical-format drift (`## Tasks` instead of
# `### Tasks`, `### T<n>` instead of `#### T<n>`) at write time so the orchestrator
# does not silently degrade to single-pass on a malformed plan.
#
# Advisory: exit 1 (warning) on violation, exit 0 otherwise. Never blocks.

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.claude/plans/*.md) ;;
  *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

BAD_SECTION=$(grep -nE '^## Tasks[[:space:]]*$' "$FILE_PATH" || true)
BAD_TASK=$(grep -nE '^### T[0-9]' "$FILE_PATH" || true)
GOOD_SECTION=$(grep -nE '^### Tasks[[:space:]]*$' "$FILE_PATH" || true)
GOOD_TASK=$(grep -nE '^#### T[0-9]' "$FILE_PATH" || true)

# Single-task plans may omit the Tasks section entirely — silent pass.
if [ -z "$BAD_SECTION" ] && [ -z "$BAD_TASK" ] && [ -z "$GOOD_SECTION" ] && [ -z "$GOOD_TASK" ]; then
  exit 0
fi

VIOLATIONS=""

if [ -n "$BAD_SECTION" ]; then
  VIOLATIONS="${VIOLATIONS}  - Section heading uses '## Tasks' (2-hash). Canonical: '### Tasks' (3-hash). Lines:\n$(echo "$BAD_SECTION" | sed 's/^/      /')\n"
fi

if [ -n "$BAD_TASK" ]; then
  VIOLATIONS="${VIOLATIONS}  - Task headings use '### T<n>' (3-hash). Canonical: '#### T<n>' (4-hash). Lines:\n$(echo "$BAD_TASK" | sed 's/^/      /')\n"
fi

# Has tasks-section heading or task headings but they don't match canonical pair.
if [ -z "$VIOLATIONS" ] && [ -n "$GOOD_SECTION" ] && [ -z "$GOOD_TASK" ]; then
  VIOLATIONS="${VIOLATIONS}  - '### Tasks' section is present but no '#### T<n>' headings found beneath it. parse-tasks.sh will return empty.\n"
fi

if [ -z "$VIOLATIONS" ] && [ -z "$GOOD_SECTION" ] && [ -n "$GOOD_TASK" ]; then
  VIOLATIONS="${VIOLATIONS}  - '#### T<n>' task headings exist but no '### Tasks' section heading above them. parse-tasks.sh awk-filter will not enter task-collection mode.\n"
fi

[ -z "$VIOLATIONS" ] && exit 0

{
  echo "[plan-format-check] $(basename "$FILE_PATH") does not match the canonical pipeline plan format:"
  printf '%b' "$VIOLATIONS"
  echo "  See plugins/agents/agents/planner.md §'Canonical plan file structure' and plugins/workflow/skills/orchestrate/scripts/parse-tasks.sh."
  echo "  Fix before running /orchestrate pipeline — otherwise the per-task contract loop silently collapses to single-pass dispatch."
} >&2

exit 1
