#!/usr/bin/env bash
# PostToolUse:EnterPlanMode — advertise plan-relevant skills.
# Includes skills whose description contains "plan mode" or whose name is "plan".

set -euo pipefail

PLUGIN_CACHE="$HOME/.claude/plugins/cache"

SKILLS=""
if [[ -d "$PLUGIN_CACHE" ]]; then
  while IFS= read -r skill_file; do
    PLUGIN_DIR=$(dirname "$(dirname "$(dirname "$skill_file")")")
    [[ -f "$PLUGIN_DIR/.orphaned_at" ]] && continue
    NAME=$(sed -n 's/^name: *//p' "$skill_file" | head -1)
    DESC=$(sed -n 's/^description: *//p' "$skill_file" | head -1)
    [[ -z "$NAME" ]] && continue
    # Match: skill named "plan", or description mentions "plan mode"
    if [[ "$NAME" == "plan" ]] || echo "$DESC" | grep -qi "plan mode"; then
      SKILLS+="- /${NAME}: ${DESC}"$'\n'
    fi
  done < <(find "$PLUGIN_CACHE" -path "*/skills/*/SKILL.md" 2>/dev/null)
fi

if [[ -z "$SKILLS" ]]; then
  exit 0
fi

echo "Plan mode skills available (invoke via Skill tool):"
echo "$SKILLS"
exit 0
