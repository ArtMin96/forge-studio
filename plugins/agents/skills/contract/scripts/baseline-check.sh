#!/usr/bin/env bash
# Reads a plan file and checks each assertion against HEAD.
#
# Assertion families recognised (backtick-anchored to avoid prose false-positives):
# Pattern: `<path>` is <N> lines
# Pattern: `<path>` has empty <field>:
# Form: `<path>:<line>`
# Form: <path/to/SKILL.md> frontmatter parses
#
# Exit codes: 0 = all match, 1 = at least one mismatch, 2 = plan not found.

set -euo pipefail

PLAN="$1"

if [ ! -f "$PLAN" ]; then
  printf '{"error":"plan not found"}\n'
  exit 2
fi

checked=0
mismatched_json="[]"

add_mismatch() {
  local assertion="$1" file="$2" expected="$3" actual="$4"
  mismatched_json=$(printf '%s' "$mismatched_json" | jq \
    --arg a "$assertion" --arg f "$file" --arg e "$expected" --arg v "$actual" \
    '. + [{"assertion":$a,"file":$f,"expected":$e,"actual":$v}]')
}

while IFS= read -r line; do

  # Pattern: `<path>` is <N> lines
  if echo "$line" | grep -qE '`[^`]+`[[:space:]]+is[[:space:]]+[0-9]+[[:space:]]+lines'; then
    fpath=$(echo "$line" | grep -oE '`[^`]+`[[:space:]]+is[[:space:]]+[0-9]+[[:space:]]+lines' | head -1 | sed 's/`\([^`]*\)`.*/\1/')
    expected=$(echo "$line" | grep -oE '`[^`]+`[[:space:]]+is[[:space:]]+([0-9]+)[[:space:]]+lines' | grep -oE '[0-9]+[[:space:]]+lines' | grep -oE '^[0-9]+')
    checked=$((checked + 1))
    if [ ! -f "$fpath" ]; then
      add_mismatch "$line" "$fpath" "$expected" "FILE_NOT_FOUND"
    else
      actual=$(wc -l < "$fpath" | tr -d ' ')
      if [ "$actual" != "$expected" ]; then
        add_mismatch "$line" "$fpath" "$expected" "$actual"
      fi
    fi
  fi

  # Pattern: `<path>` has empty <field>:
  if echo "$line" | grep -qE '`[^`]+`[[:space:]]+has[[:space:]]+empty[[:space:]]+[a-zA-Z_-]+:'; then
    fpath=$(echo "$line" | grep -oE '`[^`]+`[[:space:]]+has[[:space:]]+empty' | sed 's/`\([^`]*\)`.*/\1/')
    field=$(echo "$line" | grep -oE 'has[[:space:]]+empty[[:space:]]+([a-zA-Z_-]+):' | sed 's/has[[:space:]]*empty[[:space:]]*//' | sed 's/://')
    checked=$((checked + 1))
    if [ ! -f "$fpath" ]; then
      add_mismatch "$line" "$fpath" "empty $field" "FILE_NOT_FOUND"
    else
      # Check if YAML frontmatter field is absent, empty, or []
      actual=$(python3 - "$fpath" "$field" <<'PYEOF'
import sys, yaml
path, field = sys.argv[1], sys.argv[2]
content = open(path).read()
parts = content.split('---')
if len(parts) < 3:
    print("NO_FRONTMATTER")
    sys.exit(0)
fm = yaml.safe_load(parts[1]) or {}
val = fm.get(field)
if val is None or val == '' or val == [] or val == {}:
    print("empty")
else:
    print(repr(val))
PYEOF
)
      if [ "$actual" != "empty" ]; then
        add_mismatch "$line" "$fpath" "empty $field" "$actual"
      fi
    fi
  fi

  # Form: `<path>:<line>`  — path has at least <line> lines
  if echo "$line" | grep -qE '`[^`:]+:[0-9]+`'; then
    match=$(echo "$line" | grep -oE '`[^`:]+:[0-9]+`' | head -1)
    fpath=$(echo "$match" | sed 's/`\([^:]*\):[0-9]*`/\1/')
    expected_line=$(echo "$match" | sed 's/`[^:]*:\([0-9]*\)`/\1/')
    checked=$((checked + 1))
    if [ ! -f "$fpath" ]; then
      add_mismatch "$line" "$fpath" ">= $expected_line lines" "FILE_NOT_FOUND"
    else
      actual=$(wc -l < "$fpath" | tr -d ' ')
      if [ "$actual" -lt "$expected_line" ]; then
        add_mismatch "$line" "$fpath" ">= $expected_line lines" "$actual"
      fi
    fi
  fi

  # Form: <path/to/SKILL.md> frontmatter parses
  # Path may appear with or without backtick-quoting in plan text.
  # A missing file is counted but not recorded as a mismatch — drift is only meaningful when the file exists.
  if echo "$line" | grep -qE '[a-zA-Z0-9_./-]+/SKILL\.md[[:space:]]+frontmatter[[:space:]]+parses'; then
    fpath=$(echo "$line" | grep -oE '[a-zA-Z0-9_./-]+/SKILL\.md' | head -1 | tr -d '`')
    checked=$((checked + 1))
    if [ -f "$fpath" ]; then
      if ! python3 -c "
import yaml, sys
content = open('$fpath').read()
parts = content.split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
        add_mismatch "$line" "$fpath" "frontmatter parses" "PARSE_ERROR"
      fi
    fi
  fi

done < "$PLAN"

mismatch_count=$(printf '%s' "$mismatched_json" | jq 'length')
printf '%s' "$mismatched_json" | jq -n \
  --argjson checked "$checked" \
  --argjson mismatched "$mismatched_json" \
  '{"checked":$checked,"mismatched":$mismatched}'

if [ "$mismatch_count" -eq 0 ]; then
  exit 0
else
  exit 1
fi
