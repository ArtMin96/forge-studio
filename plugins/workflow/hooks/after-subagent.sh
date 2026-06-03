#!/usr/bin/env bash
set -euo pipefail
# SubagentStop: nudge the next step in the planner → generator → reviewer → verify chain,
# AND append a delta block to .claude/spec.md (if it exists) so the living spec tracks
# completed work as it happens. Complements (does not duplicate) contract-check.sh.
#
# Silent when agent_type is missing (line 11 early-exit). Unknown but present values emit a warning.

INPUT=$(cat 2>/dev/null || true)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)

if [ -z "$AGENT_TYPE" ]; then
  exit 0
fi

PLANS_DIR=".claude/plans"
SPEC_FILE=".claude/spec.md"
FEATURES_FILE=".claude/features.json"
HAS_ACTIVE_PLAN=0
if [ -d "$PLANS_DIR" ]; then
  if find "$PLANS_DIR" -maxdepth 1 -name '*.md' -mmin -180 2>/dev/null | grep -q .; then
    HAS_ACTIVE_PLAN=1
  fi
fi

append_spec_delta() {
  [ -f "$SPEC_FILE" ] || return 0
  local agent="$1"
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local changed
  changed=$(git diff --name-only --cached 2>/dev/null | head -5; git diff --name-only 2>/dev/null | head -5) || true
  local commits
  commits=$(git log --oneline --since="30 minutes ago" 2>/dev/null | head -3) || true
  {
    printf '\n### %s — %s\n' "$ts" "$agent"
    printf 'Completed:\n'
    if [ -n "$commits" ]; then
      printf '%s\n' "$commits" | sed 's/^/  - /'
    else
      printf '  - (no new commits in last 30m)\n'
    fi
    if [ -n "$changed" ]; then
      printf 'Changed:\n'
      printf '%s\n' "$changed" | awk 'NF' | sort -u | sed 's/^/  - /'
    fi
  } >> "$SPEC_FILE"
}

mark_features_done() {
  [ -f "$FEATURES_FILE" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local subjects
  subjects=$(git log --pretty=format:'%s' --since="30 minutes ago" 2>/dev/null) || return 0
  [ -z "$subjects" ] && return 0
  local ids
  ids=$(echo "$subjects" | grep -oE '\bF[0-9]+\b' | sort -u)
  [ -z "$ids" ] && return 0
  local tmp="${FEATURES_FILE}.tmp"
  local ids_json
  ids_json=$(echo "$ids" | jq -Rn '[inputs]')
  jq --argjson ids "$ids_json" \
    'map(if (.id as $i | $ids | index($i)) and .status == "pending" then .status="done" else . end)' \
    "$FEATURES_FILE" > "$tmp" && mv "$tmp" "$FEATURES_FILE"
}

# Dedup helper: suppress repeated nudge emissions for the same (agent_type, plan_basename) within a TTL.
# Dedup key is (nudge-id, plan-basename) rather than handoff_id because handoff_id is regenerated on
# every handoff_open call and therefore cannot identify "same logical phase transition".
# Returns 0 (already fired — suppress) or 1 (not yet fired — emit and record).
# FORGE_REMINDER_FORCE=1 bypasses the check and always returns 1.
nudge_already_fired() {
  local nudge_id="$1"
  local plan_base="$2"
  local ttl="${FORGE_AFTER_SUBAGENT_TTL_SECS:-1800}"
  local state_dir=".claude/state/reminders"
  local state_file="${state_dir}/after-subagent-${nudge_id}-${plan_base}"

  if [ "${FORGE_REMINDER_FORCE:-0}" = "1" ]; then
    mkdir -p "$state_dir"
    touch "$state_file"
    return 1
  fi

  if [ -f "$state_file" ]; then
    local now
    now=$(date +%s)
    local mtime
    mtime=$(stat -c '%Y' "$state_file" 2>/dev/null || stat -f '%m' "$state_file" 2>/dev/null || echo 0)
    local age=$(( now - mtime ))
    if [ "$age" -lt "$ttl" ]; then
      return 0
    fi
  fi

  mkdir -p "$state_dir"
  touch "$state_file"
  return 1
}

# Resolve the active plan once, before the case block, so all three arms
# (planner, generator, reviewer) share LATEST_PLAN_FILE and LATEST_PLAN_FILE_BASENAME.
# Uses the find-active-plan.sh helper for deterministic numeric-prefix order
# instead of mtime; falls back to mtime-newest when all plans are gate-complete.
LATEST_PLAN_FILE=""
LATEST_PLAN_FILE_BASENAME=""
LATEST_PLAN_FILE=$(bash "${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)
if [ -n "$LATEST_PLAN_FILE" ]; then
  LATEST_PLAN_FILE_BASENAME=$(basename "$LATEST_PLAN_FILE")
fi

# Accepted agent_type values: planner|Plan, generator|agents:generator, reviewer|agents:reviewer|evaluator:adversarial-reviewer
case "$AGENT_TYPE" in
  planner|Plan)
    if [ "$HAS_ACTIVE_PLAN" = "1" ]; then
      if ! nudge_already_fired "planner" "${LATEST_PLAN_FILE_BASENAME:-_no_plan}"; then
        echo "[workflow] Planner finished. Next: dispatch the generator. Ensure the plan has a ## Contract section before generating."
      fi
    fi
    append_spec_delta "planner"
    ;;
  generator|agents:generator)
    if [ "$HAS_ACTIVE_PLAN" = "1" ]; then
      if ! nudge_already_fired "generator" "${LATEST_PLAN_FILE_BASENAME:-_no_plan}"; then
        echo "[workflow] Generator finished. Next: dispatch the reviewer (read-only). Agent self-evaluation is unreliable."
      fi
    fi
    append_spec_delta "generator"
    mark_features_done

    # Emit handoff advisory when a plan with ## Contract section exists.
    # handoff_open always runs to create the ledger entry; only the user-facing nudge text is deduplicated.
    if [ -n "$LATEST_PLAN_FILE" ] && grep -q '^## Contract' "$LATEST_PLAN_FILE" 2>/dev/null; then
      PLAN_BASE="$LATEST_PLAN_FILE_BASENAME"
      LIB_DIR="$(dirname "$0")/../lib"
      HANDOFF_ID=$(bash "${LIB_DIR}/handoff-state.sh" open "$PLAN_BASE" 2>/dev/null || true)
      if ! nudge_already_fired "generator-handoff" "$PLAN_BASE"; then
        {
          printf '[handoff] generator complete. plan: %s | next gate: /verify %s\n' \
            "$PLAN_BASE" "${PLAN_BASE%.md}"
          if [ -n "$HANDOFF_ID" ]; then
            printf '[handoff] handoff_id=%s tracked in .claude/handoffs.jsonl\n' "$HANDOFF_ID"
          fi
        } >&2
      fi
    fi
    ;;
  reviewer|agents:reviewer|evaluator:adversarial-reviewer)
    if ! nudge_already_fired "reviewer" "${LATEST_PLAN_FILE_BASENAME:-_no_plan}"; then
      echo "[workflow] Reviewer finished. Before claiming done: run /verify (evaluator plugin) with evidence — commands, outputs, diffs."
    fi
    append_spec_delta "reviewer"
    ;;
  *)
    # Unknown-but-valid agent types (researcher, custom subagents) open no handoff.
    # Advisory plugin: stay silent rather than emit a stderr error for normal cases.
    ;;
esac

exit 0
