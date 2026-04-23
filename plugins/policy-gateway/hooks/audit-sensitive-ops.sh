#!/usr/bin/env bash
# PostToolUse:Edit|Write — non-blocking audit of writes targeting sensitive paths.
# Appends a ledger entry for every write to .env, secrets/, credentials/, etc.
# Output surfaces via /gate-report and /policy-audit.

set -u

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Sensitive path heuristics. Keep narrow; overbroad = noise.
SENSITIVE=0
case "$FILE_PATH" in
  *.env|*.env.*|*/\.env|*/\.env.*) SENSITIVE=1 ;;
  */secrets/*|*/credentials/*|*/keys/*|*/private/*) SENSITIVE=1 ;;
  *id_rsa*|*id_ed25519*|*.pem|*.key|*.p12|*.pfx) SENSITIVE=1 ;;
esac

if [ "$SENSITIVE" != "1" ]; then
  exit 0
fi

LEDGER_DIR=".claude/lineage"
mkdir -p "$LEDGER_DIR" 2>/dev/null || exit 0

TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
printf '{"ts":"%s","operator":"sensitive-op-audit","resource":"file/%s","trigger":"%s","evidence":"postwrite","actor":"policy-gateway:audit-sensitive-ops"}\n' \
  "$TS" "${FILE_PATH//\"/\\\"}" "${TOOL:-unknown}" >> "${LEDGER_DIR}/ledger.jsonl" || true

exit 0
