#!/usr/bin/env bash
# time-hook.sh — wrap a hook command, log its duration, preserve its contract.
#
# Usage:
#   bash time-hook.sh <plugin> <event> <command> [args...]
#
# Reads stdin, forwards to <command>; writes <command>'s stdout to its own
# stdout; preserves <command>'s exit code. Appends one JSONL row per call to
# $FORGE_STUDIO_TIMING_LOG (default ~/.local/share/forge-studio/startup.jsonl).
#
# On any wrapper-internal failure, falls through to a direct exec so the host
# session never breaks because of measurement code.

set -u

if [ "$#" -lt 3 ]; then
  exec "$@" 2>/dev/null || exit 0
fi

plugin="$1"
event="$2"
shift 2

LOG_DIR="${FORGE_STUDIO_TIMING_DIR:-$HOME/.local/share/forge-studio}"
LOG_FILE="${FORGE_STUDIO_TIMING_LOG:-$LOG_DIR/startup.jsonl}"
mkdir -p "$LOG_DIR" 2>/dev/null || true

stdin_buf=""
if [ ! -t 0 ]; then
  stdin_buf=$(cat)
fi

start_ns=$(date +%s%N 2>/dev/null || echo "0")

if [ -n "$stdin_buf" ]; then
  printf '%s' "$stdin_buf" | "$@"
else
  "$@" </dev/null
fi
rc=$?

end_ns=$(date +%s%N 2>/dev/null || echo "0")

if [ "$start_ns" != "0" ] && [ "$end_ns" != "0" ]; then
  duration_ms=$(( (end_ns - start_ns) / 1000000 ))
else
  duration_ms=-1
fi

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
session="${CLAUDE_SESSION_ID:-unknown}"
cmd_safe=$(printf '%s' "$*" | tr '\\"' '__' | head -c 200)

printf '{"ts":"%s","session":"%s","plugin":"%s","event":"%s","duration_ms":%d,"exit_code":%d,"cmd":"%s"}\n' \
  "$ts" "$session" "$plugin" "$event" "$duration_ms" "$rc" "$cmd_safe" \
  >> "$LOG_FILE" 2>/dev/null || true

exit "$rc"
