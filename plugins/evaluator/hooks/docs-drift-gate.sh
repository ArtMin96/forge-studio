#!/usr/bin/env bash
# PreToolUse(Bash): before a `git commit`, force the human-facing docs to keep up
# with the code. When a skill's behavior or a plugin's hooks change, the practical
# guide a newcomer reads — docs/skills/<plugin>/<skill>.md (what / why / when / how)
# and the plugin README — usually needs to change too, and it is the step most
# often skipped. This names the exact guide file to reopen so "update the docs"
# stops being a vague aspiration and becomes a concrete file to open and correct.
#
#   FORGE_DOCS_GATE=1      (default) warn, non-blocking: lists the guides to reopen.
#   FORGE_DOCS_GATE=strict block the commit (exit 2) until a guide is staged too.
#   FORGE_DOCS_GATE=0      disable.
#
# Counts are a deliberate afterthought here (one trailing line), not the point: a
# guide that still describes the old behavior is the rot worth catching.
set -euo pipefail

MODE="${FORGE_DOCS_GATE:-1}"
[ "$MODE" = "0" ] && exit 0

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0
# `git commit` anywhere in the command (handles `cd x && git commit`), not as a
# substring of another word (`mygit commit`).
echo "$COMMAND" | grep -qE '(^|[^[:alnum:]_])git[[:space:]]+commit' || exit 0

command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# What this commit will touch. Plain `git commit` only commits the index, so the
# staged set is correct; `-a`/`-am`/`--all` also sweeps modified tracked files, so
# widen to working-tree-vs-HEAD in that case (a guide edited under -a shows up too).
if echo "$COMMAND" | grep -qE 'commit[[:space:]].*(-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)|--all)'; then
  CHANGED=$( { git diff --name-only HEAD 2>/dev/null; git diff --cached --name-only 2>/dev/null; } | sort -u | grep -v '^$' || true)
else
  CHANGED=$(git diff --cached --name-only 2>/dev/null | grep -v '^$' || true)
fi
[ -z "$CHANGED" ] && exit 0

is_changed() { printf '%s\n' "$CHANGED" | grep -qxF "$1"; }

STALE=""

# (a) Each changed SKILL.md should have its practical guide reopened.
while IFS= read -r f; do
  case "$f" in
    plugins/*/skills/*/SKILL.md)
      plugin=$(printf '%s' "$f" | cut -d/ -f2)
      skill=$(printf '%s' "$f" | cut -d/ -f4)
      guide="docs/skills/${plugin}/${skill}.md"
      is_changed "$guide" || STALE="${STALE}  ${f}
      -> reopen ${guide} — does what/why/when/how still match the code?
"
      ;;
  esac
done <<< "$CHANGED"

# (b) Plugin behavior (hooks) changed but no doc for that plugin was touched.
while IFS= read -r plugin; do
  [ -z "$plugin" ] && continue
  printf '%s\n' "$CHANGED" | grep -qE "^(plugins/${plugin}/README\.md|docs/skills/${plugin}/)" && continue
  STALE="${STALE}  plugins/${plugin}/hooks/* changed
      -> reopen plugins/${plugin}/README.md (+ docs/skills/${plugin}/*) — is the
         described behavior still true? A user must still grasp what/why/when.
"
done <<< "$(printf '%s\n' "$CHANGED" | grep -E '^plugins/[^/]+/hooks/' | cut -d/ -f2 | sort -u || true)"

# Count drift — last and quietest. The project's one deterministic doc invariant.
COUNT_NOTE=""
COUNT_SCRIPT="plugins/diagnostics/skills/entropy-scan/scripts/count.sh"
if [ -f "$COUNT_SCRIPT" ] && [ -f README.md ]; then
  LIVE=$(bash "$COUNT_SCRIPT" . 2>/dev/null || true)
  DOC=$(grep -m1 -E '^[0-9]+ plugins\. [0-9]+ skills\.' README.md 2>/dev/null || true)
  [ -n "$LIVE" ] && [ -n "$DOC" ] && [ "$LIVE" != "$DOC" ] && \
    COUNT_NOTE="(also: README counts drift — count.sh='${LIVE}' vs README='${DOC}')"
fi

if [ -n "$STALE" ]; then
  {
    echo "[docs-drift] Behavior changed; these practical guides were NOT touched."
    echo "They are the docs a newcomer reads — keep them true to the code, don't pretend:"
    printf '%s' "$STALE"
    [ -n "$COUNT_NOTE" ] && echo "  $COUNT_NOTE"
    echo "Standard: docs/skills/README.md. Disable: FORGE_DOCS_GATE=0 · Block: FORGE_DOCS_GATE=strict"
  } >&2
  [ "$MODE" = "strict" ] && exit 2
  exit 1
fi

if [ -n "$COUNT_NOTE" ]; then
  echo "[docs-drift] $COUNT_NOTE — reconcile README counts before commit." >&2
  exit 1
fi

exit 0
