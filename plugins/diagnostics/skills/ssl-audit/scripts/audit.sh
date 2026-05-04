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

exit 0
