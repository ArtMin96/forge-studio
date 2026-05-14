#!/usr/bin/env bash
# handoff-state.sh — shared helper for generator handoff tracking.
# Reads and writes .claude/handoffs.jsonl (append-only event log).
# Argv-driven: first argument selects the function.
#
# Usage:
#   handoff-state.sh open  <plan_basename>          → prints handoff_id to stdout
#   handoff-state.sh close <handoff_id> <status>    → appends close event
#   handoff-state.sh age   <handoff_id>             → prints seconds since open (wall-clock)
#   handoff-state.sh --help

set -euo pipefail

HANDOFFS_FILE="${HANDOFFS_FILE:-.claude/handoffs.jsonl}"

usage() {
  cat <<EOF
Usage: handoff-state.sh <command> [args]

Commands:
  open  <plan_basename>           Write handoff_open line; print handoff_id to stdout.
  close <handoff_id> <status>     Append handoff_close / handoff_resolved / handoff_skipped line.
  age   <handoff_id>              Print seconds elapsed since open (wall-clock).
  --help                          Show this message.

Exit codes:
  0  success
  1  usage error or handoff_id not found
EOF
}

handoff_open() {
  local plan_basename="$1"
  if [ -z "$plan_basename" ]; then
    echo "ERROR: handoff_open requires plan_basename" >&2
    exit 1
  fi

  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # Generate unique id: timestamp prefix + 6-char random hex.
  local handoff_id
  handoff_id="${ts//[^0-9]/}-$(openssl rand -hex 3 2>/dev/null || printf '%06x' $((RANDOM * RANDOM % 16777216)))"

  # Unix epoch seconds at open — enables cross-session wall-clock age checks.
  local opened_at
  opened_at=$(date +%s)

  mkdir -p "$(dirname "$HANDOFFS_FILE")"
  printf '{"event":"handoff_open","handoff_id":"%s","ts":"%s","plan":"%s","opened_at":%s}\n' \
    "$handoff_id" "$ts" "$plan_basename" "$opened_at" >> "$HANDOFFS_FILE"

  echo "$handoff_id"
}

handoff_close() {
  local handoff_id="$1"
  local status="$2"

  if [ -z "$handoff_id" ] || [ -z "$status" ]; then
    echo "ERROR: handoff_close requires handoff_id and status" >&2
    exit 1
  fi

  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  mkdir -p "$(dirname "$HANDOFFS_FILE")"
  printf '{"event":"%s","handoff_id":"%s","ts":"%s"}\n' \
    "$status" "$handoff_id" "$ts" >> "$HANDOFFS_FILE"
}

handoff_age_seconds() {
  local handoff_id="$1"

  if [ -z "$handoff_id" ]; then
    echo "ERROR: handoff_age requires handoff_id" >&2
    exit 1
  fi

  if [ ! -f "$HANDOFFS_FILE" ]; then
    echo 0
    return 0
  fi

  # Find opened_at (Unix epoch) for this handoff_id.
  # Pre-existing entries with "turn_at_open" won't match; they return 0 and never age out.
  local opened_at
  opened_at=$(grep "\"handoff_open\"" "$HANDOFFS_FILE" 2>/dev/null \
    | grep "\"$handoff_id\"" \
    | grep -oE '"opened_at":[0-9]+' \
    | grep -oE '[0-9]+$' \
    | tail -1)

  if [ -z "$opened_at" ]; then
    echo "0"
    return 0
  fi

  local current
  current=$(date +%s)

  echo $((current - opened_at))
}

# --- dispatch ---
CMD="${1:-}"
case "$CMD" in
  open)
    handoff_open "${2:-}"
    ;;
  close)
    handoff_close "${2:-}" "${3:-}"
    ;;
  age)
    handoff_age_seconds "${2:-}"
    ;;
  --help|-h|help)
    usage
    exit 0
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    echo "ERROR: unknown command '$CMD'" >&2
    usage
    exit 1
    ;;
esac
