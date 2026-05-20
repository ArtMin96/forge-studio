#!/usr/bin/env bash
# attribute.sh — Failure attribution via manifest verifier replay
# Usage: attribute.sh [manifest-path] [N]
#   manifest-path: path to change_manifest.jsonl (default: .claude/evolution/change_manifest.jsonl)
#   N: number of most-recent entries to examine (default: 20)
# Exit codes:
#   0 — no suspects found
#   1 — one or more suspects found
#   2 — manifest not found
#   3 — manifest exists but no entries to examine

MANIFEST="${1:-.claude/evolution/change_manifest.jsonl}"
N="${2:-20}"

if [[ ! -f "$MANIFEST" ]]; then
  python3 -c "
import json, sys
print(json.dumps({'error': 'manifest not found', 'manifest_path': sys.argv[1]}, indent=2))
" "$MANIFEST"
  exit 2
fi

python3 - "$MANIFEST" "$N" <<'PYEOF'
import json
import os
import subprocess
import sys

manifest_path = sys.argv[1]
try:
    n = int(sys.argv[2])
except (IndexError, ValueError):
    n = 20

# Read N most-recent lines
try:
    with open(manifest_path, "r", encoding="utf-8") as fh:
        all_lines = [l.strip() for l in fh if l.strip()]
except OSError as exc:
    print(json.dumps({"error": str(exc), "manifest_path": manifest_path}, indent=2))
    sys.exit(2)

recent_lines = all_lines[-n:]
if not recent_lines:
    print(json.dumps({
        "manifest_path": manifest_path,
        "entries_examined": 0,
        "suspects": [],
        "primary_suspect": None
    }, indent=2))
    sys.exit(3)

# Parse entries (skip malformed lines silently — they are not attributable)
entries = []
for line in recent_lines:
    try:
        entries.append(json.loads(line))
    except json.JSONDecodeError:
        pass

# Reverse-chronological order for attribution walk
entries_rev = list(reversed(entries))

suspects = []

def truncate(text, limit=500):
    if text is None:
        return None
    s = str(text)
    return s[:limit] + "..." if len(s) > limit else s

def empty_evidence(entry):
    """Return True when the evidence_bundle is absent, null, {}, or has empty checks_run."""
    if "evidence_bundle" not in entry:
        return True
    bundle = entry["evidence_bundle"]
    if bundle is None:
        return True
    if not isinstance(bundle, dict):
        return True
    if len(bundle) == 0:
        return True
    checks = bundle.get("checks_run")
    if checks is None or checks == []:
        return True
    return False

for entry in entries_rev:
    entry_id = entry.get("id", "")
    ts = entry.get("iso_timestamp", entry.get("ts", ""))
    agent = entry.get("agent_type", entry.get("agent", "unknown"))
    files_raw = entry.get("files", entry.get("write_set", []))
    if isinstance(files_raw, str):
        files_list = [f.strip() for f in files_raw.split(",") if f.strip()]
    elif isinstance(files_raw, list):
        files_list = files_raw
    else:
        files_list = []

    if empty_evidence(entry):
        suspects.append({
            "ts": ts,
            "agent": agent,
            "id": entry_id,
            "files": files_list,
            "reason": "no_evidence",
            "priority": 1,
            "evidence": {
                "command": None,
                "exit_code": None,
                "stdout_tail": None,
                "stderr_tail": None,
            },
        })
        continue

    # Entry has non-empty evidence; check verifier_obligations
    obligations = entry.get("verifier_obligations", [])
    if not obligations:
        # Legacy entry without verifier obligations and with evidence — skip silently
        continue
    if isinstance(obligations, str):
        obligations = [obligations]

    for cmd in obligations:
        if not cmd:
            continue
        try:
            result = subprocess.run(
                ["timeout", "10", "bash", "-c", cmd],
                capture_output=True,
                text=True,
            )
            exit_code = result.returncode
        except OSError:
            # timeout or bash not available — treat as failed
            exit_code = 127
            result = type("R", (), {"stdout": "", "stderr": "bash/timeout unavailable"})()

        if exit_code != 0:
            suspects.append({
                "ts": ts,
                "agent": agent,
                "id": entry_id,
                "files": files_list,
                "reason": "verifier_failed",
                "priority": 2,
                "evidence": {
                    "command": cmd,
                    "exit_code": exit_code,
                    "stdout_tail": truncate(result.stdout),
                    "stderr_tail": truncate(result.stderr),
                },
            })
            break  # First failure per entry is enough

# Sort: priority 1 first, then keep reverse-chrono order within same priority
suspects_sorted = sorted(suspects, key=lambda s: s["priority"])

primary = suspects_sorted[0] if suspects_sorted else None

report = {
    "manifest_path": manifest_path,
    "entries_examined": len(entries),
    "suspects": suspects_sorted,
    "primary_suspect": primary,
}
print(json.dumps(report, indent=2))
sys.exit(1 if suspects_sorted else 0)
PYEOF
