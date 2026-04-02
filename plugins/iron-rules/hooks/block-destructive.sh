#!/usr/bin/env bash
# Iron Rules: Block destructive commands.
# exit 2 = BLOCK the command. exit 1 = warn only. exit 0 = allow.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Layer 1: Direct destructive patterns
if echo "$COMMAND" | grep -qEi '(rm\s+-rf\s+[/~]|git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D)'; then
  MATCHED=$(echo "$COMMAND" | grep -oEi '(rm\s+-rf\s+[/~]|git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D)' | head -1)
  echo "BLOCKED: Destructive command detected: '$MATCHED'. If you genuinely need this, ask the user to run it manually."
  exit 2
fi

# Layer 2: Shell wrapper obfuscation (bash -c '...', sh -c "...")
if echo "$COMMAND" | grep -qE '(bash|sh|zsh)\s+-c\s'; then
  INNER=$(echo "$COMMAND" | grep -oP "(?<=-c\s')[^']*" 2>/dev/null || echo "$COMMAND" | grep -oP '(?<=-c\s")[^"]*' 2>/dev/null || echo "$COMMAND" | grep -oP '(?<=-c\s)\S+' 2>/dev/null)
  if [ -n "$INNER" ]; then
    if echo "$INNER" | grep -qEi '(rm\s+-r|git\s+push.*(-f|--force)|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE|git\s+clean|git\s+branch\s+-D)'; then
      echo "BLOCKED: Destructive command hidden in shell wrapper. If you genuinely need this, ask the user to run it manually."
      exit 2
    fi
  fi
fi

# Layer 3: Pipe-to-shell patterns
if echo "$COMMAND" | grep -qE '\|\s*(bash|sh|zsh)\b'; then
  echo "BLOCKED: Pipe-to-shell detected. This pattern can execute arbitrary code. If you genuinely need this, ask the user to run it manually."
  exit 2
fi

# Layer 4: Flag reordering (rm -r -f /, rm -f -r /)
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-z]*r[a-z]*\s+-[a-z]*f|-[a-z]*f[a-z]*\s+-[a-z]*r)\s+[/~]'; then
  echo "BLOCKED: Recursive forced deletion detected (reordered flags). If you genuinely need this, ask the user to run it manually."
  exit 2
fi

exit 0
