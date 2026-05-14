#!/usr/bin/env bash
set -euo pipefail

# Detect repeated (tool, args) fingerprints within a sliding window of 20 calls.
# Exits:
#   0 — no repetition concern
#   1 — warning (fingerprint seen >=3 times in last 20 calls)
#   2 — block  (fingerprint seen >=5 times in last 20 calls)
# Delete /tmp/forge-doom-${CLAUDE_SESSION_ID} to override a block.

input=$(cat)

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)

# If tool_name is empty or missing, exit silently — don't track unknown calls.
if [[ -z "$tool_name" ]]; then
  exit 0
fi

tool_input=$(printf '%s' "$input" | jq -c '.tool_input // {}' 2>/dev/null || true)

# Compute md5 of the serialised tool_input JSON.
input_hash=$(printf '%s' "$tool_input" | md5sum | awk '{print $1}')

fingerprint="${tool_name}	${input_hash}"

state_file="/tmp/forge-doom-${CLAUDE_SESSION_ID:-default}"

# Append the new fingerprint first, then read the window (inclusive of this call).
printf '%s\n' "$fingerprint" >> "$state_file"
# Trim to the last 20 lines after appending.
trimmed=$(tail -20 "$state_file")
printf '%s\n' "$trimmed" > "$state_file"

# Count occurrences of this fingerprint within the current 20-line window.
count=$(grep -cF "$fingerprint" "$state_file" || true)

# Emit warnings / block based on count within the window (including this call).
if (( count >= 5 )); then
  echo "[forge-diagnostics] possible doom-loop: tool=${tool_name} repeated ${count} times in last 20 calls. Block — delete ${state_file} to override." >&2
  exit 2
elif (( count >= 3 )); then
  echo "[forge-diagnostics] possible doom-loop: tool=${tool_name} repeated ${count} times in last 20 calls." >&2
  exit 1
fi

exit 0
