#!/usr/bin/env bash
# Forge Studio bootstrap.
#
# Adds the ArtMin96/forge-studio marketplace, installs all 21 plugins to
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
TEMPLATE_STATUSLINE="${SCRIPT_DIR}/templates/statusline.sh"
TARGET_STATUSLINE="${HOME}/.claude/statusline.sh"

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
  humanizer
  token-efficiency
  research-gate
  policy-gateway
  rtk-optimizer
  code-graph
  themes
  cross-repo
  forge-meta
  stack-flow
)

# Colour palette — empty when stdout is not a TTY (CI, piped to file, etc.).
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

PLUGIN_NAME_WIDTH=18
TOTAL_PLUGINS=${#PLUGINS[@]}

banner() {
  printf "\n"
  printf "  %s%sForge Studio%s   %sharness marketplace for Claude Code%s\n" \
    "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf "  %s21 plugins, 88 skills, 79 hooks%s\n\n" "$C_DIM" "$C_RESET"
}

section() {
  printf "%s==>%s %s%s%s\n" "$C_BLUE" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
}

info() { printf "    %s\n" "$*"; }
ok()   { printf "    %sok%s    %s\n" "$C_GREEN" "$C_RESET" "$*"; }
skip() { printf "    %sskip%s  %s\n" "$C_DIM" "$C_RESET" "$*"; }
warn() { printf "    %swarn%s  %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf "    %sfail%s  %s\n" "$C_RED" "$C_RESET" "$*" >&2; }

fail() {
  printf "\n%sError:%s %s\n\n" "$C_RED$C_BOLD" "$C_RESET" "$*" >&2
  exit 1
}

step_line() {
  # $1 = index, $2 = total, $3 = status (running|ok|skip|fail), $4 = plugin
  local idx="$1" total="$2" status="$3" plugin="$4" colour symbol
  case "$status" in
    running) colour="$C_DIM";    symbol="..."  ;;
    ok)      colour="$C_GREEN";  symbol="ok"   ;;
    skip)    colour="$C_DIM";    symbol="skip" ;;
    fail)    colour="$C_RED";    symbol="fail" ;;
  esac
  printf "    [%2d/%2d] %s%-4s%s  %-${PLUGIN_NAME_WIDTH}s\n" \
    "$idx" "$total" "$colour" "$symbol" "$C_RESET" "$plugin"
}

# 1. Pre-flight
banner
section "Pre-flight"

if ! command -v claude >/dev/null 2>&1; then
  fail "claude CLI not found on PATH. Install Claude Code first: https://docs.anthropic.com/claude-code"
fi
[ -f "$TEMPLATE_CLAUDE_MD" ] || fail "template not found: ${TEMPLATE_CLAUDE_MD} (run install.sh from a Forge Studio checkout)"

CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $1}')
ok "claude CLI detected${CLAUDE_VER:+ (${CLAUDE_VER})}"
ok "template located at ${C_DIM}${TEMPLATE_CLAUDE_MD/#$HOME/~}${C_RESET}"

# Cross-plugin shared resources: ${CLAUDE_PLUGIN_ROOT}/../<other-plugin>/... is
# forbidden (Anthropic strips sibling content from the cache). Each consumer
# plugin gets a symlink inside its own directory pointing at the shared target;
# the installer dereferences the symlink and copies the content into each
# plugin's cache. Re-asserted on every run for fresh checkouts and hosts where
# symlinks were stripped.
declare -A SHARED_TARGETS=(
  [_lib]="../_lib"
  [diagnostics-lib]="../diagnostics/lib"
  [workflow-orchestrate]="../workflow/skills/orchestrate"
)
declare -A SHARED_CONSUMERS=(
  [_lib]="workflow traces context-engine policy-gateway"
  [diagnostics-lib]="behavioral-core caveman code-graph context-engine long-session rtk-optimizer workflow"
  [workflow-orchestrate]="agents evaluator"
)
SHARED_LINKED=0
SHARED_TOTAL=0
for link_name in "${!SHARED_TARGETS[@]}"; do
  target_rel="${SHARED_TARGETS[$link_name]}"
  source_path="${SCRIPT_DIR}/plugins/${target_rel#../}"
  [ -d "$source_path" ] || fail "shared resource not found at ${source_path} (run install.sh from a Forge Studio checkout)"
  for p in ${SHARED_CONSUMERS[$link_name]}; do
    [ -d "${SCRIPT_DIR}/plugins/${p}" ] || continue
    SHARED_TOTAL=$((SHARED_TOTAL + 1))
    target="${SCRIPT_DIR}/plugins/${p}/${link_name}"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$target_rel" ]; then
      continue
    fi
    rm -rf "$target"
    ln -s "$target_rel" "$target"
    SHARED_LINKED=$((SHARED_LINKED + 1))
  done
done
if [ "$SHARED_LINKED" -gt 0 ]; then
  ok "shared resources: linked ${SHARED_LINKED}/${SHARED_TOTAL} symlinks across ${#SHARED_TARGETS[@]} targets"
else
  ok "shared resources: ${SHARED_TOTAL} symlinks present across ${#SHARED_TARGETS[@]} targets"
fi
printf "\n"

