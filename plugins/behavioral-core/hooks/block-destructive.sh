#!/usr/bin/env bash
# Behavioral Core: Block destructive commands.
# Uses JSON permissionDecision output (exit 0) for blocking.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

deny_command() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Layer 5 (runs first): safe-mode flag denies all mutations until cleared.
# Set by context-engine/consecutive-failure-guard.sh at FORGE_SAFE_MODE_THRESHOLD.
# Cleared by /safe-mode off.
if [ -f .claude/safe-mode ]; then
  REASON=$(jq -r '.reason // "unspecified"' .claude/safe-mode 2>/dev/null)
  COUNTER=$(jq -r '.counter // "?"' .claude/safe-mode 2>/dev/null)
  deny_command "safe-mode active (reason: ${REASON}, failures: ${COUNTER}). Diagnose root cause, then run /safe-mode off. Until then all mutations are blocked."
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Layer 1: Direct destructive patterns
if echo "$COMMAND" | grep -qEi '(rm\s+-rf\s+[/~]|git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D)'; then
  MATCHED=$(echo "$COMMAND" | grep -oEi '(rm\s+-rf\s+[/~]|git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D)' | head -1)
  deny_command "Destructive command detected: '${MATCHED}'. Ask the user to run it manually if genuinely needed."
fi

# Layer 2: Shell wrapper obfuscation (bash -c '...', sh -c "...")
if echo "$COMMAND" | grep -qE '(bash|sh|zsh)\s+-c\s'; then
  INNER=$(echo "$COMMAND" | grep -oP "(?<=-c\s')[^']*" 2>/dev/null || echo "$COMMAND" | grep -oP '(?<=-c\s")[^"]*' 2>/dev/null || echo "$COMMAND" | grep -oP '(?<=-c\s)\S+' 2>/dev/null)
  if [ -n "$INNER" ]; then
    if echo "$INNER" | grep -qEi '(rm\s+-r|git\s+push.*(-f|--force)|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE|git\s+clean|git\s+branch\s+-D)'; then
      deny_command "Destructive command hidden in shell wrapper. Ask the user to run it manually if genuinely needed."
    fi
  fi
fi

# Layer 3: Pipe-to-shell patterns
if echo "$COMMAND" | grep -qE '\|\s*(bash|sh|zsh)\b'; then
  deny_command "Pipe-to-shell detected. This pattern can execute arbitrary code. Ask the user to run it manually if genuinely needed."
fi

# Layer 4: Flag reordering (rm -r -f /, rm -f -r /)
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-z]*r[a-z]*\s+-[a-z]*f|-[a-z]*f[a-z]*\s+-[a-z]*r)\s+[/~]'; then
  deny_command "Recursive forced deletion detected (reordered flags). Ask the user to run it manually if genuinely needed."
fi

exit 0
