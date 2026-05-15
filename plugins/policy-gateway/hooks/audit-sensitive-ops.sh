#!/usr/bin/env bash
# PostToolUse:Edit|Write — non-blocking audit of writes targeting sensitive paths.
# Appends a ledger entry for every write to .env, secrets/, credentials/, etc.
# Output surfaces via /gate-report and /policy-audit.

set -euo pipefail

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

TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
LEDGER_LINE=$(printf '{"ts":"%s","operator":"sensitive-op-audit","resource":"file/%s","trigger":"%s","evidence":"postwrite","actor":"policy-gateway:audit-sensitive-ops"}' \
  "$TS" "${FILE_PATH//\"/\\\"}" "${TOOL:-unknown}")
bash plugins/_lib/jsonl-append.sh .claude/lineage/ledger.jsonl "$LEDGER_LINE"

exit 0
