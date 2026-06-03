#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi
THRESHOLD=${FORGE_LARGE_FILE_LINES:-1200}
LINES=$(wc -l < "$FILE_PATH")
if [[ $LINES -gt $THRESHOLD ]]; then
  echo "[context-engine] Large file read (>${THRESHOLD} lines). Extract what you need — details may be lost during compaction."
fi

exit 0
