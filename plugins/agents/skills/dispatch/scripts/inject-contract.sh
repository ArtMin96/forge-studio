#!/usr/bin/env bash
set -euo pipefail

# Best-effort reader for the active sprint contract.
# Reads .claude/state/active-contract.md (written by contract-reread.sh on
# SubagentStart) and prints it to stdout with a [contract] header so the
# dispatching model can prepend it verbatim to any subagent prompt it builds.
# If the file is absent or empty (e.g., no active plan, or session hasn't
# triggered SubagentStart yet), prints nothing and exits 0.
# Never blocks — exit 0 in all cases.

CONTRACT_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/state/active-contract.md"

if [ -s "$CONTRACT_FILE" ]; then
  echo "[contract] active sprint contract from .claude/state/active-contract.md:"
  echo ""
  cat "$CONTRACT_FILE"
fi

exit 0
