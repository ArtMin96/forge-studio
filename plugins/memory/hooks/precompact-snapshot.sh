#!/usr/bin/env bash
# PreCompact: snapshot the most recent user corrections to disk so behavioral
# feedback survives compaction. SessionStart picks the file up via the
# long-session surface-progress.sh tail.
#
# Disable: FORGE_PRECOMPACT_SNAPSHOT=0

set -u

if [ "${FORGE_PRECOMPACT_SNAPSHOT:-1}" = "0" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Resolve project root: prefer CLAUDE_PROJECT_DIR (set by Claude Code), fall back
# to git common dir's parent (handles worktrees correctly), fall back to pwd.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  COMMON=$(git rev-parse --git-common-dir 2>/dev/null || true)
  if [ -n "$COMMON" ]; then
    PROJECT_DIR=$(dirname "$(cd "$COMMON" 2>/dev/null && pwd)")
  fi
fi
[ -z "$PROJECT_DIR" ] && PROJECT_DIR=$(pwd)

SLUG=$(echo "$PROJECT_DIR" | sed 's|/|-|g; s|^-||')
OUTDIR="${HOME}/.claude/projects/-${SLUG}/memory"
mkdir -p "$OUTDIR" 2>/dev/null || exit 0

OUT="${OUTDIR}/.precompact-feedback.txt"

# Reverse transcript lines portably (tac is GNU-only).
reverse_lines() {
  awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$1"
}

# Pull the last 10 user turns whose first text content begins with a correction
# verb. Compressed format: "<TS> <first 200 chars>"
{
  printf '# Pre-compact behavioral feedback snapshot — %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  reverse_lines "$TRANSCRIPT" 2>/dev/null \
    | jq -rc 'select(.type=="user") | (.timestamp // "?") + " " + (.message.content[0].text // "" | tostring)' 2>/dev/null \
    | grep -iE '^[^[:space:]]+[[:space:]]+(no|stop|don.?t|actually|wait|you.?re wrong|that.?s not|this is wrong|undo|revert)\>' \
    | head -10 \
    | sed 's/\(.\{200\}\).*/\1.../'
} > "$OUT" 2>/dev/null

# Bound file size at 50 lines.
if [ -f "$OUT" ]; then
  head -50 "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
fi

exit 0
