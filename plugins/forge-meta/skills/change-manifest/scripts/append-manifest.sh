#!/usr/bin/env bash
set -euo pipefail
# Append one entry to .claude/evolution/change_manifest.jsonl.
# Argv-driven; called by manifest-writer.sh and directly by users.
# Generates id as chg-<unix-epoch>-<random6hex>; envelope fields come from env.
# Exit 0 on success. Exit 1 on missing required flag.

TYPE=""
DESCRIPTION=""
FILES=""
FAILURE_PATTERN=""
PREDICTED_FIXES=""
RISK_TASKS=""
CONSTRAINT_LEVEL=""
WHY_THIS_COMPONENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)             TYPE="$2";               shift 2 ;;
    --description)      DESCRIPTION="$2";        shift 2 ;;
    --files)            FILES="$2";              shift 2 ;;
    --failure-pattern)  FAILURE_PATTERN="$2";    shift 2 ;;
    --predicted-fixes)  PREDICTED_FIXES="$2";    shift 2 ;;
    --risk-tasks)       RISK_TASKS="$2";         shift 2 ;;
    --constraint-level) CONSTRAINT_LEVEL="$2";   shift 2 ;;
    --why-this-component) WHY_THIS_COMPONENT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$TYPE" ]]; then
  echo "append-manifest.sh: --type is required" >&2
  exit 1
fi

if [[ -z "$DESCRIPTION" ]]; then
  echo "append-manifest.sh: --description is required" >&2
  exit 1
fi

ISO_TIMESTAMP=$(date -u +%FT%TZ)
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
AGENT_TYPE_ENV="${CLAUDE_AGENT_TYPE:-unknown}"

EPOCH=$(date +%s)
RAND_HEX=$(python3 -c "import random; print('%06x' % random.randint(0, 16**6 - 1))")
ENTRY_ID="chg-${EPOCH}-${RAND_HEX}"

MANIFEST_FILE=".claude/evolution/change_manifest.jsonl"
mkdir -p "$(dirname "$MANIFEST_FILE")"

# Pass values via env to avoid shell-into-Python source interpolation;
# any quote, backslash, or newline in inputs would otherwise break parsing.
export MF_ID="$ENTRY_ID" \
       MF_TS="$ISO_TIMESTAMP" \
       MF_SESSION="$SESSION_ID" \
       MF_AGENT="$AGENT_TYPE_ENV" \
       MF_TYPE="$TYPE" \
       MF_DESC="$DESCRIPTION" \
       MF_FILES="$FILES" \
       MF_FAILPAT="$FAILURE_PATTERN" \
       MF_PREDFIX="$PREDICTED_FIXES" \
       MF_RISKTASK="$RISK_TASKS" \
       MF_CONSTRAINT="$CONSTRAINT_LEVEL" \
       MF_WHY="$WHY_THIS_COMPONENT" \
       MF_PATH="$MANIFEST_FILE"

python3 <<'PYEOF'
import json, os

entry = {
    "id":            os.environ["MF_ID"],
    "iso_timestamp": os.environ["MF_TS"],
    "session_id":    os.environ["MF_SESSION"],
    "agent_type":    os.environ["MF_AGENT"],
    "type":          os.environ["MF_TYPE"],
    "description":   os.environ["MF_DESC"],
}

for env_key, json_key in [
    ("MF_FILES",       "files"),
    ("MF_FAILPAT",     "failure_pattern"),
    ("MF_PREDFIX",     "predicted_fixes"),
    ("MF_RISKTASK",    "risk_tasks"),
    ("MF_CONSTRAINT",  "constraint_level"),
    ("MF_WHY",         "why_this_component"),
]:
    v = os.environ.get(env_key, "").strip()
    if v:
        entry[json_key] = v

with open(os.environ["MF_PATH"], "a") as f:
    f.write(json.dumps(entry) + "\n")
PYEOF

ROTATE_SCRIPT="$(dirname "$0")/rotate.sh"
[ -x "$ROTATE_SCRIPT" ] && bash "$ROTATE_SCRIPT" "$MANIFEST_FILE" 2>/dev/null || true
