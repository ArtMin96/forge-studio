#!/usr/bin/env bash
set -u
for f in plugins/behavioral-core/hooks/rules.d/*.txt; do
  [ -f "$f" ] || continue
  first=$(grep -m1 -v '^\s*$' "$f" 2>/dev/null)
  case "$first" in
    \#\ origin:*) ;;
    *) echo "UNPROVENANCED: $f" ;;
  esac
done
