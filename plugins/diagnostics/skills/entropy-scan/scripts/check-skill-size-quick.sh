#!/usr/bin/env bash
set -u
find plugins -name "SKILL.md" -exec sh -c '
  chars=$(wc -c < "$1")
  tokens=$((chars / 4))
  if [ "$tokens" -gt 2000 ]; then
    echo "OVERSIZED: $1 (~${tokens} tokens)"
  fi
' _ {} \;
