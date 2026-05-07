#!/usr/bin/env bash
# Stop: warn (do not block) when this session changed substantive code but
# none of the repo-wide docs (README, CHANGELOG, docs/, ADR/, CLAUDE.md) were
# touched. Generic across project types — uses canonical doc surfaces only.
#
# Tunable: FORGE_DOCS_TOUCHED_THRESHOLD = minimum changed code files to warn
# (default 3).

set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$ACTIVE" = "true" ] && exit 0

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

CHANGED=$(timeout 1 git diff --name-only HEAD 2>/dev/null; timeout 1 git diff --cached --name-only 2>/dev/null)
CHANGED=$(echo "$CHANGED" | sort -u | grep -v '^$')
[ -z "$CHANGED" ] && exit 0

# Canonical doc surfaces (case-insensitive on basename, plus docs/ trees).
DOCS_PATTERN='(^|/)((README|CHANGELOG|CONTRIBUTING|CODE_OF_CONDUCT|HISTORY|UPGRADING|MIGRATION|CLAUDE)\.(md|rst|adoc|txt)|README|CHANGELOG)$|^docs/|^doc/|^documentation/|^website/|^site/|^adr/|^docs?/adr/|^architecture/'

DOCS_TOUCHED=$(echo "$CHANGED" | grep -iE "$DOCS_PATTERN" | head -1)
[ -n "$DOCS_TOUCHED" ] && exit 0

# Count substantive code changes (exclude lockfiles, generated, vendor, dotfiles).
SKIP_PATTERN='(^|/)(node_modules/|vendor/|dist/|build/|out/|target/|coverage/|__pycache__/|\.next/|\.nuxt/|\.cache/|\.venv/|venv/|\.idea/|\.vscode/|\.git/)|\.lock$|-lock\.(json|yaml|yml)$|^package-lock\.json$|^composer\.lock$|^yarn\.lock$|^pnpm-lock\.yaml$|^Cargo\.lock$|^go\.sum$|^Pipfile\.lock$|^poetry\.lock$|^Gemfile\.lock$'

CODE_CHANGED=$(echo "$CHANGED" | grep -ivE "$SKIP_PATTERN" | grep -ivE "$DOCS_PATTERN")
COUNT=$(echo "$CODE_CHANGED" | grep -c '^.' 2>/dev/null || echo 0)

THRESHOLD="${FORGE_DOCS_TOUCHED_THRESHOLD:-3}"
[ "$COUNT" -lt "$THRESHOLD" ] 2>/dev/null && exit 0

# Only warn if the repo actually has any docs to update — otherwise quiet.
HAS_DOCS=0
for candidate in README.md README.rst README docs CHANGELOG.md CHANGELOG; do
  [ -e "$candidate" ] && { HAS_DOCS=1; break; }
done
[ "$HAS_DOCS" = "0" ] && exit 0

SAMPLE=$(echo "$CODE_CHANGED" | head -3 | tr '\n' ',' | sed 's/,$//')

jq -nc --arg n "$COUNT" --arg s "$SAMPLE" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: ("[docs-touched] " + $n + " code files changed this session (e.g. " + $s + ") but no doc surfaces (README / CHANGELOG / docs/) were touched. If the change affects external behavior, public API, or setup, consider updating the relevant doc.")
  }
}'
exit 0
