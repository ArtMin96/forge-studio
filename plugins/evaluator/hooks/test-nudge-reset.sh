#!/usr/bin/env bash
# PostToolUse(Bash): Reset test-nudge counter when tests are run.
# Detects common test runner patterns in the command.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check if command looks like a test run
case "$COMMAND" in
  *pest*|*phpunit*|*"npm test"*|*"npm run test"*|*pytest*|*"go test"*|*"cargo test"*|*jest*|*vitest*|*mocha*|*rspec*|*"mix test"*)
    SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
    TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-test-nudge}/${SESSION_ID}"
    COUNTFILE="${TRACKDIR}/edit-count"
    # Reset counter
    echo "0" > "$COUNTFILE" 2>/dev/null
    # Mark as verified
    touch "${TRACKDIR}/verified-since-edit" 2>/dev/null
    ;;
esac

exit 0
