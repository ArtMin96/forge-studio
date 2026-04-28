#!/usr/bin/env bash
# Forge Studio bootstrap.
#
# Adds the ArtMin96/forge-studio marketplace, installs all 17 plugins to
# user scope, and copies templates/CLAUDE.md to ~/.claude/CLAUDE.md
# (backing up any existing file).
#
# Idempotent. Safe to re-run.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MARKETPLACE_REPO="ArtMin96/forge-studio"
MARKETPLACE_NAME="forge-studio"
TEMPLATE_CLAUDE_MD="${SCRIPT_DIR}/templates/CLAUDE.md"
TARGET_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"

PLUGINS=(
  behavioral-core
  context-engine
  long-session
  memory
  evaluator
  workflow
  agents
  reference
  traces
  diagnostics
  caveman
  token-efficiency
  research-gate
  policy-gateway
  rtk-optimizer
  code-graph
  themes
)

log()  { printf "[install] %s\n" "$*"; }
warn() { printf "[install] WARN: %s\n" "$*" >&2; }
fail() { printf "[install] ERROR: %s\n" "$*" >&2; exit 1; }

# 1. Pre-flight
command -v claude >/dev/null 2>&1 || fail "claude CLI not found on PATH. Install Claude Code first: https://docs.anthropic.com/claude-code"
[ -f "$TEMPLATE_CLAUDE_MD" ] || fail "template not found: ${TEMPLATE_CLAUDE_MD} (run install.sh from a Forge Studio checkout)"

log "claude $(claude --version 2>/dev/null | awk '{print $1}') detected"

# 2. CLAUDE.md install
mkdir -p "${HOME}/.claude"
if [ -f "$TARGET_CLAUDE_MD" ]; then
  if cmp -s "$TEMPLATE_CLAUDE_MD" "$TARGET_CLAUDE_MD"; then
    log "CLAUDE.md already matches template, skipping copy"
  else
    BACKUP="${TARGET_CLAUDE_MD}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$TARGET_CLAUDE_MD" "$BACKUP"
    log "backed up existing CLAUDE.md -> ${BACKUP}"
    cp "$TEMPLATE_CLAUDE_MD" "$TARGET_CLAUDE_MD"
    log "installed templates/CLAUDE.md -> ${TARGET_CLAUDE_MD}"
  fi
else
  cp "$TEMPLATE_CLAUDE_MD" "$TARGET_CLAUDE_MD"
  log "installed templates/CLAUDE.md -> ${TARGET_CLAUDE_MD}"
fi

# 3. Marketplace registration (idempotent at the CLI level)
log "registering marketplace ${MARKETPLACE_REPO}"
if ! claude plugin marketplace add "$MARKETPLACE_REPO"; then
  fail "marketplace add failed for ${MARKETPLACE_REPO}"
fi

# 4. Plugin install loop
TOTAL=${#PLUGINS[@]}
OK=0
FAIL=0
FAILED_PLUGINS=()

log "installing ${TOTAL} plugins to user scope"
for name in "${PLUGINS[@]}"; do
  if claude plugin install "${name}@${MARKETPLACE_NAME}" --scope user; then
    OK=$((OK + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_PLUGINS+=("$name")
    warn "install failed: ${name}@${MARKETPLACE_NAME}"
  fi
done

# 5. Summary
echo
log "summary: ${OK}/${TOTAL} plugins installed (or already present)"
if [ "$FAIL" -gt 0 ]; then
  warn "${FAIL} failed: ${FAILED_PLUGINS[*]}"
  exit 1
fi

log "done. Start a new Claude Code session, or run /reload-plugins in an existing one, for plugins to load."
