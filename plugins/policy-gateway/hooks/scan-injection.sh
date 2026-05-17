#!/usr/bin/env bash
# PreToolUse:Bash|Edit|Write — scan tool inputs for prompt-injection patterns.
# Same permissionDecision:deny contract as block-destructive. Patterns in rules.d/injection.txt.

set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
# Combine the relevant tool-input fields into a single haystack.
HAYSTACK=$(echo "$INPUT" | jq -r '[.tool_input.command // "", .tool_input.content // "", .tool_input.new_string // "", .tool_input.old_string // ""] | join(" \n ")' 2>/dev/null) || true

if [ -z "$HAYSTACK" ]; then
  exit 0
fi

RULES_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/rules.d/injection.txt"
if [ ! -f "$RULES_FILE" ]; then
  exit 0
fi

append_ledger() {
  local pattern="$1"
  local ts safe_pat line
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  safe_pat=$(printf '%s' "$pattern" | sed 's/"/\\\\"/g')
  line=$(printf '{"ts":"%s","operator":"policy-block","resource":"tool-input","trigger":"scan-injection","evidence":"pattern:%s","actor":"policy-gateway:scan-injection"}' \
    "$ts" "$safe_pat")
  bash plugins/_lib/jsonl-append.sh --with-turn-id .claude/lineage/ledger.jsonl "$line" <<< "$INPUT"
}

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  if printf '%s' "$HAYSTACK" | grep -qiE -- "$line"; then
    append_ledger "$line"
    deny "policy-gateway: prompt-injection pattern matched. Review the tool input for smuggled instructions. Refine rules.d/injection.txt if false positive."
  fi
done < "$RULES_FILE"

exit 0
