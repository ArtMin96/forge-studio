#!/usr/bin/env bash
# PreToolUse:Edit|Write hook — controllability boundary guard.
#
# Blocks edits to protected paths when the request originates from the
# self-evolution loop (FORGE_META_EVOLVE=1). Human invocations (no env var)
# pass through silently.
#
# Exit codes: 0 = allow, 2 = block (PreToolUse semantics per HARNESS_SPEC.md).
# Protected-path list is parsed from POLICY.md at runtime (Step 3).
set -euo pipefail

# Step 1: human-edit fast path — no env var means no restriction.
if [[ "${FORGE_META_EVOLVE:-0}" != "1" ]]; then
  exit 0
fi

# Step 2: extract file_path from JSON stdin.
raw_input="$(cat)"
file_path="$(printf '%s' "$raw_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Step 3: build protected-path list from POLICY.md at runtime so the guard
# and policy document can never drift silently.
# Fallback list below activates only when POLICY.md is unreadable or yields
# no entries (e.g., the file is missing during bootstrapping).
_fallback_protected_paths=(
  "plugins/evaluator/skills/verify/"
  "plugins/evaluator/skills/healthcheck/"
  "plugins/diagnostics/skills/entropy-scan/scripts/count.sh"
  "CLAUDE.md"
  "HARNESS_SPEC.md"
  "plugins/forge-meta/POLICY.md"
)

policy_file="${CLAUDE_PROJECT_DIR:-.}/plugins/forge-meta/POLICY.md"

mapfile -t protected_paths < <(
  awk '
    /^## Protected Paths/ { in_section=1; next }
    in_section && /^## / { exit }
    in_section && /^- `/ { print }
  ' "$policy_file" 2>/dev/null | grep -oE '`[^`]+`' | tr -d '`'
)

if [[ ${#protected_paths[@]} -eq 0 ]]; then
  echo "[forge-meta] WARNING: POLICY.md unreadable or empty, using fallback list" >&2
  protected_paths=("${_fallback_protected_paths[@]}")
fi

# Step 4: normalize to repo-relative. Claude Code's Edit/Write tools mandate
# absolute paths, so we resolve the repo root (preferring CLAUDE_PROJECT_DIR,
# then git toplevel, then cwd) and strip the prefix. Without this, an absolute
# /home/.../CLAUDE.md would silently bypass the guard.
repo_root="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "$repo_root" ]]; then
  repo_root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
repo_root="${repo_root%/}"

normalized="${file_path#./}"
if [[ "$normalized" == "$repo_root"/* ]]; then
  normalized="${normalized#$repo_root/}"
fi

# Step 5: match against each protected path.
for protected in "${protected_paths[@]}"; do
  if [[ "$protected" == */ ]]; then
    # Directory prefix match.
    if [[ "$normalized" == "$protected"* || "$normalized" == "${protected%/}" ]]; then
      echo "[forge-meta] policy block: $file_path is protected by POLICY.md. Set FORGE_META_EVOLVE=0 or unset to override (you're presumably running outside the self-evolution loop)." >&2
      exit 2
    fi
  else
    # Exact file match.
    if [[ "$normalized" == "$protected" ]]; then
      echo "[forge-meta] policy block: $file_path is protected by POLICY.md. Set FORGE_META_EVOLVE=0 or unset to override (you're presumably running outside the self-evolution loop)." >&2
      exit 2
    fi
  fi
done

# Step 6: not a protected path — allow.
exit 0
