#!/usr/bin/env bash
# Emit a per-turn correlation key combining session_id and the hook shell's PID
# so log lines from one hook invocation can be joined across ledgers.
set -euo pipefail

case " $* " in *" --from-stdin "*) ;; *) exit 0 ;; esac
INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-}"
[ -z "$SESSION_ID" ] && exit 0

# Walk the /proc parent chain up to 6 hops looking for the hook shell — the first
# ancestor whose cmdline matches `plugins/*/hooks/*`. Without this, each nested
# helper invocation gets a fresh PID and one hook produces multiple turn_ids.
# Starttime (stat field 22) disambiguates re-used PIDs. Linux only; non-Linux
# falls back to plain $PPID and may drift across helper boundaries.
ANCHOR=""
P="${PPID:-}"
for _ in 1 2 3 4 5 6; do
  [ -z "$P" ] || [ "$P" = "0" ] && break
  CMD=$(tr '\0' ' ' < "/proc/$P/cmdline" 2>/dev/null || true)
  case "$CMD" in *plugins/*/hooks/*) ANCHOR="$P"; break ;; esac
  GP=$(awk '/^PPid:/{print $2}' "/proc/$P/status" 2>/dev/null || true)
  [ -z "$GP" ] || [ "$GP" = "0" ] || [ "$GP" = "$P" ] && break
  P="$GP"
done
[ -z "$ANCHOR" ] && ANCHOR="${PPID:-0}"
[ "$ANCHOR" = "0" ] && ANCHOR=$(date +%s%3N)
STARTTIME=$(awk '{print $22}' "/proc/$ANCHOR/stat" 2>/dev/null || true)
[ -n "$STARTTIME" ] && ANCHOR="${ANCHOR}.${STARTTIME}"

printf '%s-%s\n' "$SESSION_ID" "$ANCHOR"
