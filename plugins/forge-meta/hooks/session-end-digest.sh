#!/usr/bin/env bash
set -euo pipefail
# SessionEnd hook: write a per-session AHE digest to .claude/sessions/.
# Reads the event payload from stdin, extracts session_id, calls digest.sh.
# Observability only — always exits 0.

INPUT=$(cat 2>/dev/null || true)

SESSION_ID=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print(d.get('session_id', ''))
except Exception:
    print('')
" "$INPUT" 2>/dev/null || true)

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../skills/session-digest/scripts/digest.sh" --session-id "$SESSION_ID" || true

exit 0
