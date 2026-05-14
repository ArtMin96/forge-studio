#!/usr/bin/env bash
set -euo pipefail
# run-iteration.sh — workspace coordinator for /auto-tune-skill
#
# Creates the per-run proposal workspace, logs iteration metadata to
# .claude/evolution/auto-tune-runs.jsonl, and triggers ledger rotation.
# Subagent dispatch is the model's job (see SKILL.md); this script does NOT
# invoke Claude or spawn subagents.
#
# Args: <plugin>:<skill-id>
# Env:
#   FORGE_AUTO_TUNE_ITERS  — iteration cap passed into log entry (default 3)
#   FORGE_AUTO_TUNE_K      — candidates per iteration for log entry (default 3)
#   FORGE_AUTO_TUNE_MOCK   — "1" = mock mode; written into log entry

# ---------------------------------------------------------------------------
# Parse argument
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: run-iteration.sh <plugin>:<skill-id>" >&2
  exit 1
fi

ARG="$1"
PLUGIN="${ARG%%:*}"
SKILL="${ARG##*:}"

if [[ -z "$PLUGIN" || -z "$SKILL" || "$PLUGIN" == "$ARG" ]]; then
  echo "Error: argument must be <plugin>:<skill-id>, got: $ARG" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

SKILL_MD="$REPO_ROOT/plugins/$PLUGIN/skills/$SKILL/SKILL.md"
EVALS_JSON="$REPO_ROOT/plugins/$PLUGIN/skills/$SKILL/evals/evals.json"

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
if [[ ! -f "$SKILL_MD" ]]; then
  echo "Error: SKILL.md not found at plugins/$PLUGIN/skills/$SKILL/SKILL.md" >&2
  exit 1
fi

if [[ ! -f "$EVALS_JSON" ]]; then
  echo "Error: evals.json not found for $PLUGIN:$SKILL — add plugins/$PLUGIN/skills/$SKILL/evals/evals.json before auto-tuning" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ITERS="${FORGE_AUTO_TUNE_ITERS:-3}"
K="${FORGE_AUTO_TUNE_K:-3}"
MOCK="${FORGE_AUTO_TUNE_MOCK:-0}"
MODE="$( [[ "$MOCK" == "1" ]] && echo "mock" || echo "live" )"

# ---------------------------------------------------------------------------
# Create workspace: .claude/proposals/<plugin>-<skill>-<iso-ts>/iter-1/
# ---------------------------------------------------------------------------
PROPOSALS_DIR="$REPO_ROOT/.claude/proposals"
EVOLUTION_DIR="$REPO_ROOT/.claude/evolution"
mkdir -p "$PROPOSALS_DIR" "$EVOLUTION_DIR"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORKSPACE_DIR="$PROPOSALS_DIR/${PLUGIN}-${SKILL}-${TIMESTAMP}"
mkdir -p "$WORKSPACE_DIR/iter-1"

# ---------------------------------------------------------------------------
# Log iteration metadata to auto-tune-runs.jsonl
# ---------------------------------------------------------------------------
LOG_FILE="$EVOLUTION_DIR/auto-tune-runs.jsonl"

ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

python3 -c "
import json
entry = {
    'iso_timestamp': '$ISO_TS',
    'session_id': '$SESSION_ID',
    'skill': '$PLUGIN:$SKILL',
    'iteration_no': 1,
    'candidate_count': int('$K'),
    'mode': '$MODE',
    'workspace_dir': '$WORKSPACE_DIR',
}
print(json.dumps(entry))
" >> "$LOG_FILE"

# ---------------------------------------------------------------------------
# Rotate ledger if it exceeds thresholds
# ---------------------------------------------------------------------------
ROTATE_SCRIPT="$SCRIPT_DIR/../../change-manifest/scripts/rotate.sh"
if [[ -x "$ROTATE_SCRIPT" ]]; then
  bash "$ROTATE_SCRIPT" "$LOG_FILE" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Output the workspace dir so SKILL.md / the model knows where to write candidates
# ---------------------------------------------------------------------------
echo "$WORKSPACE_DIR"
