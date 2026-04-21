#!/usr/bin/env bash
# PreToolUse:Edit|Write — enforce worktree-team directory ownership.
#
# Silent unless ALL conditions hold:
#   1. FORGE_DIRECTORY_OWNERSHIP=1  (opt-in)
#   2. .claude/agents/active-roles.json exists and is readable
#   3. $CLAUDE_AGENT_ROLE env var is set and matches an entry in the registry
#   4. The entry has a non-empty `owned` list
#   5. The tool input's target path is outside the owned list
#
# When all hold, exit 0 with a JSON permissionDecision=deny (preferred over exit 2).

set -u

# Opt-in gate
if [ "${FORGE_DIRECTORY_OWNERSHIP:-0}" != "1" ]; then
  exit 0
fi

REGISTRY=".claude/agents/active-roles.json"
if [ ! -r "$REGISTRY" ]; then
  exit 0
fi

ROLE="${CLAUDE_AGENT_ROLE:-}"
if [ -z "$ROLE" ]; then
  exit 0
fi

INPUT=$(cat)

# Extract target path from Edit/Write tool input
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -z "$TARGET" ]; then
  exit 0
fi

# Lookup role in registry, get owned paths
OWNED=$(jq -r --arg r "$ROLE" '
  .roles[] | select(.name == $r) | .owned[]?
' "$REGISTRY" 2>/dev/null)

if [ -z "$OWNED" ]; then
  # No owned list for this role — enforcement cannot apply
  exit 0
fi

# Normalize target to repo-relative if possible
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
REL_TARGET="$TARGET"
if [ -n "$REPO_ROOT" ]; then
  case "$TARGET" in
    "$REPO_ROOT"/*) REL_TARGET="${TARGET#$REPO_ROOT/}" ;;
  esac
fi

# Check if REL_TARGET starts with any owned prefix
ALLOWED=0
while IFS= read -r prefix; do
  [ -z "$prefix" ] && continue
  # Normalize prefix (strip trailing slash)
  prefix="${prefix%/}"
  case "$REL_TARGET" in
    "$prefix"/*|"$prefix") ALLOWED=1; break ;;
  esac
done <<< "$OWNED"

if [ "$ALLOWED" -eq 1 ]; then
  exit 0
fi

# Deny with structured JSON (preferred pattern per HARNESS_SPEC)
OWNED_SUMMARY=$(echo "$OWNED" | tr '\n' ',' | sed 's/,$//')
REASON="Role '$ROLE' may not edit '$REL_TARGET'. Owned: $OWNED_SUMMARY. Hand off to the owning role, or disable FORGE_DIRECTORY_OWNERSHIP to bypass."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
