#!/usr/bin/env bash
# Walk plugins/*/skills/*/SKILL.md frontmatter; report SSL field coverage.

set -u

ROOT="${1:-.}"
TOTAL=0
SCHED=0
STRUCT=0
LOGICAL=0
MISSING_LOGICAL=()

while IFS= read -r SKILL_FILE; do
  TOTAL=$((TOTAL + 1))
  FRONTMATTER=$(awk 'BEGIN{in_block=0} /^---$/{if(in_block){exit} else {in_block=1; next}} in_block{print}' "$SKILL_FILE")
  if echo "$FRONTMATTER" | grep -qE '^scheduling:'; then SCHED=$((SCHED + 1)); fi
  if echo "$FRONTMATTER" | grep -qE '^structural:'; then STRUCT=$((STRUCT + 1)); fi
  if echo "$FRONTMATTER" | grep -qE '^logical:'; then
    LOGICAL=$((LOGICAL + 1))
  else
    REL_PATH="${SKILL_FILE#"$ROOT"/}"
    REL_PATH="${REL_PATH#./}"
    SLUG=$(echo "$REL_PATH" | sed -E 's|plugins/([^/]+)/skills/([^/]+)/SKILL.md|skills/\1/\2|')
    MISSING_LOGICAL+=("$SLUG")
  fi
done < <(find "$ROOT/plugins" -mindepth 4 -maxdepth 4 -name SKILL.md -type f 2>/dev/null | sort)

echo "## SSL Audit"
echo "Skills scanned: $TOTAL"
echo "With scheduling field: $SCHED"
echo "With structural field: $STRUCT"
echo "With logical field: $LOGICAL"
echo "Missing logical (no measurable success criterion): ${#MISSING_LOGICAL[@]}"
echo ""
if [ ${#MISSING_LOGICAL[@]} -gt 0 ]; then
  echo "### Skills missing \`logical:\`"
  for SLUG in "${MISSING_LOGICAL[@]}"; do
    echo "- $SLUG"
  done
fi

# Second pass: intersect missing-logical set with routing/dispatch skills.
# Routing/dispatch skills are those whose name or description matches rout(e|ing)|dispatch|orchestrate.
# Per arXiv:2605.26112 §4.3, S⊥G coupling means unverified routing scales unreliability fastest —
# so any routing skill that lacks a logical post-condition is higher-priority than a non-routing gap.
# An empty list here is the healthy, expected result.
ROUTING_MISSING=()
for SLUG in "${MISSING_LOGICAL[@]}"; do
  SKILL_FILE="$ROOT/$(echo "$SLUG" | sed -E 's|^skills/([^/]+)/(.+)$|plugins/\1/skills/\2|')/SKILL.md"
  SKILL_NAME=$(echo "$SLUG" | sed 's|.*/||')
  SKILL_DESC=""
  if [ -f "$SKILL_FILE" ]; then
    SKILL_DESC=$(awk 'BEGIN{in_block=0} /^---$/{if(in_block){exit} else {in_block=1; next}} in_block{print}' "$SKILL_FILE" | grep '^description:' | head -1)
  fi
  if echo "$SKILL_NAME $SKILL_DESC" | grep -qiE 'rout(e|ing)|dispatch|orchestrate'; then
    ROUTING_MISSING+=("$SLUG")
  fi
done

echo ""
echo "### Routing and dispatch skills missing \`logical:\`"
if [ ${#ROUTING_MISSING[@]} -eq 0 ]; then
  echo "(none — all routing and dispatch skills have a logical post-condition)"
else
  for SLUG in "${ROUTING_MISSING[@]}"; do
    echo "- $SLUG  [HIGH PRIORITY]"
  done
fi

exit 0
