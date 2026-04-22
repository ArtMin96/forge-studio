#!/usr/bin/env bash
# Context Engine: MCP server impact monitoring.
# Each MCP server adds ~500-2000 tokens to the system prompt AND
# busts the prompt cache on connect/disconnect (Claude Code marks
# MCP instructions as DANGEROUS_uncachedSystemPromptSection).
# This hook warns at session start if MCP overhead is significant or
# if any configured server's config contains suspicious patterns that
# could indicate prompt-injection or untrusted code execution.
# Opt-out injection scan: FORGE_MCP_INJECTION_SCAN=0.

set -o pipefail

MARKER="/tmp/claude-mcp-monitor-${CLAUDE_SESSION_ID:-$$}"

# Only run once per session
if [[ -f "$MARKER" ]]; then
  exit 0
fi
touch "$MARKER"

MCP_COUNT=0
CONFIG_FILES=()

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
    [[ "${FILE_MCP:-0}" -gt 0 ]] && CONFIG_FILES+=("$SETTINGS_FILE")
  fi
done

# Check plugin-provided MCP servers (.mcp.json files in plugin cache)
PLUGIN_CACHE="$HOME/.claude/plugins/cache"
if [[ -d "$PLUGIN_CACHE" ]]; then
  while IFS= read -r mcpfile; do
    # Skip orphaned plugins
    DIR=$(dirname "$mcpfile")
    [[ -f "$DIR/.orphaned_at" ]] && continue
    COUNT=$(python3 -c "
import json
try:
    d = json.load(open('$mcpfile'))
    print(len(d))
except: print(0)
" 2>/dev/null)
    MCP_COUNT=$((MCP_COUNT + ${COUNT:-0}))
    [[ "${COUNT:-0}" -gt 0 ]] && CONFIG_FILES+=("$mcpfile")
  done < <(find "$PLUGIN_CACHE" -name ".mcp.json" -not -path "*/.orphaned_at*" 2>/dev/null)
fi

WARN_THRESHOLD=${FORGE_MCP_WARN_THRESHOLD:-2}

if [[ "$MCP_COUNT" -gt "$WARN_THRESHOLD" ]]; then
  echo "MCP overhead: ${MCP_COUNT} servers configured (~$((MCP_COUNT * 1000)) tokens added to system prompt). Each server connect/disconnect busts the prompt cache. Consider disabling unused MCP servers."
elif [[ "$MCP_COUNT" -gt 0 ]]; then
  echo "MCP servers: ${MCP_COUNT} configured."
fi

# Injection / untrusted-config scan.
# The SessionStart hook cannot see runtime instruction text (servers
# haven't been queried yet), but it CAN inspect the config JSON itself
# for patterns that indicate sketchy execution or literal injection
# strings that a config author shouldn't need to embed.
if [[ "${FORGE_MCP_INJECTION_SCAN:-1}" != "0" ]] && [[ ${#CONFIG_FILES[@]} -gt 0 ]]; then
  FINDINGS=$(python3 - "${CONFIG_FILES[@]}" <<'PY' 2>/dev/null
import json, re, sys

EXEC_PATTERNS = [
    (re.compile(r'curl\s+[^|]*\|\s*(sh|bash|zsh)', re.I), 'pipes curl to shell'),
    (re.compile(r'wget\s+[^|]*\|\s*(sh|bash|zsh)', re.I), 'pipes wget to shell'),
    (re.compile(r'\beval\s*\(?\s*[\'"`]?\$', re.I), 'uses eval on variable'),
    (re.compile(r'base64\s+(-d|--decode)', re.I), 'decodes base64'),
    (re.compile(r'\bpython3?\s+-c\s+[\'"][^\'"]*exec', re.I), 'python -c with exec'),
]
INJ_PATTERNS = [
    (re.compile(r'ignore\s+(all\s+)?(previous|prior|above)\s+(instructions|messages|rules)', re.I), 'prompt-injection phrase ("ignore previous")'),
    (re.compile(r'disregard\s+(all\s+)?(previous|prior|above)', re.I), 'prompt-injection phrase ("disregard previous")'),
    (re.compile(r'you\s+are\s+now\s+(a|an)\s+', re.I), 'role-replacement phrase ("you are now")'),
    (re.compile(r'\bSYSTEM\s*PROMPT\s*[:=]', re.I), 'literal SYSTEM PROMPT marker'),
    (re.compile(r'new\s+role\s*[:=]', re.I), 'role-replacement phrase ("new role:")'),
]

# Walk any JSON value, stringify, and search.
def walk(v, acc):
    if isinstance(v, str):
        acc.append(v)
    elif isinstance(v, dict):
        for x in v.values(): walk(x, acc)
    elif isinstance(v, list):
        for x in v: walk(x, acc)

findings = []
for path in sys.argv[1:]:
    try:
        data = json.load(open(path))
    except Exception:
        continue
    servers = data.get('mcpServers', data) if isinstance(data, dict) else {}
    if not isinstance(servers, dict):
        continue
    for name, cfg in servers.items():
        if not isinstance(cfg, dict):
            continue
        strings = []
        walk(cfg, strings)
        blob = '\n'.join(strings)
        hits = []
        for pat, label in EXEC_PATTERNS:
            if pat.search(blob):
                hits.append(label)
        for pat, label in INJ_PATTERNS:
            if pat.search(blob):
                hits.append(label)
        if hits:
            findings.append((path, name, sorted(set(hits))))

for path, name, hits in findings:
    print(f"  - {name} ({path}): {', '.join(hits)}")
PY
  )
  if [[ -n "$FINDINGS" ]]; then
    echo "MCP config scan flagged suspicious content:"
    echo "$FINDINGS"
    echo "  Review these servers. Prompt-injection or shell-exec patterns in MCP config can compromise the agent. Disable via FORGE_MCP_INJECTION_SCAN=0."
  fi
fi

exit 0
