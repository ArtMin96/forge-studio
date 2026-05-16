#!/usr/bin/env bash
# Emit a per-turn correlation key combining session_id and the parent shell's PID
# so log lines from one hook invocation can be joined across ledgers.
set -euo pipefail

FROM_STDIN=0
for arg in "$@"; do
  [ "$arg" = "--from-stdin" ] && FROM_STDIN=1
done
[ "$FROM_STDIN" = "0" ] && exit 0

INPUT=$(cat 2>/dev/null || true)

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-}"
[ -z "$SESSION_ID" ] && exit 0

# Prefer the nearest real hook-shell ancestor. On Linux a $(...) pass-through subshell
# copies its parent's argv on fork-without-exec; if PPID cmdline matches its own parent's,
# step one level up to reach the actual hook shell rather than an ephemeral subshell.
# Linux only; non-Linux skips the /proc walk and uses plain $PPID, which may drift across
# pipeline-subshell helper calls within one hook turn.
PPID_CMD=$(tr '\0' ' ' < /proc/$PPID/cmdline 2>/dev/null || true)
GP=$(awk '/^PPid:/{print $2}' /proc/$PPID/status 2>/dev/null || true)
GP_CMD=$(tr '\0' ' ' < /proc/${GP:-0}/cmdline 2>/dev/null || true)

if [ -n "$PPID_CMD" ] && [ "$PPID_CMD" = "$GP_CMD" ] && [ -n "$GP" ] && [ "$GP" != "0" ]; then
  ANCHOR="$GP"
elif [ -n "${PPID:-}" ] && [ "${PPID}" != "0" ]; then
  ANCHOR="$PPID"
else
  ANCHOR=$(date +%s%3N)
fi

printf '%s-%s\n' "$SESSION_ID" "$ANCHOR"
