#!/usr/bin/env bash
# PreToolUse:Edit|Write — scan the new content for secrets and block if found.
# Uses the same permissionDecision:deny JSON contract as behavioral-core/block-destructive.
# Patterns live in rules.d/secrets.txt (evolvable via SEPL).

set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
# We scan whatever is being written: new_string for Edit, content for Write, file_path as fallback context.
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null) || true
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true

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
  local ts line
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  line=$(printf '{"ts":"%s","operator":"policy-block","resource":"file/%s","trigger":"scan-secrets","evidence":"%s","actor":"policy-gateway:scan-secrets"}' \
    "$ts" "${file//\"/\\\"}" "$label")
  bash "${CLAUDE_PLUGIN_ROOT}/_lib/jsonl-append.sh" --with-turn-id .claude/lineage/ledger.jsonl "$line" <<< "$INPUT"
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

# arXiv:2605.18747 §5.2.5 — context-sensitive policy: same secret-shape
# is intentional in tests/fixtures but a real leak in src/. Optional 3rd
# tab-delimited field on each rule line restricts where the rule applies:
#   <regex>|<label>                              global (default, unchanged)
#   <regex>|<label>\t<glob>[;<glob>...]          only when FILE_PATH matches
#   <regex>|<label>\t!<glob>                     except when FILE_PATH matches
# Empty FILE_PATH (Edit on missing path) falls through as "apply rule"
# — safer default for secret-scanning.
match_scope() {
  local scope="$1" path="$2"
  [ -z "$scope" ] && return 0
  [ -z "$path" ] && return 0
  local has_positive=0 positive_hit=0 g
  local IFS=';'
  for g in $scope; do
    if [ "${g:0:1}" = "!" ]; then
      # shellcheck disable=SC2053
      [[ "$path" == ${g#!} ]] && return 1
    else
      has_positive=1
      # shellcheck disable=SC2053
      [[ "$path" == $g ]] && positive_hit=1
    fi
  done
  [ "$has_positive" = "1" ] && [ "$positive_hit" = "0" ] && return 1
  return 0
}

# Iterate rules. Each non-comment line is `<regex>|<label>[<TAB><scope>]`.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  RULE_PART="${line%%	*}"
  if [ "$RULE_PART" = "$line" ]; then
    SCOPE=""
  else
    SCOPE="${line#*	}"
  fi
  PATTERN="${RULE_PART%|*}"
  LABEL="${RULE_PART##*|}"
  match_scope "$SCOPE" "$FILE_PATH" || continue
  if printf '%s' "$CONTENT" | grep -qE -- "$PATTERN"; then
    append_ledger "secret-detected:${LABEL}" "${FILE_PATH:-<unknown>}"
    deny "policy-gateway: secret pattern matched (${LABEL}) in ${FILE_PATH:-content}. Remove the secret or move it to an environment file. If this is a false positive, refine rules.d/secrets.txt (optional tab-delimited scope glob narrows scope)."
  fi
done < "$RULES_FILE"

exit 0
