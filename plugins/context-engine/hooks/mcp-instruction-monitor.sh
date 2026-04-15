#!/usr/bin/env bash
# Context Engine: MCP server impact monitoring.
# Each MCP server adds ~500-2000 tokens to the system prompt AND
# busts the prompt cache on connect/disconnect (Claude Code marks
# MCP instructions as DANGEROUS_uncachedSystemPromptSection).
# This hook warns at session start if MCP overhead is significant.

set -o pipefail

MARKER="/tmp/claude-mcp-monitor-${CLAUDE_SESSION_ID:-$$}"

# Only run once per session
if [[ -f "$MARKER" ]]; then
  exit 0
fi
touch "$MARKER"

MCP_COUNT=0

# Check user and project settings for mcpServers
for SETTINGS_FILE in "$HOME/.claude/settings.json" ".claude/settings.json" ".claude/settings.local.json"; do
  if [[ -f "$SETTINGS_FILE" ]]; then
    FILE_MCP=$(python3 -c "
import json
try:
    d = json.load(open('$SETTINGS_FILE'))
    print(len(d.get('mcpServers', {})))
except: print(0)
" 2>/dev/null)
    MCP_COUNT=$((MCP_COUNT + ${FILE_MCP:-0}))
  fi
done

# Check plugin-provided MCP servers (.mcp.json files in plugin cache)
PLUGIN_CACHE="$HOME/.claude/plugins/cache"
if [[ -d "$PLUGIN_CACHE" ]]; then
  PLUGIN_MCP=$(find "$PLUGIN_CACHE" -name ".mcp.json" -not -path "*/.orphaned_at*" 2>/dev/null | while read -r mcpfile; do
    # Skip orphaned plugins
    DIR=$(dirname "$mcpfile")
    [[ -f "$DIR/.orphaned_at" ]] && continue
    python3 -c "
import json
try:
    d = json.load(open('$mcpfile'))
    print(len(d))
except: print(0)
" 2>/dev/null
  done | awk '{s+=$1} END {print s+0}')
  MCP_COUNT=$((MCP_COUNT + ${PLUGIN_MCP:-0}))
fi

WARN_THRESHOLD=${FORGE_MCP_WARN_THRESHOLD:-2}

if [[ "$MCP_COUNT" -gt "$WARN_THRESHOLD" ]]; then
  echo "MCP overhead: ${MCP_COUNT} servers configured (~$((MCP_COUNT * 1000)) tokens added to system prompt). Each server connect/disconnect busts the prompt cache. Consider disabling unused MCP servers."
elif [[ "$MCP_COUNT" -gt 0 ]]; then
  echo "MCP servers: ${MCP_COUNT} configured."
fi

exit 0
