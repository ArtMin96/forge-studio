#!/usr/bin/env bash
# PreToolUse:Edit|Write — if .claude/spec.md mentions any symbol from the
# edited file's path, surface up to 3 matching lines as a soft nudge.
# Read-only; never blocks. Exit 0 always.
#
# Reasoning (Lesson 5, Breunig 2026-05-04 + SDD Triangle 2026-03-04): treating
# the spec as a frozen artifact loses learnings during implementation. Surfacing
# spec lines relevant to the current edit keeps the spec-code feedback loop alive.

set -euo pipefail

SPEC_FILE=".claude/spec.md"
[ ! -s "$SPEC_FILE" ] && exit 0

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.claude/*|*node_modules/*|*vendor/*|*.git/*|*docs/research/*|*/dist/*|*/build/*) exit 0 ;;
esac

BASE=$(basename "$FILE_PATH")
STEM="${BASE%.*}"
PARENT=$(basename "$(dirname "$FILE_PATH")")

is_useful() {
  local s="$1"
  [ ${#s} -ge 4 ] || return 1
  case "$s" in
    index|main|app|lib|src|test|tests|spec|specs|hooks|scripts|skills|plugins) return 1 ;;
    [0-9]*) return 1 ;;
  esac
  return 0
}

CANDIDATES=()
is_useful "$STEM" && CANDIDATES+=("$STEM")
is_useful "$PARENT" && CANDIDATES+=("$PARENT")
[ ${#CANDIDATES[@]} -eq 0 ] && exit 0

MATCHES=""
for c in "${CANDIDATES[@]}"; do
  HITS=$(grep -niF -- "$c" "$SPEC_FILE" 2>/dev/null | head -3)
  if [ -n "$HITS" ]; then
    MATCHES="${MATCHES}${HITS}\n"
  fi
done

[ -z "$MATCHES" ] && exit 0

printf '[long-session] spec.md mentions symbols from %s:\n' "$FILE_PATH"
printf '%b' "$MATCHES" | head -3
printf '[long-session] If this edit changes the documented behavior, update .claude/spec.md to reflect it (Lesson 5: keep specs in sync).\n'

exit 0
