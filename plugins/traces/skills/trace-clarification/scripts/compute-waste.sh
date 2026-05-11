#!/usr/bin/env bash
# compute-waste.sh — walk a JSONL trace file and emit a per-session
# clarification-waste table.
#
# Usage: compute-waste.sh [path-to-trace.jsonl]
# Without an argument, uses the most recent file in ~/.claude/traces/.

TRACE_FILE="${1:-}"

if [[ -z "$TRACE_FILE" ]]; then
  TRACE_FILE=$(stat -c '%Y %n' "$HOME/.claude/traces"/*.jsonl 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [[ -z "$TRACE_FILE" || ! -f "$TRACE_FILE" ]]; then
  echo "No trace file found." >&2
  exit 0
fi

# Extract the session name from the filename (basename without extension)
SESSION=$(basename "$TRACE_FILE" .jsonl)

# Count user_turn events to decide whether to continue
USER_TURN_COUNT=$(jq -r 'select(.type == "user_turn") | .type' "$TRACE_FILE" 2>/dev/null | wc -l)

if [[ "$USER_TURN_COUNT" -eq 0 ]]; then
  echo "No user_turn events found in $TRACE_FILE"
  exit 0
fi

# Walk lines: track action count between user_turn boundaries
# Variables: first_turn_seen, actions_since_last_turn, total_actions,
#            first_clarify_at, actions_before_first_clarify, reported
python3 - "$TRACE_FILE" "$SESSION" <<'PYEOF'
import sys, json

trace_path = sys.argv[1]
session    = sys.argv[2]

total_actions          = 0
actions_since_turn     = 0
first_turn_seen        = False
first_clarify_at       = None
actions_before_clarify = None

with open(trace_path) as fh:
    for raw in fh:
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except json.JSONDecodeError:
            continue

        t = entry.get("type", "")

        if t == "user_turn":
            if not first_turn_seen:
                first_turn_seen = True
                actions_since_turn = 0
            else:
                # This is a clarification candidate
                if first_clarify_at is None:
                    first_clarify_at       = total_actions + 1
                    actions_before_clarify = actions_since_turn
                actions_since_turn = 0
        elif t in ("bash", "file"):
            total_actions      += 1
            actions_since_turn += 1

# Emit table
print("| session | first_clarify_at_action | actions_before_first_clarify | total_actions | waste_ratio |")
print("|---------|------------------------|------------------------------|---------------|-------------|")

if first_clarify_at is None:
    ratio = "0.00"
    row = f"| {session} | — | 0 | {total_actions} | {ratio} |"
else:
    ratio = f"{actions_before_clarify / total_actions:.2f}" if total_actions else "0.00"
    row = f"| {session} | {first_clarify_at} | {actions_before_clarify} | {total_actions} | {ratio} |"

print(row)
PYEOF
