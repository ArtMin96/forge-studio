#!/usr/bin/env bash
# PostToolUse(Edit|Write): warn when written content includes
# changelog/sprint/phase markers. CLAUDE.md forbids these in source.
#
# PostToolUse cannot undo the write (issue #19009 — exit 2 only warns), so this
# hook only emits additionalContext nudging Claude to rewrite the comment.
# stop-clean-tree.sh is the blocking backstop at end-of-turn.
#
# Disable: FORGE_CHANGELOG_LEAK=0

set -u

if [ "${FORGE_CHANGELOG_LEAK:-1}" = "0" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Pull written content. Edit uses new_string; Write uses content.
CONTENT=""
case "$TOOL" in
  Edit)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
    ;;
  Write)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
    ;;
  *)
    exit 0
    ;;
esac

[ -z "$CONTENT" ] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
REL=$(echo "$FILE_PATH" | sed "s|^$(pwd)/||")

# Skip the plan files, lineage proposals, and history docs — those legitimately
# contain phase/sprint references describing process artifacts, not source.
case "$REL" in
  .claude/plans/*) exit 0 ;;
  .claude/lineage/*) exit 0 ;;
  docs/CHANGELOG*) exit 0 ;;
  CHANGELOG*) exit 0 ;;
esac

# POSIX ERE patterns (portable across GNU + BSD grep). \< \> are word boundaries
# supported by both. \s replaced with [[:space:]]. "Previously" tightened to
# require a slash-path so legitimate prose ("Previously Bob said") doesn't fire.
PATTERNS='\<Sprint[[:space:]]+[0-9]+\>|\<Phase[[:space:]]+[0-9]+\>|\(Sprint[[:space:]]+[[:alnum:]_]+\)|Was[[:space:]]+/[[:alnum:]_-]+,[[:space:]]+now[[:space:]]+/[[:alnum:]_-]+|Previously[[:space:]]+/[[:alnum:]_-]+|Replaced[[:space:]]+in[[:space:]]+v[0-9]|Post-Sprint[[:space:]]+[0-9]'

HIT=$(echo "$CONTENT" | grep -nEo "$PATTERNS" | head -3 | tr '\n' '; ')

if [ -z "$HIT" ]; then
  exit 0
fi

CTX="[changelog-leak] Phase/sprint marker detected in ${REL:-the written content}: ${HIT}. CLAUDE.md forbids changelog-style refs in source — rewrite the comment to explain WHY (the constraint or invariant), not WHEN (the sprint/phase). The plan file and PR description carry process state."

jq -nc --arg c "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $c
  }
}'
exit 0
