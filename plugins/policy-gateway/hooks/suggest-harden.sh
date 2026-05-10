#!/usr/bin/env bash
# PostToolUse:Edit|Write — if the edited path matches security-sensitive globs,
# surface a one-line nudge to invoke /challenge (adversarial-reviewer).
# Read-only; never blocks. Exit 0 always.
#
# Reasoning (Lesson 10c, Breunig 2026-04): hardening is token-budgeted exploit
# discovery. Not always-on — that wastes tokens against zero attacker. Surface
# the nudge at the edit boundary so the human decides when to spend the budget.

set -u

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

LOW=$(printf '%s' "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

match() {
  case "$LOW" in
    */auth/*|*/authn/*|*/authz/*) return 0 ;;
    *auth*.ts|*auth*.js|*auth*.py|*auth*.go|*auth*.php|*auth*.rb) return 0 ;;
    *.sql|*/migrations/*|*/migrate/*) return 0 ;;
    */crypto/*|*crypto*.ts|*crypto*.js|*crypto*.py|*crypto*.go|*crypto*.php|*crypto*.rb) return 0 ;;
    */http/*|*/handlers/*|*/routes/*|*/controllers/*) return 0 ;;
    *session*.ts|*session*.js|*session*.py|*session*.go|*session*.php|*session*.rb) return 0 ;;
    *token*.ts|*token*.js|*token*.py|*token*.go|*token*.php|*token*.rb) return 0 ;;
    *password*.ts|*password*.js|*password*.py|*password*.go|*password*.php|*password*.rb) return 0 ;;
  esac
  return 1
}

if match; then
  printf '[policy-gateway] Edited security-sensitive path: %s\n' "$FILE_PATH"
  printf '[policy-gateway] Consider running /challenge — adversarial-reviewer agent (read-only) probes edge cases, race conditions, and exploit paths. Token-budgeted; you decide when.\n'
fi

exit 0
