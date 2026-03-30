#!/usr/bin/env bash
# Quality Gates: Remind to run tests before committing.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only trigger on git commit commands
if echo "$COMMAND" | grep -qE '^git\s+commit'; then
  echo "Pre-commit reminder: Have you run tests? Consider /healthcheck before committing."
fi

exit 0
