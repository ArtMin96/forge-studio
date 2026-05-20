#!/usr/bin/env bash
# Append a transactional change-manifest entry to .claude/evolution/change_manifest.jsonl.
# Positional args: <agent_name> <why>
# New fields read from env vars — all optional. Legacy callers (no env vars set) produce
# the same shape as before: only the core envelope + agent/why fields.
#
# Env vars accepted:
#   MANIFEST_READ_SET           newline-separated paths Read before the edit
#   MANIFEST_WRITE_SET          newline-separated paths written
#   MANIFEST_ASSUMPTIONS        newline-separated falsifiable statements relied on
#   MANIFEST_VERIFIER_OBLIGATIONS  newline-separated shell commands that confirm the work
#   MANIFEST_CHECKS_RUN         newline-separated checks that passed at write time
#   MANIFEST_ASSUMPTIONS_PRESERVED  newline-separated assumptions verified before writing
#   MANIFEST_UNTESTED_REGIONS   newline-separated regions not tested (explicit [] = fully tested)
#   MANIFEST_REMAINING_RISKS    newline-separated residual risks
#   MANIFEST_ROLLBACK_HANDLE    single string: command or git ref that reverses the change
#   MANIFEST_CONTRACT_YAML      multi-line YAML string containing change_contract fields;
#                               embedded under evidence_bundle.contract in the manifest entry.
#                               If jq is available, parsed to a JSON sub-object; otherwise
#                               embedded as a raw YAML string under evidence_bundle.contract_yaml.
set -euo pipefail

AGENT_NAME="${1:-unknown}"
WHY="${2:-}"

ISO_TIMESTAMP=$(date -u +%FT%TZ)
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-${AGENT_NAME}}"

EPOCH=$(date +%s)
RAND_HEX=$(python3 -c "import random; print('%06x' % random.randint(0, 16**6 - 1))")
ENTRY_ID="chg-${EPOCH}-${RAND_HEX}"

MANIFEST_FILE=".claude/evolution/change_manifest.jsonl"
mkdir -p "$(dirname "$MANIFEST_FILE")"

# Pass all values via env to avoid shell interpolation hazards with quotes/backslashes/newlines.
export MF_ID="$ENTRY_ID" \
       MF_TS="$ISO_TIMESTAMP" \
       MF_SESSION="$SESSION_ID" \
       MF_AGENT="$AGENT_TYPE" \
       MF_WHY="$WHY" \
       MF_PATH="$MANIFEST_FILE" \
       MF_READ_SET="${MANIFEST_READ_SET:-}" \
       MF_WRITE_SET="${MANIFEST_WRITE_SET:-}" \
       MF_ASSUMPTIONS="${MANIFEST_ASSUMPTIONS:-}" \
       MF_VERIFIER="${MANIFEST_VERIFIER_OBLIGATIONS:-}" \
       MF_CHECKS_RUN="${MANIFEST_CHECKS_RUN:-}" \
       MF_ASSUMP_PRESERVED="${MANIFEST_ASSUMPTIONS_PRESERVED:-}" \
       MF_UNTESTED="${MANIFEST_UNTESTED_REGIONS:-}" \
       MF_REMAINING="${MANIFEST_REMAINING_RISKS:-}" \
       MF_ROLLBACK="${MANIFEST_ROLLBACK_HANDLE:-}" \
       MF_CONTRACT_YAML="${MANIFEST_CONTRACT_YAML:-}"

python3 <<'PYEOF'
import json, os

def lines_to_list(val):
    """Split newline-separated env var into a list, stripping blanks."""
    return [s for s in val.splitlines() if s.strip()]

entry = {
    "id":            os.environ["MF_ID"],
    "iso_timestamp": os.environ["MF_TS"],
    "session_id":    os.environ["MF_SESSION"],
    "agent_type":    os.environ["MF_AGENT"],
    "type":          "manifest-entry",
    "description":   os.environ["MF_WHY"],
}

# Transactional state — omit when env var is empty
read_set = lines_to_list(os.environ.get("MF_READ_SET", ""))
if read_set:
    entry["read_set"] = read_set

write_set = lines_to_list(os.environ.get("MF_WRITE_SET", ""))
if write_set:
    entry["write_set"] = write_set

assumptions = lines_to_list(os.environ.get("MF_ASSUMPTIONS", ""))
if assumptions:
    entry["assumptions"] = assumptions

verifier = lines_to_list(os.environ.get("MF_VERIFIER", ""))
if verifier:
    entry["verifier_obligations"] = verifier

rollback = os.environ.get("MF_ROLLBACK", "").strip()
if rollback:
    entry["rollback_handle"] = rollback

# Evidence bundle — only emit the sub-object if at least one field is non-empty
checks_run          = lines_to_list(os.environ.get("MF_CHECKS_RUN", ""))
assump_preserved    = lines_to_list(os.environ.get("MF_ASSUMP_PRESERVED", ""))
untested            = lines_to_list(os.environ.get("MF_UNTESTED", ""))
remaining           = lines_to_list(os.environ.get("MF_REMAINING", ""))

bundle = {}
if checks_run:
    bundle["checks_run"] = checks_run
if assump_preserved:
    bundle["assumptions_preserved"] = assump_preserved
if untested:
    bundle["untested_regions"] = untested
if remaining:
    bundle["remaining_risks"] = remaining

if bundle:
    entry["evidence_bundle"] = bundle

# Change contract — embed under evidence_bundle.contract when MANIFEST_CONTRACT_YAML is set.
# Uses yaml.safe_load when pyyaml is available (produces a JSON-safe dict);
# falls back to embedding the raw YAML string under evidence_bundle.contract_yaml.
contract_yaml = os.environ.get("MF_CONTRACT_YAML", "").strip()
if contract_yaml:
    eb = entry.setdefault("evidence_bundle", {})
    try:
        import yaml as _yaml
        parsed = _yaml.safe_load(contract_yaml)
        if isinstance(parsed, dict):
            # Unwrap one level if the YAML root key is "change_contract"
            contract_obj = parsed.get("change_contract", parsed)
            eb["contract"] = contract_obj
        else:
            eb["contract_yaml"] = contract_yaml
    except Exception:
        # pyyaml absent or parse error — fall back to raw string
        eb["contract_yaml"] = contract_yaml

line = json.dumps(entry)

# Validate before appending — catch encoding or structural errors early.
json.loads(line)

with open(os.environ["MF_PATH"], "a") as f:
    f.write(line + "\n")
PYEOF

ROTATE_SCRIPT="$(dirname "$0")/rotate.sh"
[ -x "$ROTATE_SCRIPT" ] && bash "$ROTATE_SCRIPT" "$MANIFEST_FILE" 2>/dev/null || true
