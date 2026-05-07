#!/usr/bin/env bash
# Stop: block end-of-turn when the last assistant message claims completion
# without supporting evidence in the same or recent turns.
#
# Evidence accepted: any tool_use in the last 3 assistant messages (Bash,
# Edit, Write, Read, Grep), any /verify or /challenge invocation, any fenced
# code block whose first line begins with $ or #, or any file:line citation.
#
# Disable: FORGE_PROOF_OF_DONE=0

set -u

if [ "${FORGE_PROOF_OF_DONE:-1}" = "0" ]; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$ACTIVE" = "true" ]; then
  exit 0
fi

TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Reverse-read transcript (tac is GNU-only; use awk for macOS/BSD portability).
reverse_lines() {
  awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$1"
}

# Last assistant message text.
LAST_TEXT=$(reverse_lines "$TRANSCRIPT" 2>/dev/null \
  | jq -rc 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null \
  | head -50)

if [ -z "$LAST_TEXT" ]; then
  exit 0
fi

# Strip fenced code blocks before scanning for claim words — code samples and
# quoted output often legitimately contain "done"/"passing".
STRIPPED=$(echo "$LAST_TEXT" | awk 'BEGIN{f=0} /^```/{f=1-f; next} f==0 {print}')

CLAIM=$(echo "$STRIPPED" | grep -iEo '\b(done|fixed|complete|completed|passing|passed|works|working|ready|shipped|all set|good to go)\b' | head -1)

if [ -z "$CLAIM" ]; then
  exit 0
fi

# Look for evidence in last 3 assistant messages.
RECENT=$(reverse_lines "$TRANSCRIPT" 2>/dev/null \
  | jq -rc 'select(.type=="assistant") | .message.content[]?' 2>/dev/null \
  | head -300)

EVIDENCE=0

# 1. Any tool_use in the last 3 assistant turns.
TOOLS=$(echo "$RECENT" | jq -rc 'select(.type=="tool_use") | .name' 2>/dev/null | head -20)
if [ -n "$TOOLS" ]; then
  EVIDENCE=1
fi

# 2. /verify or /challenge invocation in last assistant text.
if echo "$LAST_TEXT" | grep -qE '/verify|/challenge|/verify-refs'; then
  EVIDENCE=1
fi

# 3. file:line citation (e.g. plugins/foo/bar.sh:42).
if echo "$LAST_TEXT" | grep -qE '[/.A-Za-z0-9_-]+\.[A-Za-z]+:[0-9]+'; then
  EVIDENCE=1
fi

# 4. Fenced shell-style block (line begins with $ or # inside ```).
if echo "$LAST_TEXT" | awk 'BEGIN{f=0} /^```/{f=1-f; next} f==1 && /^[$#] /{found=1} END{exit !found}'; then
  EVIDENCE=1
fi

if [ "$EVIDENCE" = "1" ]; then
  exit 0
fi

REASON="Completion claim ('${CLAIM}') detected without proof. Run /verify or attach pasted command output, file:line, or test result before ending the turn."
jq -nc --arg r "$REASON" '{decision:"block", reason:$r}'
exit 0
