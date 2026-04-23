#!/usr/bin/env bash
# PreToolUse:Edit|Write — scan the new content for secrets and block if found.
# Uses the same permissionDecision:deny JSON contract as behavioral-core/block-destructive.
# Patterns live in rules.d/secrets.txt (evolvable via SEPL).

set -u

INPUT=$(cat 2>/dev/null || true)
# We scan whatever is being written: new_string for Edit, content for Write, file_path as fallback context.
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Nothing to scan → pass through.
if [ -z "$CONTENT" ]; then
  exit 0
fi

RULES_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/rules.d/secrets.txt"
if [ ! -f "$RULES_FILE" ]; then
  # No rules installed → silent pass.
  exit 0
fi

append_ledger() {
  local label="$1"
  local file="$2"
  local ledger_dir=".claude/lineage"
  mkdir -p "$ledger_dir" 2>/dev/null || return 0
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '{"ts":"%s","operator":"policy-block","resource":"file/%s","trigger":"scan-secrets","evidence":"%s","actor":"policy-gateway:scan-secrets"}\n' \
    "$ts" "${file//\"/\\\"}" "$label" >> "${ledger_dir}/ledger.jsonl" || true
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

# Iterate rules. Each non-comment line is `<regex>|<label>`.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  PATTERN="${line%|*}"
  LABEL="${line##*|}"
  if printf '%s' "$CONTENT" | grep -qE -- "$PATTERN"; then
    append_ledger "secret-detected:${LABEL}" "${FILE_PATH:-<unknown>}"
    deny "policy-gateway: secret pattern matched (${LABEL}) in ${FILE_PATH:-content}. Remove the secret or move it to an environment file. If this is a false positive, refine rules.d/secrets.txt."
  fi
done < "$RULES_FILE"

exit 0
