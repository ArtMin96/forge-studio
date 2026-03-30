#!/usr/bin/env bash
# Iron Rules: Block destructive commands.
# exit 2 = BLOCK the command. exit 1 = warn only. exit 0 = allow.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check for destructive patterns
if echo "$COMMAND" | grep -qE '(rm\s+-rf\s+[/~]|git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D)'; then
  MATCHED=$(echo "$COMMAND" | grep -oE '(rm\s+-rf\s+[/~]|git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D)' | head -1)
  echo "BLOCKED: Destructive command detected: '$MATCHED'. This action is irreversible. If you genuinely need this, ask the user to run it manually."
  exit 2
fi

exit 0
