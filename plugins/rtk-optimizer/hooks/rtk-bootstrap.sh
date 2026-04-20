#!/usr/bin/env bash
# rtk-optimizer: auto-install rtk-ai/rtk and register its global Bash rewrite hook.
#
# First session: downloads rtk via `curl | sh` from rtk-ai/rtk master and runs
# `rtk init -g` to write a PreToolUse hook into ~/.claude/settings.json.
# Subsequent sessions: fast path, no network, no writes.
#
# Opt-out: export FORGE_RTK_DISABLED=1
#
# Caveats:
# - Pipes curl output to sh on first run. Upstream compromise = code execution.
# - `rtk init -g` mutates ~/.claude/settings.json. Uninstalling this plugin does
#   NOT remove that hook — run `rtk init -g --uninstall` manually if needed.
# - Always exits 0 so session startup never fails.

set -u

[ "${FORGE_RTK_DISABLED:-0}" = "1" ] && exit 0

SESSION_MARKER="/tmp/forge-rtk-${CLAUDE_SESSION_ID:-$$}"
[ -f "$SESSION_MARKER" ] && exit 0
touch "$SESSION_MARKER" 2>/dev/null || true

export PATH="$HOME/.local/bin:$PATH"

STATE_DIR="$HOME/.local/share/rtk"
INIT_MARKER="$STATE_DIR/.forge-studio-initialized"

if [ -f "$INIT_MARKER" ] && command -v rtk >/dev/null 2>&1; then
  exit 0
fi

if ! command -v rtk >/dev/null 2>&1; then
  if ! curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh >/dev/null 2>&1; then
    echo "rtk-optimizer: install failed (network?). Retry next session or set FORGE_RTK_DISABLED=1 to silence." >&2
    exit 0
  fi
  export PATH="$HOME/.local/bin:$PATH"
fi

if command -v rtk >/dev/null 2>&1; then
  rtk init -g --auto-patch >/dev/null 2>&1 || echo "rtk-optimizer: 'rtk init -g --auto-patch' failed; run it manually to activate." >&2
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  touch "$INIT_MARKER" 2>/dev/null || true
fi

exit 0
