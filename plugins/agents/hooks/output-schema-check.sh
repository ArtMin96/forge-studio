#!/usr/bin/env bash
# SubagentStop: warn if generator finished without producing artifacts declared in the plan's Contract or Output Schema.
# Silent when:
#   - No plan file exists
#   - Plan has no Contract / Output Schema section
#   - All declared artifacts present
# Complementary to contract-check.sh (which warns on missing reviewer validation).
# This hook warns on missing generator output — earlier in the pipeline.

set -euo pipefail

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)

# Only check when generator agent stops
if [ "$AGENT_TYPE" != "generator" ]; then
  exit 0
fi

PLANS_DIR=".claude/plans"
if [ ! -d "$PLANS_DIR" ]; then
  exit 0
fi

# Find the active plan via numeric-prefix order (deterministic, not mtime).
LATEST_PLAN=$(bash "${CLAUDE_PLUGIN_ROOT}/../workflow/skills/orchestrate/scripts/find-active-plan.sh" 2>/dev/null || true)

if [ -z "$LATEST_PLAN" ] || [ ! -r "$LATEST_PLAN" ]; then
  exit 0
fi

# Extract file paths mentioned in Contract or Output Schema section(s).
# We treat bullet-list items that look like paths (contain '/' and a file extension) as declared artifacts.
SECTION=$(awk '
  /^## (Contract|Output Schema|Artifacts)/ { in_section=1; next }
  /^## / && in_section { in_section=0 }
  in_section { print }
' "$LATEST_PLAN")

if [ -z "$SECTION" ]; then
  exit 0
fi

# Collect candidate paths: strings matching a file-ish shape.
# Format we look for: anywhere in the section text, a token like `foo/bar.ext` or `plugins/x/y.md`.
DECLARED=$(echo "$SECTION" \
  | grep -oE '(\`[^` ]+\`|[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+)' \
  | sed 's/`//g' \
  | sort -u)

if [ -z "$DECLARED" ]; then
  exit 0
fi

MISSING=()
while IFS= read -r path; do
  if [ -z "$path" ]; then continue; fi
  # Skip anchors / URLs / relative refs starting with http or ./
  case "$path" in
    http*|\#*|\.\/*) continue ;;
  esac
  # Only check paths that look plausibly local to the repo
  if [ ! -e "$path" ]; then
    MISSING+=("$path")
  fi
done <<< "$DECLARED"

if [ "${#MISSING[@]}" -eq 0 ]; then
  exit 0
fi

# Warn (exit 1). Keep message short — hook budget ~100 tokens.
{
  echo "Plan $(basename "$LATEST_PLAN") declares artifacts the generator did not produce:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
  echo "Review the Contract before moving to reviewer phase."
} >&2

exit 1
