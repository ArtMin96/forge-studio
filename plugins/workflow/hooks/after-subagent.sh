#!/usr/bin/env bash
# SubagentStop: nudge the next step in the planner → generator → reviewer → verify chain,
# AND append a delta block to .claude/spec.md (if it exists) so the living spec tracks
# completed work as it happens. Complements (does not duplicate) contract-check.sh.
#
# Silent when agent_type is missing or unrecognized.

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

case "$AGENT_TYPE" in
  planner|Plan)
    if [ "$HAS_ACTIVE_PLAN" = "1" ]; then
      echo "[workflow] Planner finished. Next: dispatch the generator. Ensure the plan has a ## Contract section before generating."
    fi
    append_spec_delta "planner"
    ;;
  generator|agents:generator)
    if [ "$HAS_ACTIVE_PLAN" = "1" ]; then
      echo "[workflow] Generator finished. Next: dispatch the reviewer (read-only). Agent self-evaluation is unreliable."
    fi
    append_spec_delta "generator"
    mark_features_done
    ;;
  reviewer|agents:reviewer|evaluator:adversarial-reviewer)
    echo "[workflow] Reviewer finished. Before claiming done: run /verify (evaluator plugin) with evidence — commands, outputs, diffs."
    append_spec_delta "reviewer"
    ;;
esac

exit 0
