#!/usr/bin/env bash
set -euo pipefail

# Reads stdin (SubagentStart event payload — unused in v1, hook is generic).
# Finds the most-recent .claude/plans/*.md file, extracts the ## Contract
# block, and writes it to .claude/state/active-contract.md so downstream
# agents can read a fresh copy without relying on in-context memory.
# Exit 1 = warning (non-blocking); exit 0 = success.

# Consume stdin so the process doesn't leave it open.
cat > /dev/null

# Locate the workspace root: the directory containing .claude/plans/.
# When invoked by Claude Code, CWD is typically the project root.
PLANS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/plans"

# Locate the active plan via numeric-prefix sort (deterministic, not mtime).
# find-active-plan.sh honors FORGE_ACTIVE_PLAN_OVERRIDE and skips completed
# plans per the feature gate; falls back to mtime-newest with a stderr warning
# when all plans are gate-complete. The || true keeps pipefail from aborting
# before the user-friendly "no plan files" warning below.
PLAN_FILE=$(bash "${CLAUDE_PLUGIN_ROOT}/workflow-orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)

if [[ -z "$PLAN_FILE" ]]; then
  echo "[contract-reread] no plan files in .claude/plans/" >&2
  exit 1
fi

PLAN_BASENAME=$(basename "$PLAN_FILE")

# Extract from the "## Contract" line up to (not including) the next "## "
# heading, or EOF if no subsequent heading exists.
CONTRACT=$(awk '
  /^## Contract[[:space:]]*$/ { in_section=1; print; next }
  in_section && /^## / { exit }
  in_section { print }
' "$PLAN_FILE")

if [[ -z "$CONTRACT" ]]; then
  echo "[contract-reread] no ## Contract section in ${PLAN_BASENAME}" >&2
  exit 1
fi

# Write to the state dir; create it if absent.
STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/state"
mkdir -p "$STATE_DIR"

printf '%s\n' "$CONTRACT" > "${STATE_DIR}/active-contract.md"

# Touch mtime so downstream readers can detect that the file was refreshed
# on this dispatch, even when the content is unchanged.
touch "${STATE_DIR}/active-contract.md"
