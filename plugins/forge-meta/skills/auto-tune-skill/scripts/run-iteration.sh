#!/usr/bin/env bash
# run-iteration.sh — outer-loop scaffold for /auto-tune-skill
#
# Implements the harness shape of Meta-Harness 2603.28052 Algorithm 1 (p.5):
# validate → propose mutations → score → keep Pareto-best → write proposal.
#
# The autonomous mutation subagent (context: fork dispatch) is a planned
# follow-up. This script ships the file-I/O skeleton and proposal format so
# the rest of the pipeline (evals, ledger, guard hooks) can be verified now.
#
# Args: <plugin>:<skill-id>  e.g. diagnostics:entropy-scan
# Env:  FORGE_AUTO_TUNE_ITERS — iteration cap (default 5)

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse argument
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: run-iteration.sh <plugin>:<skill-id>" >&2
  exit 1
fi

ARG="$1"

# Split on colon
PLUGIN="${ARG%%:*}"
SKILL="${ARG##*:}"

if [[ -z "$PLUGIN" || -z "$SKILL" || "$PLUGIN" == "$ARG" ]]; then
  echo "Error: argument must be <plugin>:<skill-id>, got: $ARG" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve paths relative to the repo root (two dirs above this script)
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
ITERS="${FORGE_AUTO_TUNE_ITERS:-5}"

# ---------------------------------------------------------------------------
# Ensure output directories exist
# ---------------------------------------------------------------------------
PROPOSALS_DIR="$REPO_ROOT/.claude/proposals"
EVOLUTION_DIR="$REPO_ROOT/.claude/evolution"
mkdir -p "$PROPOSALS_DIR" "$EVOLUTION_DIR"

# ---------------------------------------------------------------------------
# Outer loop (stub: harness shape without live mutation subagent)
# ---------------------------------------------------------------------------
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PROPOSAL_FILE="$PROPOSALS_DIR/${PLUGIN}-${SKILL}-${TIMESTAMP}.md"

echo "auto-tune-skill: $PLUGIN:$SKILL — running $ITERS iteration(s) (stub mode)"

for ITER_N in $(seq 1 "$ITERS"); do
  echo "  iteration $ITER_N/$ITERS"
  # In the full implementation each iteration would:
  #   1. Dispatch a context:fork subagent to propose 2 body mutations
  #   2. Run /run-evals for each candidate
  #   3. Score by (pass_rate, -token_cost) and update Pareto frontier
  # Stub: copy current SKILL.md as the baseline candidate for this iteration.
done

# ---------------------------------------------------------------------------
# Write proposal file
# ---------------------------------------------------------------------------
# Prepend a status header outside the YAML frontmatter block, then the
# original SKILL.md content, then a reviewer footer.

{
  printf 'proposal_status: unreviewed\n\n'
  cat "$SKILL_MD"
  printf '\n\n---\n'
  printf '<!-- auto-tune proposal footer -->\n'
  printf '## Reviewer Instructions\n\n'
  printf 'This file was produced by `/auto-tune-skill %s:%s` on %s.\n\n' \
    "$PLUGIN" "$SKILL" "$TIMESTAMP"
  printf 'The frontmatter above is unchanged from the original.\n'
  printf 'The body is the baseline (autonomous mutation in a future release).\n\n'
  printf '**To apply:** copy the body section back into `plugins/%s/skills/%s/SKILL.md`.\n\n' \
    "$PLUGIN" "$SKILL"
  printf '**To verify:** run `/run-evals %s:%s` and compare pass-rate to baseline.\n\n' \
    "$PLUGIN" "$SKILL"
  printf '**To discard:** delete this file — the original SKILL.md is untouched.\n'
} > "$PROPOSAL_FILE"

echo "  proposal written: .claude/proposals/${PLUGIN}-${SKILL}-${TIMESTAMP}.md"

# ---------------------------------------------------------------------------
# Log to evolution ledger
# ---------------------------------------------------------------------------
LOG_FILE="$EVOLUTION_DIR/auto-tune-runs.jsonl"

ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

python3 -c "
import json, sys
entry = {
    'iso_timestamp': '$ISO_TS',
    'session_id': '$SESSION_ID',
    'skill': '$PLUGIN:$SKILL',
    'iterations_run': $ITERS,
    'proposal_file': '.claude/proposals/${PLUGIN}-${SKILL}-${TIMESTAMP}.md',
    'mode': 'stub',
    'note': 'Baseline candidate only; autonomous mutation subagent not yet dispatched'
}
print(json.dumps(entry))
" >> "$LOG_FILE"

echo "  logged to .claude/evolution/auto-tune-runs.jsonl"
echo "auto-tune-skill: done"
