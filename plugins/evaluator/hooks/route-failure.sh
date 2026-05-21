#!/usr/bin/env bash
set -euo pipefail
# PostToolUseFailure: classify the error string and nudge toward the corrective
# skill. Advisory only; never blocks. Silent when no class matches or when the
# same (class, error-md5) already fired this session.
#
# arXiv:2605.18747 §5.2.2 — feedback should route differently by type: compile
# errors → local syntax repair; test failures → behavioral diagnosis; type
# errors → local fix; lint/static-analysis warnings → in-place revise.

INPUT=$(cat 2>/dev/null || true)
ERROR=$(echo "$INPUT" | jq -r '.error // empty' 2>/dev/null | head -c 800)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-default}"

[ -z "$ERROR" ] && exit 0

CLASS="" ; NUDGE=""
err_lc=$(printf '%s' "$ERROR" | tr '[:upper:]' '[:lower:]')

if printf '%s' "$err_lc" | grep -qE '(syntaxerror|parseerror|unexpected token|unexpected end of (file|input)|expected .{1,30}(but|got)|missing semicolon)'; then
  CLASS="compile-error"
  NUDGE="compile-error → fix locally at the cited file:line; do NOT escalate to /tdd-loop or /orchestrate"
elif printf '%s' "$err_lc" | grep -qE '(assertionerror|assertion failed|expect\(.*\)\.to|tests?:.*failed|^\s*fail\s|expected .* received|wanted .* got)'; then
  CLASS="test-fail"
  NUDGE="test-fail → consider /tdd-loop to drive a RED→GREEN cycle, or read the failure and fix the production code directly"
elif printf '%s' "$err_lc" | grep -qE '(ts[0-9]{4}|type .* (is not assignable|does not (exist|satisfy))|cannot find name|incompatible types|expected type .* but)'; then
  CLASS="type-error"
  NUDGE="type-error → fix annotation/import locally; do NOT broaden types to suppress"
elif printf '%s' "$err_lc" | grep -qE '(phpstan|psalm|eslint|pylint|flake8|ruff:|pint:|warning:.*deprecated|warning:.*unused)'; then
  CLASS="lint-warning"
  NUDGE="lint-warning → address the warning in place; /healthcheck reruns the same linter"
fi

[ -z "$CLASS" ] && exit 0

REMINDERS_DIR=".claude/state/reminders"
mkdir -p "$REMINDERS_DIR" 2>/dev/null || true
STATE_FILE="$REMINDERS_DIR/route-failure-${SESSION_ID}"
ERROR_MD5=$(printf '%s' "$ERROR" | md5sum | cut -d' ' -f1)
STATE_HASH=$(printf '%s:%s' "$CLASS" "$ERROR_MD5" | md5sum | cut -d' ' -f1)

if [ -f "$STATE_FILE" ] && grep -qx "$STATE_HASH" "$STATE_FILE" 2>/dev/null && [ "${FORGE_REMINDER_FORCE:-0}" != "1" ]; then
  exit 0
fi

printf '[evaluator router] tool=%s class=%s\n%s\n' "$TOOL" "$CLASS" "$NUDGE"
printf '%s\n' "$STATE_HASH" >> "$STATE_FILE"

exit 0
