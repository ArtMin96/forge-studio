#!/usr/bin/env bash
# convergence-check/scripts/check.sh
#
# Evaluate a plan's declared convergence criterion against current state.
#
# Argv: [plan-path]
#   If omitted, scans .claude/plans/*.md for the most-recently-modified
#   plan that contains a "## Convergence" section.
#
# Exit codes:
#   0  criterion met
#   1  criterion unmet
#   2  plan has no convergence block (skip gracefully)
#   3  plan not found

set -euo pipefail

PLAN_PATH="${1:-}"

# ── Plan resolution ────────────────────────────────────────────────────────
if [[ -n "$PLAN_PATH" ]]; then
  if [[ ! -f "$PLAN_PATH" ]]; then
    echo "plan_path: $PLAN_PATH"
    echo "error: plan file not found"
    exit 3
  fi
else
  # Find the most-recently-modified plan with a convergence block
  PLAN_PATH=""
  while IFS= read -r -d $'\0' f; do
    if grep -q "^## Convergence" "$f" 2>/dev/null; then
      PLAN_PATH="$f"
      break
    fi
  done < <(find .claude/plans -maxdepth 1 -name "*.md" -printf "%T@ %p\0" 2>/dev/null \
            | sort -rz | cut -z -d' ' -f2-)

  if [[ -z "$PLAN_PATH" ]]; then
    echo "plan_path: (none)"
    echo "error: no plan with a convergence block found in .claude/plans/"
    exit 3
  fi
fi

# ── Parse convergence block ────────────────────────────────────────────────
# Supports a ## Convergence section containing a fenced yaml block, e.g.:
#
#   ## Convergence
#   ```yaml
#   convergence:
#     type: test-gated
#     criterion: "test -f README.md"
#     max_iterations: 5
#   ```

# Extract lines between ## Convergence and the next ## heading (or EOF)
CONVERGENCE_BLOCK=""
in_section=0
in_fence=0
while IFS= read -r line; do
  if [[ "$line" =~ ^##[[:space:]]Convergence ]]; then
    in_section=1
    continue
  fi
  if (( in_section )); then
    # Stop at next ## heading (but not inside a fence)
    if [[ "$line" =~ ^##[[:space:]] ]] && (( !in_fence )); then
      break
    fi
    # Track fenced code blocks to avoid false heading matches inside them
    if [[ "$line" =~ ^\`\`\` ]]; then
      if (( in_fence )); then in_fence=0; else in_fence=1; fi
      continue
    fi
    CONVERGENCE_BLOCK+="$line"$'\n'
  fi
done < "$PLAN_PATH"

if [[ -z "$CONVERGENCE_BLOCK" ]]; then
  echo "plan_path: $PLAN_PATH"
  echo "met: skipped"
  echo "reason: no convergence block found in plan"
  exit 2
fi

# Extract type and criterion from the YAML-like block
CONV_TYPE=""
CONV_CRITERION=""

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*type:[[:space:]]*(.+)$ ]]; then
    CONV_TYPE="${BASH_REMATCH[1]}"
    # Strip surrounding quotes if present
    CONV_TYPE="${CONV_TYPE#\"}"
    CONV_TYPE="${CONV_TYPE%\"}"
    CONV_TYPE="${CONV_TYPE#\'}"
    CONV_TYPE="${CONV_TYPE%\'}"
  fi
  if [[ "$line" =~ ^[[:space:]]*criterion:[[:space:]]*\"(.+)\"$ ]]; then
    CONV_CRITERION="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]*criterion:[[:space:]]*\'(.+)\'$ ]]; then
    CONV_CRITERION="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]*criterion:[[:space:]]*(.+)$ ]]; then
    # Unquoted — take as-is, but only if criterion not yet set
    if [[ -z "$CONV_CRITERION" ]]; then
      CONV_CRITERION="${BASH_REMATCH[1]}"
      # Strip trailing quotes that may appear without opening quote
      CONV_CRITERION="${CONV_CRITERION%\"}"
      CONV_CRITERION="${CONV_CRITERION%\'}"
    fi
  fi
done <<< "$CONVERGENCE_BLOCK"

if [[ -z "$CONV_CRITERION" ]]; then
  echo "plan_path: $PLAN_PATH"
  echo "met: skipped"
  echo "reason: convergence block present but criterion field is empty or unparseable"
  exit 2
fi

# ── Execute the criterion ──────────────────────────────────────────────────
EVIDENCE=""
CRITERION_EXIT=0

# Run in a subshell with timeout; capture stdout+stderr as evidence
set +e
EVIDENCE=$(timeout 10 bash -c "$CONV_CRITERION" 2>&1)
CRITERION_EXIT=$?
set -e

MET="false"
if (( CRITERION_EXIT == 0 )); then
  MET="true"
fi

# Handle timeout (exit code 124 from timeout(1))
TIMEOUT_NOTE=""
if (( CRITERION_EXIT == 124 )); then
  TIMEOUT_NOTE=" (timed out after 10s)"
fi

# ── Emit structured report ────────────────────────────────────────────────
echo "plan_path: $PLAN_PATH"
echo "convergence_type: ${CONV_TYPE:-unknown}"
echo "criterion: $CONV_CRITERION"
echo "criterion_exit_code: ${CRITERION_EXIT}${TIMEOUT_NOTE}"
echo "met: $MET"
if [[ -n "$EVIDENCE" ]]; then
  echo "evidence_lines: $EVIDENCE"
else
  echo "evidence_lines: (no stdout — exit ${CRITERION_EXIT} is the signal)"
fi

if [[ "$MET" == "false" ]]; then
  echo "gap: criterion exited ${CRITERION_EXIT}${TIMEOUT_NOTE} — review evidence_lines above"
fi

# Exit with the semantic exit code
if (( CRITERION_EXIT == 0 )); then
  exit 0
else
  exit 1
fi
