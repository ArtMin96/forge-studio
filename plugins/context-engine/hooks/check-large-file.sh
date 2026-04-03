#!/usr/bin/env bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi
LINES=$(wc -l < "$FILE_PATH")
if [[ $LINES -gt 500 ]]; then
  echo "Large file read (>500 lines). Extract what you need — details may be lost during compaction."
fi
