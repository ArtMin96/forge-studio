#!/usr/bin/env bash
# PostToolUse:Bash — when the just-run command was a successful `git commit`,
# surface a one-line nudge to capture the decision via /remember.
# Reads tool input from stdin (Claude Code hook contract). Silent on non-commits.

set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
EXIT=$(printf '%s' "$INPUT" | jq -r '.tool_response.exit_code // empty' 2>/dev/null || true)

case "$CMD" in
  *"git commit"*) ;;
  *"git "*"commit"*) ;;
  *) exit 0 ;;
esac

case "$CMD" in *"--amend"*|*"--dry-run"*) exit 0 ;; esac
[ -n "$EXIT" ] && [ "$EXIT" != "0" ] && exit 0

if [ ! -d .git ]; then exit 0; fi

SUBJECT=$(git log -1 --pretty=%s 2>/dev/null)
[ -z "$SUBJECT" ] && exit 0

printf '[memory] Commit landed: %s\n' "$SUBJECT"
printf '[memory] If this commit reflects a decision worth keeping (architecture, constraint, "always do it this way"), invoke /remember to capture the WHY.\n'
exit 0
