#!/usr/bin/env bash
# Behavioral Steering: Modular anchor injected on every user message.
# Reads priority-ordered rule fragments from rules.d/ to prevent behavioral drift.
# Users can add/remove/reorder rules by managing files in the directory.

RULES_DIR="${CLAUDE_PLUGIN_ROOT}/hooks/rules.d"

echo "BEHAVIORAL RULES (enforced every message):"

if [[ -d "$RULES_DIR" ]]; then
  for rule_file in "$RULES_DIR"/*.txt; do
    [[ -f "$rule_file" ]] || continue
    echo "- $(cat "$rule_file")"
  done
else
  # Fallback if rules.d/ is missing
  echo "- Be critical, direct, and honest. Verify before claiming done."
fi

# Conditional: if a scope file exists in the session, add scope-respect rule
if [[ -n "${CLAUDE_SESSION_SCOPE:-}" ]] && [[ -f "${CLAUDE_SESSION_SCOPE}" ]]; then
  echo "- SCOPE ACTIVE: Respect boundaries defined in $(basename "$CLAUDE_SESSION_SCOPE"). Warn before going out of scope."
fi

exit 0
