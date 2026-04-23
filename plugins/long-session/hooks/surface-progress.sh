#!/usr/bin/env bash
# SessionStart: surface long-session state so a fresh session picks up where the
# previous one left off. Reads claude-progress.txt (append-only log), spec.md,
# features.json status, and notes init.sh presence.
#
# Silent when nothing exists. Never blocks.

set -u

# Only act in a real repo. Bail quietly otherwise.
if [ ! -d .git ] && [ ! -f package.json ] && [ ! -f composer.json ] && [ ! -f pyproject.toml ] && [ ! -f Cargo.toml ] && [ ! -f go.mod ]; then
  exit 0
fi

PROGRESS_FILE="claude-progress.txt"
SPEC_FILE=".claude/spec.md"
FEATURES_FILE=".claude/features.json"
INIT_SCRIPT="init.sh"

ANY=0
OUT=""

# 1. Tail of progress log (last 3 entries). Entries are separated by blank lines.
if [ -f "$PROGRESS_FILE" ]; then
  TAIL=$(awk 'BEGIN{RS=""} {entries[NR]=$0} END{start=NR-2; if(start<1)start=1; for(i=start;i<=NR;i++) print entries[i] "\n"}' "$PROGRESS_FILE" 2>/dev/null)
  if [ -n "$TAIL" ]; then
    OUT="${OUT}[long-session] Recent progress (${PROGRESS_FILE}):\n${TAIL}\n"
    ANY=1
  fi
fi

# 2. Features.json status summary (pending / in_progress / done counts).
if [ -f "$FEATURES_FILE" ] && command -v jq >/dev/null 2>&1; then
  SUMMARY=$(jq -r '[.[] | .status] | group_by(.) | map({k: .[0], v: length}) | map("\(.k)=\(.v)") | join(" ")' "$FEATURES_FILE" 2>/dev/null)
  if [ -n "$SUMMARY" ] && [ "$SUMMARY" != "null" ]; then
    OUT="${OUT}[long-session] Features: ${SUMMARY}\n"
    ANY=1
  fi
fi

# 3. Last spec delta (tail 15 lines of spec.md).
if [ -f "$SPEC_FILE" ]; then
  DELTA=$(tail -n 15 "$SPEC_FILE" 2>/dev/null)
  if [ -n "$DELTA" ]; then
    OUT="${OUT}[long-session] spec.md tail:\n${DELTA}\n"
    ANY=1
  fi
fi

# 4. init.sh presence hint.
if [ -f "$INIT_SCRIPT" ] && [ -x "$INIT_SCRIPT" ]; then
  OUT="${OUT}[long-session] init.sh present — run \`bash ${INIT_SCRIPT}\` to bootstrap the dev env.\n"
  ANY=1
fi

if [ "$ANY" = "1" ]; then
  printf "%b" "$OUT"
fi

exit 0
