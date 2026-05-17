#!/usr/bin/env bash
# SubagentStop hook — orchestrator-imposed verify nudge (CAAF 2604.17025 p.39).
# Fires after a generator or reviewer subagent stops. Emits a structured-gradient
# result so the next turn has explicit PASS/FAIL evidence rather than an assertion.
# Exit 0 = PASS or no evidence; exit 1 = FAIL (warning, not block).
# Never exits 2 — blocking SubagentStop is meaningless and breaks subagent dispatch.
set -euo pipefail

# --- env override: FORGE_AUTO_VERIFY=0 silences this hook for manual-control sessions ---
if [[ "${FORGE_AUTO_VERIFY:-1}" == "0" ]]; then
  exit 0
fi

# --- read JSON stdin and extract agent_type ---
input="$(cat)"
agent_type="$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type',''))" 2>/dev/null || true)"

# Only fire for generator or reviewer agent types (glob-style: *generator* or *reviewer*)
case "$agent_type" in
  *generator*|*reviewer*) ;;
  *) exit 0 ;;
esac

# --- helper: emit structured gradient and exit ---
emit() {
  local dimension="$1" direction="$2" magnitude="$3" rc="$4"
  printf '[auto-verify] Dimension=%s  Direction=%s  Magnitude=%s\n' \
    "$dimension" "$direction" "$magnitude" >&2
  exit "$rc"
}

# --- locate most-recent plan ---
plan_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/plans"
gate_file="${CLAUDE_PROJECT_DIR:-.}/.claude/gate/features.json"

# Find the active plan via numeric-prefix order (deterministic, not mtime).
most_recent_plan=""
if [[ -d "$plan_dir" ]]; then
  most_recent_plan="$(bash "${CLAUDE_PLUGIN_ROOT}/../workflow/skills/orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)"
fi

# --- check gate/features.json for task evidence ---
if [[ -f "$gate_file" ]]; then
  # Check whether any feature entry has passed:true
  has_passing="$(python3 - "$gate_file" 2>/dev/null <<'PY' || echo "no"
import sys, json
try:
    gate = json.load(open(sys.argv[1]))
except (json.JSONDecodeError, OSError):
    print("no"); sys.exit(0)
if isinstance(gate, list) and len(gate) > 0 and all(e.get("passed") is True for e in gate):
    print("yes")
else:
    print("no")
PY
  )"
  has_passing="${has_passing:-no}"

  if [[ "$has_passing" == "yes" ]]; then
    emit "gate-features" "PASS" "gate/features.json contains passing entries" 0
  else
    emit "gate-features" "FAIL" "run /verify to produce passing gate entries" 1
  fi
fi

# --- no gate file: check whether a plan exists as minimum evidence ---
if [[ -z "$most_recent_plan" ]]; then
  # No plan, no gate — nothing to verify against; treat as no-evidence (PASS-silent)
  exit 0
fi

# Plan exists but no gate file — verification has not been run
emit "gate-features" "FAIL" "no gate/features.json — run /verify against $(basename "$most_recent_plan")" 1
