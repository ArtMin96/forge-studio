#!/usr/bin/env bash
# Context Engine: Environment bootstrapping.
# Gathers project environment snapshot at session start.
# Based on Meta-Harness paper (arXiv 2603.28052) finding that
# environment bootstrapping eliminates 2-4 wasted exploratory turns.
# Guarded by timeout — fails silently if environment can't be probed.

set -o pipefail

MARKER="/tmp/claude-env-bootstrap-${CLAUDE_SESSION_ID:-$$}"

# Only run once per session
if [[ -f "$MARKER" ]]; then
  exit 0
fi
touch "$MARKER"

OUTPUT=""

# Working directory
WD="$(pwd)"
OUTPUT+="[Environment Snapshot]"$'\n'
OUTPUT+="Working directory: ${WD}"$'\n'

# OS info
if [[ -f /etc/os-release ]]; then
  OS_NAME=$(. /etc/os-release && echo "${PRETTY_NAME:-$NAME}")
elif [[ "$(uname)" == "Darwin" ]]; then
  OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null)"
else
  OS_NAME=$(uname -s -r 2>/dev/null)
fi
OUTPUT+="OS: ${OS_NAME}"$'\n'

# Available memory
if command -v free >/dev/null 2>&1; then
  MEM=$(free -h 2>/dev/null | awk '/^Mem:/{print $2 " total, " $7 " available"}')
  [[ -n "$MEM" ]] && OUTPUT+="Memory: ${MEM}"$'\n'
elif [[ "$(uname)" == "Darwin" ]]; then
  MEM=$(sysctl -n hw.memsize 2>/dev/null)
  if [[ -n "$MEM" ]]; then
    MEM_GB=$(( MEM / 1073741824 ))
    OUTPUT+="Memory: ${MEM_GB}G total"$'\n'
  fi
fi

# Top-level structure (max 25 entries)
if LS_OUT=$(ls -1 2>/dev/null | head -25); then
  OUTPUT+="Top-level files:"$'\n'
  OUTPUT+="${LS_OUT}"$'\n'
fi

# Project type detection
PROJECT_TYPE=""
[[ -f "composer.json" ]] && PROJECT_TYPE+="Laravel/PHP "
[[ -f "package.json" ]] && PROJECT_TYPE+="Node.js "
[[ -f "Cargo.toml" ]] && PROJECT_TYPE+="Rust "
[[ -f "go.mod" ]] && PROJECT_TYPE+="Go "
[[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" ]] && PROJECT_TYPE+="Python "
[[ -f "Gemfile" ]] && PROJECT_TYPE+="Ruby "
[[ -f "build.gradle" || -f "pom.xml" ]] && PROJECT_TYPE+="Java "
[[ -f "artisan" ]] && PROJECT_TYPE+="Laravel "
[[ -f "next.config.js" || -f "next.config.mjs" || -f "next.config.ts" ]] && PROJECT_TYPE+="Next.js "
[[ -f "nuxt.config.ts" || -f "nuxt.config.js" ]] && PROJECT_TYPE+="Nuxt "
[[ -f "vite.config.ts" || -f "vite.config.js" ]] && PROJECT_TYPE+="Vite "
[[ -f "docker-compose.yml" || -f "docker-compose.yaml" ]] && PROJECT_TYPE+="Docker "

if [[ -n "$PROJECT_TYPE" ]]; then
  OUTPUT+="Project type: ${PROJECT_TYPE}"$'\n'
fi

# Available languages
LANGS=""
command -v php   >/dev/null 2>&1 && LANGS+="PHP $(php -r 'echo PHP_VERSION;' 2>/dev/null), "
command -v node  >/dev/null 2>&1 && LANGS+="Node $(node -v 2>/dev/null | tr -d 'v'), "
command -v python3 >/dev/null 2>&1 && LANGS+="Python $(python3 --version 2>/dev/null | awk '{print $2}'), "
command -v go    >/dev/null 2>&1 && LANGS+="Go $(go version 2>/dev/null | awk '{print $3}' | tr -d 'go'), "
command -v rustc >/dev/null 2>&1 && LANGS+="Rust $(rustc --version 2>/dev/null | awk '{print $2}'), "
command -v ruby  >/dev/null 2>&1 && LANGS+="Ruby $(ruby -v 2>/dev/null | awk '{print $2}'), "
command -v java  >/dev/null 2>&1 && LANGS+="Java $(java -version 2>&1 | head -1 | awk -F'"' '{print $2}'), "

if [[ -n "$LANGS" ]]; then
  OUTPUT+="Languages: ${LANGS%, }"$'\n'
fi

# Package managers
PKGMGRS=""
command -v composer >/dev/null 2>&1 && PKGMGRS+="composer "
command -v npm      >/dev/null 2>&1 && PKGMGRS+="npm "
command -v yarn     >/dev/null 2>&1 && PKGMGRS+="yarn "
command -v pnpm     >/dev/null 2>&1 && PKGMGRS+="pnpm "
command -v pip      >/dev/null 2>&1 && PKGMGRS+="pip "
command -v cargo    >/dev/null 2>&1 && PKGMGRS+="cargo "
command -v go       >/dev/null 2>&1 && PKGMGRS+="go-modules "

if [[ -n "$PKGMGRS" ]]; then
  OUTPUT+="Package managers: ${PKGMGRS}"$'\n'
fi

# Git info
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  OUTPUT+="Git: branch=${BRANCH:-detached}, uncommitted=${DIRTY}"$'\n'
fi

OUTPUT+="[/Environment Snapshot]"

echo "$OUTPUT"
exit 0
