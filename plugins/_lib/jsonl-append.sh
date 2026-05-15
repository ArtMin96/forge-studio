#!/usr/bin/env bash
# Append one JSON line to a JSONL ledger under exclusive flock.
#
# Bare `>>` is line-atomic only when the write fits PIPE_BUF (4 KiB on Linux);
# longer payloads (e.g. injection-scan ledger entries) can interleave when
# concurrent hooks fire on the same file. flock serializes writers across
# processes; lock file is `${ledger}.lock` (zero bytes, sized 0).
#
# Contract: jsonl-append.sh <ledger-path> <json-line>
# Always exits 0. Logging helpers must never block a hook past its budget.

set -euo pipefail

LEDGER="${1:-}"
LINE="${2:-}"

if [ -z "$LEDGER" ] || [ -z "$LINE" ]; then
  echo "jsonl-append: usage: jsonl-append.sh <ledger-path> <json-line>" >&2
  exit 0
fi

mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true

# macOS without util-linux ships no flock; fall back to bare append so the
# helper still works (correctness-degraded under contention, but functional).
if command -v flock >/dev/null 2>&1; then
  LOCKFILE="${LEDGER}.lock"
  (
    flock -x -w 2 200 || true
    printf '%s\n' "$LINE" >> "$LEDGER" 2>/dev/null || true
  ) 200>"$LOCKFILE" 2>/dev/null || true
else
  printf '%s\n' "$LINE" >> "$LEDGER" 2>/dev/null || true
fi

exit 0
