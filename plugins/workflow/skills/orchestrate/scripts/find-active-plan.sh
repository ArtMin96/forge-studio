#!/usr/bin/env bash
set -euo pipefail

# Single source of truth for "which plan is active."
#
# Algorithm:
#   1. FORGE_ACTIVE_PLAN_OVERRIDE env: if set and file exists → return it.
#   2. Enumerate .claude/plans/*.md sorted by natural numeric prefix (sort -V).
#   3. For each plan, consult .claude/gate/features.json (best-effort heuristic):
#      if ALL gate entries whose id matches this plan's sprint prefix (e.g. "s1")
#      have passed:true, treat this plan as complete and skip it.
#   4. Return the first non-complete plan.
#   5. If all plans appear complete per the gate, fall back to mtime-newest
#      and emit a warning to stderr.
#
# Heuristic caveat: features.json entries use arbitrary ids; the match is by
# the plan file's sprint prefix (e.g. "s5" from "s5-followups.md"). This is
# best-effort — a gate entry whose id is "s5-T1" will match; one named
# "feat-xyz" will not and therefore won't affect skip logic for s5.
#
# Returns: one absolute path on stdout, or empty string + exit 0 when no plans exist.
# Exit codes: 0 always (this script is advisory, never a gate).

# --- 1. Honor override ---
if [[ -n "${FORGE_ACTIVE_PLAN_OVERRIDE:-}" ]]; then
  if [[ -f "$FORGE_ACTIVE_PLAN_OVERRIDE" && -r "$FORGE_ACTIVE_PLAN_OVERRIDE" ]]; then
    echo "$FORGE_ACTIVE_PLAN_OVERRIDE"
    exit 0
  fi
  # Override set but file not readable — fall through to normal resolution.
fi

# --- 2. Locate plans directory ---
PLANS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/plans"
if [[ ! -d "$PLANS_DIR" ]]; then
  exit 0
fi

# Enumerate plan files in natural numeric-prefix order.
mapfile -t PLAN_PATHS < <(ls -1 "$PLANS_DIR"/*.md 2>/dev/null | sort -V)
if [[ ${#PLAN_PATHS[@]} -eq 0 ]]; then
  exit 0
fi

# --- 3. Load feature gate once ---
GATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/gate/features.json"
GATE_ENTRIES=""
if [[ -f "$GATE_FILE" && -r "$GATE_FILE" ]]; then
  GATE_ENTRIES=$(python3 - "$GATE_FILE" 2>/dev/null <<'PYEOF' || true
import sys, json
try:
    data = json.load(open(sys.argv[1]))
    if isinstance(data, list):
        print(json.dumps(data))
    else:
        print("[]")
except (json.JSONDecodeError, OSError):
    print("[]")
PYEOF
  )
fi
GATE_ENTRIES="${GATE_ENTRIES:-[]}"

# --- 4. Walk plans in sort-V order; return first non-complete ---
for plan_path in "${PLAN_PATHS[@]}"; do
  plan_basename=$(basename "$plan_path")
  # Extract sprint prefix: "s5-followups.md" → "s5"
  sprint_prefix=$(echo "$plan_basename" | grep -oE '^s[0-9]+' || true)

  if [[ -z "$sprint_prefix" || "$GATE_ENTRIES" == "[]" ]]; then
    # No prefix or no gate data — cannot determine completion; treat as active.
    echo "$plan_path"
    exit 0
  fi

  # Check if all gate entries matching this sprint prefix have passed:true.
  # A plan is "complete" only when at least one matching entry exists AND all such entries passed.
  is_complete=$(python3 - "$GATE_ENTRIES" "$sprint_prefix" 2>/dev/null <<'PYEOF' || echo "no"
import sys, json
entries_json = sys.argv[1]
prefix = sys.argv[2]
try:
    entries = json.loads(entries_json)
except (json.JSONDecodeError, ValueError):
    print("no"); sys.exit(0)
if not isinstance(entries, list):
    print("no"); sys.exit(0)
# Match entries whose id starts with the sprint prefix.
matching = [e for e in entries if isinstance(e, dict) and str(e.get("id","")).startswith(prefix)]
if not matching:
    # No gate entries for this plan → cannot confirm complete → treat as active.
    print("no")
    sys.exit(0)
all_passed = all(e.get("passed") is True for e in matching)
print("yes" if all_passed else "no")
PYEOF
  )

  if [[ "$is_complete" == "yes" ]]; then
    continue  # All gate entries for this plan passed; skip it.
  fi

  echo "$plan_path"
  exit 0
done

# --- 5. All plans appear complete per gate; fall back to mtime-newest ---
echo "[find-active-plan] all plans appear complete per feature gate; falling back to mtime-newest" >&2
fallback=$(ls -1t "$PLANS_DIR"/*.md 2>/dev/null | head -1 || true)
if [[ -n "$fallback" ]]; then
  echo "$fallback"
fi
exit 0
