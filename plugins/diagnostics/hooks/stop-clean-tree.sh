#!/usr/bin/env bash
# Stop: scan staged + unstaged tree for phase/sprint markers and block end-of-turn
# until the working tree is clean. Backstop for the changelog-leak PostToolUse
# warning (which can only nudge, not undo).

set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$ACTIVE" = "true" ] && exit 0

# Skip outside a git tree.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# POSIX ERE patterns (portable across GNU + BSD grep). See changelog-leak.sh for rationale.
PATTERNS='\<Sprint[[:space:]]+[0-9]+\>|\<Phase[[:space:]]+[0-9]+\>|\(Sprint[[:space:]]+[[:alnum:]_]+\)|Was[[:space:]]+/[[:alnum:]_-]+,[[:space:]]+now[[:space:]]+/[[:alnum:]_-]+|Previously[[:space:]]+/[[:alnum:]_-]+|Replaced[[:space:]]+in[[:space:]]+v[0-9]|Post-Sprint[[:space:]]+[0-9]'

# Only inspect changes (staged + unstaged) — bounded cost, ignores existing source.
CHANGED=$(timeout 1 git diff --name-only HEAD 2>/dev/null; timeout 1 git diff --cached --name-only 2>/dev/null)
CHANGED=$(echo "$CHANGED" | sort -u | grep -v '^$')

[ -z "$CHANGED" ] && exit 0

VIOLATIONS=""
while IFS= read -r f; do
  # Skip plan / lineage / changelog files.
  case "$f" in
    .claude/plans/*) continue ;;
    .claude/lineage/*) continue ;;
    docs/CHANGELOG*) continue ;;
    CHANGELOG*) continue ;;
  esac
  [ ! -f "$f" ] && continue
  HIT=$(grep -nEo "$PATTERNS" "$f" 2>/dev/null | head -1)
  if [ -n "$HIT" ]; then
    VIOLATIONS="${VIOLATIONS}${f}: ${HIT}"$'\n'
  fi
done <<< "$CHANGED"

if [ -z "$VIOLATIONS" ]; then
  exit 0
fi

# Trim to first 5 violations to stay within reason text limits.
SUMMARY=$(echo "$VIOLATIONS" | head -5 | tr '\n' ';' | sed 's/;$//')

REASON="Pre-completion clean-tree scan failed. Phase/sprint markers found in changed files: ${SUMMARY}. Remove them — comments must explain WHY (the constraint), not WHEN (the sprint). Plan + PR description carry process state."

jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
exit 0