# 2. CLAUDE.md install
section "User CLAUDE.md"
mkdir -p "${HOME}/.claude"
if [ -f "$TARGET_CLAUDE_MD" ]; then
  if cmp -s "$TEMPLATE_CLAUDE_MD" "$TARGET_CLAUDE_MD"; then
    skip "${TARGET_CLAUDE_MD/#$HOME/~} already matches template"
  else
    BACKUP="${TARGET_CLAUDE_MD}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$TARGET_CLAUDE_MD" "$BACKUP"
    info "backup -> ${C_DIM}${BACKUP/#$HOME/~}${C_RESET}"
    cp "$TEMPLATE_CLAUDE_MD" "$TARGET_CLAUDE_MD"
    ok "installed -> ${TARGET_CLAUDE_MD/#$HOME/~}"
  fi
else
  cp "$TEMPLATE_CLAUDE_MD" "$TARGET_CLAUDE_MD"
  ok "installed -> ${TARGET_CLAUDE_MD/#$HOME/~}"
fi
printf "\n"

section "User statusline"
if [ -f "$TARGET_STATUSLINE" ]; then
  if cmp -s "$TEMPLATE_STATUSLINE" "$TARGET_STATUSLINE"; then
    skip "${TARGET_STATUSLINE/#$HOME/~} already matches template"
  else
    BACKUP="${TARGET_STATUSLINE}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$TARGET_STATUSLINE" "$BACKUP"
    info "backup -> ${C_DIM}${BACKUP/#$HOME/~}${C_RESET}"
    cp "$TEMPLATE_STATUSLINE" "$TARGET_STATUSLINE"
    chmod +x "$TARGET_STATUSLINE"
    ok "installed -> ${TARGET_STATUSLINE/#$HOME/~}"
  fi
else
  cp "$TEMPLATE_STATUSLINE" "$TARGET_STATUSLINE"
  chmod +x "$TARGET_STATUSLINE"
  ok "installed -> ${TARGET_STATUSLINE/#$HOME/~}"
fi
printf "\n"

# 3. Marketplace registration
section "Marketplace"
info "registering ${C_BOLD}${MARKETPLACE_REPO}${C_RESET}"
MARKETPLACE_LOG=$(mktemp)
trap 'rm -f "$MARKETPLACE_LOG" "$INSTALL_LOG"' EXIT
if claude plugin marketplace add "$MARKETPLACE_REPO" >"$MARKETPLACE_LOG" 2>&1; then
  ok "marketplace ready"
else
  err "marketplace registration failed"
  sed 's/^/      /' "$MARKETPLACE_LOG" >&2
  fail "see error above"
fi
printf "\n"

# 4. Plugin install loop
section "Plugins (${TOTAL_PLUGINS})"
INSTALL_LOG=$(mktemp)
OK=0
FAIL=0
FAILED_PLUGINS=()
START_TS=$(date +%s)

idx=0
for name in "${PLUGINS[@]}"; do
  idx=$((idx + 1))
  if claude plugin install "${name}@${MARKETPLACE_NAME}" --scope user >"$INSTALL_LOG" 2>&1; then
    step_line "$idx" "$TOTAL_PLUGINS" "ok" "$name"
    OK=$((OK + 1))
  else
    step_line "$idx" "$TOTAL_PLUGINS" "fail" "$name"
    FAIL=$((FAIL + 1))
    FAILED_PLUGINS+=("$name")
    sed 's/^/             /' "$INSTALL_LOG" >&2
  fi
done

ELAPSED=$(( $(date +%s) - START_TS ))
printf "\n"

# 4b. Cross-vendor .agents/skills/ symlinks (POSIX only)
# Symlink source is the clone itself — stable across Claude Code version bumps.
# Cache paths (~/.claude/plugins/cache/...) are volatile and must not be used.
case "$(uname)" in
  Linux|Darwin)
    section "Cross-vendor skills"
    mkdir -p "${HOME}/.agents/skills"
    LINKED=0
    for skill_dir in "${SCRIPT_DIR}"/plugins/*/skills/*/; do
      skill_name=$(basename "$skill_dir")
      ln -sfn "$skill_dir" "${HOME}/.agents/skills/${skill_name}"
      LINKED=$((LINKED + 1))
    done
    info "Cross-vendor: linked ${LINKED} skills under ~/.agents/skills/ (from clone at ${SCRIPT_DIR})"
    printf "\n"
    ;;
  *)
    warn "POSIX symlinks unavailable; skipping ~/.agents/skills/ cross-vendor surface"
    ;;
esac

# 5. Summary
section "Summary"
if [ "$FAIL" -eq 0 ]; then
  printf "    %s%d/%d%s plugins installed " "$C_GREEN$C_BOLD" "$OK" "$TOTAL_PLUGINS" "$C_RESET"
  printf "%s(%ds)%s\n" "$C_DIM" "$ELAPSED" "$C_RESET"
  printf "\n"
  printf "  %sNext:%s start a fresh Claude Code session, or run %s/reload-plugins%s in an existing one.\n" \
    "$C_BOLD" "$C_RESET" "$C_CYAN" "$C_RESET"
  printf "        run %s/healthcheck%s once loaded to verify everything is wired up.\n\n" "$C_CYAN" "$C_RESET"
  exit 0
else
  printf "    %s%d/%d%s installed, %s%d failed%s %s(%ds)%s\n\n" \
    "$C_GREEN" "$OK" "$TOTAL_PLUGINS" "$C_RESET" "$C_RED$C_BOLD" "$FAIL" "$C_RESET" \
    "$C_DIM" "$ELAPSED" "$C_RESET"
  warn "failed: ${FAILED_PLUGINS[*]}"
  printf "\n  Re-run %s./install.sh%s to retry. Stale auth or rate limits often resolve themselves on retry.\n\n" \
    "$C_CYAN" "$C_RESET"
  exit 1
fi
