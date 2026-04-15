#!/usr/bin/env bash
# SessionStart: One-time output style safety check.
# Warns if any configured output style suppresses coding instructions.

SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$(pwd)-$(date +%Y%m%d)" | md5sum | cut -c1-8)}"
TRACKDIR="${CLAUDE_PLUGIN_DATA:-/tmp/claude-self-review}/${SESSION_ID}"
MARKER="${TRACKDIR}/output-style-check-ran"

# Already ran this session — exit silently
if [[ -f "$MARKER" ]]; then
  exit 0
fi

# Create marker before doing any work so we don't fire twice even on error
mkdir -p "$TRACKDIR"
touch "$MARKER"

check_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    return
  fi
  # Match either JSON key form of the setting
  if grep -qE '"keep-coding-instructions"\s*:\s*false|"keepCodingInstructions"\s*:\s*false' "$path" 2>/dev/null; then
    echo "Output style warning: $path has keep-coding-instructions: false. Core software engineering guidance is suppressed."
  fi
}

check_file "${HOME}/.claude/settings.json"
check_file ".claude/settings.json"

exit 0
