#!/usr/bin/env bash
set -euo pipefail
# Rotate a ledger file when it exceeds entry-count or byte-size thresholds.
# Usage: rotate.sh <ledger-path>
# Env:
#   FORGE_LEDGER_MAX_ENTRIES  (default 2000)
#   FORGE_LEDGER_MAX_BYTES    (default 1048576 = 1 MiB)
#
# If neither threshold is exceeded, exits 0 silently.
# If the file does not exist, exits 0 silently.
# When a threshold is exceeded, moves the file to
#   .claude/evolution/archive/<basename>-<iso-date>-<unix-epoch>.jsonl
# The caller's next append will recreate the live file from scratch.

if [[ $# -lt 1 ]]; then
  echo "Usage: rotate.sh <ledger-path>" >&2
  exit 1
fi

LEDGER_PATH="$1"

# Resolve the ledger path relative to the repo root when not absolute.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If CLAUDE_PROJECT_DIR is set, use it as the repo root; otherwise walk up from
# this script (change-manifest/scripts → change-manifest → skills → forge-meta →
# plugins → repo-root).
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  REPO_ROOT="$CLAUDE_PROJECT_DIR"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Resolve to absolute path when relative.
if [[ "$LEDGER_PATH" != /* ]]; then
  LEDGER_PATH="$REPO_ROOT/$LEDGER_PATH"
fi

# Nothing to rotate if the file does not exist.
[[ -f "$LEDGER_PATH" ]] || exit 0

MAX_ENTRIES="${FORGE_LEDGER_MAX_ENTRIES:-2000}"
MAX_BYTES="${FORGE_LEDGER_MAX_BYTES:-1048576}"

# Check byte size (portable: wc -c handles sparse files safely).
BYTE_SIZE=$(wc -c < "$LEDGER_PATH")
# Check entry count (one JSON object per line).
ENTRY_COUNT=$(wc -l < "$LEDGER_PATH")

if [[ "$BYTE_SIZE" -lt "$MAX_BYTES" && "$ENTRY_COUNT" -lt "$MAX_ENTRIES" ]]; then
  exit 0
fi

# At least one threshold exceeded — rotate.
ARCHIVE_DIR="$REPO_ROOT/.claude/evolution/archive"
mkdir -p "$ARCHIVE_DIR"

BASENAME="$(basename "$LEDGER_PATH" .jsonl)"
ISO_DATE="$(date -u +%Y-%m-%d)"
UNIX_EPOCH="$(date +%s)"

DEST="$ARCHIVE_DIR/${BASENAME}-${ISO_DATE}-${UNIX_EPOCH}.jsonl"
mv "$LEDGER_PATH" "$DEST"
