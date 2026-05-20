#!/usr/bin/env bash
# Belief-state audit: compare last-known sha256 signatures against disk.
# Usage: audit.sh [N]   (default N=5)
# Exit 0 = no drift, exit 1 = drift detected or missing files found.

set -euo pipefail

N="${1:-5}"

STATE_FILE="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/state/belief.jsonl"

if [ ! -f "$STATE_FILE" ]; then
  echo "## Belief-State Audit"
  echo ""
  echo "No snapshots recorded yet. (.claude/state/belief.jsonl not found)"
  exit 0
fi

# Take the latest entry per unique path, limit to N most-recent unique paths.
# Strategy: read all lines, pick the last occurrence of each path (latest ts),
# then take the N most-recent by timestamp.
PATHS_AND_HASHES=$(python3 - "$STATE_FILE" "$N" <<'PY'
import json, sys

state_file = sys.argv[1]
n = int(sys.argv[2])

latest = {}  # path -> {ts, sha256, op}
OP_RANK = {"post": 1, "pre": 0}  # post wins ties — it's the settled state after an edit
with open(state_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        path = entry.get("path", "")
        ts = entry.get("ts", "")
        sha = entry.get("sha256", "")
        op = entry.get("op", "pre")
        if not path or not sha:
            continue
        cur = latest.get(path)
        if cur is None:
            latest[path] = {"ts": ts, "sha256": sha, "op": op}
        elif ts > cur["ts"]:
            latest[path] = {"ts": ts, "sha256": sha, "op": op}
        elif ts == cur["ts"] and OP_RANK.get(op, 0) > OP_RANK.get(cur["op"], 0):
            # same timestamp: prefer the post-edit snapshot over pre-edit
            latest[path] = {"ts": ts, "sha256": sha, "op": op}

# Sort by ts descending, take top N
sorted_entries = sorted(latest.items(), key=lambda x: x[1]["ts"], reverse=True)[:n]

for path, info in sorted_entries:
    print(f"{info['sha256']}  {path}")
PY
)

if [ -z "$PATHS_AND_HASHES" ]; then
  echo "## Belief-State Audit"
  echo ""
  echo "No valid snapshot entries found in $STATE_FILE."
  exit 0
fi

DRIFT_COUNT=0
CHECKED=0
DRIFT_ROWS=""
OK_COUNT=0

while IFS= read -r line; do
  RECORDED_SHA=$(echo "$line" | awk '{print $1}')
  FILE_PATH=$(echo "$line" | awk '{$1=""; print substr($0,2)}')

  CHECKED=$((CHECKED + 1))

  if [ ! -f "$FILE_PATH" ]; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    DRIFT_ROWS="${DRIFT_ROWS}| \`${FILE_PATH}\` | ${RECORDED_SHA} | FILE MISSING |\n"
    continue
  fi

  CURRENT_SHA=$(sha256sum "$FILE_PATH" 2>/dev/null | awk '{print $1}' || true)
  if [ -z "$CURRENT_SHA" ]; then
    echo "Warning: sha256sum unavailable — cannot audit $FILE_PATH" >&2
    continue
  fi

  if [ "$RECORDED_SHA" != "$CURRENT_SHA" ]; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    DRIFT_ROWS="${DRIFT_ROWS}| \`${FILE_PATH}\` | ${RECORDED_SHA} | ${CURRENT_SHA} |\n"
  else
    OK_COUNT=$((OK_COUNT + 1))
  fi
done <<< "$PATHS_AND_HASHES"

echo "## Belief-State Audit (${CHECKED} file(s) checked)"
echo ""

if [ "$DRIFT_COUNT" -eq 0 ]; then
  echo "All ${CHECKED} file(s) match recorded signatures."
  exit 0
fi

printf "DRIFT DETECTED — %d file(s) have changed since last snapshot:\n\n" "$DRIFT_COUNT"
echo "| Path | Recorded sha256 | Current sha256 |"
echo "|------|-----------------|----------------|"
printf "%b" "$DRIFT_ROWS"
echo ""
if [ "$OK_COUNT" -gt 0 ]; then
  echo "${OK_COUNT} file(s) matched (no drift)."
fi
echo ""
echo "Re-read the flagged files before editing."

exit 1
