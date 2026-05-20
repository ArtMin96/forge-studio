#!/usr/bin/env bash
set -euo pipefail
# Generate a per-session AHE rollup digest from change_manifest.jsonl and handoffs.jsonl.
# Writes to .claude/sessions/<session-id>-digest.md. Idempotent; overwrites on each run.
# Always exits 0 — this is observability only, never a gate.

SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id) SESSION_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
fi

MANIFEST_FILE=".claude/evolution/change_manifest.jsonl"
HANDOFFS_FILE=".claude/handoffs.jsonl"
OUTPUT_DIR=".claude/sessions"
OUTPUT_FILE="${OUTPUT_DIR}/${SESSION_ID}-digest.md"
MAX_BYTES=10240
TRUNCATION_MARKER="... (truncated to 10KB) ..."

mkdir -p "$OUTPUT_DIR"

# Use Python for all JSON parsing to handle special characters safely.
python3 - "$SESSION_ID" "$MANIFEST_FILE" "$HANDOFFS_FILE" "$OUTPUT_FILE" "$MAX_BYTES" "$TRUNCATION_MARKER" <<'PYEOF'
import sys, json, os

session_id    = sys.argv[1]
manifest_path = sys.argv[2]
handoffs_path = sys.argv[3]
output_path   = sys.argv[4]
max_bytes     = int(sys.argv[5])
trunc_marker  = sys.argv[6]

# --- Load manifest entries for this session ---
entries = []
if os.path.isfile(manifest_path):
    with open(manifest_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                if obj.get("session_id") == session_id:
                    entries.append(obj)
            except json.JSONDecodeError:
                pass

# --- Load handoff events (not filtered by session — no session_id in handoffs.jsonl) ---
handoff_open = 0
handoff_resolved = 0
handoff_skipped = 0
if os.path.isfile(handoffs_path):
    with open(handoffs_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                ev = obj.get("event", "")
                if ev == "handoff_open":
                    handoff_open += 1
                elif ev == "handoff_resolved":
                    handoff_resolved += 1
                elif ev == "handoff_skipped":
                    handoff_skipped += 1
            except json.JSONDecodeError:
                pass

# --- Build Component section ---
def section_component(entries, handoff_open, handoff_resolved, handoff_skipped):
    lines = ["## Component", ""]
    lines.append("_Plugins and events active during this session._")
    lines.append("")

    if entries:
        # Count by type
        type_counts = {}
        for e in entries:
            t = e.get("type", "unknown")
            type_counts[t] = type_counts.get(t, 0) + 1
        lines.append(f"**Manifest entries**: {len(entries)} total")
        lines.append("")
        lines.append("| Type | Count |")
        lines.append("|---|---|")
        for t, c in sorted(type_counts.items()):
            lines.append(f"| `{t}` | {c} |")
    else:
        lines.append("_no entries for this session_")

    lines.append("")
    lines.append("**Handoffs** (lifetime totals in handoffs.jsonl):")
    lines.append(f"- open: {handoff_open}")
    lines.append(f"- resolved: {handoff_resolved}")
    lines.append(f"- skipped: {handoff_skipped}")
    return "\n".join(lines)

# --- Build Experience section ---
def section_experience(entries):
    lines = ["## Experience", ""]
    lines.append("_Per-task outcomes recorded in the manifest for this session._")
    lines.append("")

    if not entries:
        lines.append("_no entries for this session_")
        return "\n".join(lines)

    for e in entries:
        lines.append(f"### `{e.get('type', 'unknown')}` — {e.get('description', '')}")
        ts = e.get("iso_timestamp", "")
        if ts:
            lines.append(f"- **time**: {ts}")
        agent = e.get("agent_type", "")
        if agent:
            lines.append(f"- **agent**: {agent}")
        files = e.get("files", "")
        if files:
            lines.append(f"- **files**: {files}")
        fp = e.get("failure_pattern", "")
        if fp:
            lines.append(f"- **failure_pattern**: {fp}")
        lines.append("")

    return "\n".join(lines)

# --- Build Decision section ---
def section_decision(entries):
    lines = ["## Decision", ""]
    lines.append("_Change-manifest deltas: aggregated counts and predicted impact._")
    lines.append("")

    if not entries:
        lines.append("_no entries for this session_")
        return "\n".join(lines)

    lines.append(f"**Total manifest entries this session**: {len(entries)}")
    lines.append("")

    # Aggregate predicted_fixes
    predicted = [e["predicted_fixes"] for e in entries if e.get("predicted_fixes")]
    if predicted:
        lines.append("**Predicted fixes**:")
        for p in predicted:
            lines.append(f"- {p}")
        lines.append("")

    # Aggregate risk_tasks
    risks = [e["risk_tasks"] for e in entries if e.get("risk_tasks")]
    if risks:
        lines.append("**Risk tasks**:")
        for r in risks:
            lines.append(f"- {r}")
        lines.append("")

    # Constraint levels
    constraints = [e["constraint_level"] for e in entries if e.get("constraint_level")]
    if constraints:
        from collections import Counter
        ctr = Counter(constraints)
        lines.append("**Constraint levels**: " + ", ".join(f"{k}: {v}" for k, v in sorted(ctr.items())))
        lines.append("")

    # Assumptions count — aggregate from all entries with assumptions lists
    total_assumptions = 0
    for e in entries:
        a = e.get("assumptions", [])
        if isinstance(a, list):
            total_assumptions += len(a)
        elif a:
            total_assumptions += 1
    if total_assumptions > 0:
        lines.append(f"**Total assumptions declared: {total_assumptions}**")
        lines.append("")

    # Remaining risks — surface any non-empty lists verbatim (high signal for follow-up)
    all_remaining = []
    for e in entries:
        bundle = e.get("evidence_bundle") or {}
        remaining = bundle.get("remaining_risks", [])
        if isinstance(remaining, list):
            all_remaining.extend(remaining)
        elif remaining:
            all_remaining.append(remaining)
    if all_remaining:
        lines.append("**Remaining risks**:")
        for r in all_remaining:
            lines.append(f"- {r}")
        lines.append("")

    return "\n".join(lines)

# --- Assemble full document ---
header = f"# Session Digest: {session_id}\n\nGenerated by forge-meta/session-digest.\n"
comp   = section_component(entries, handoff_open, handoff_resolved, handoff_skipped)
exp    = section_experience(entries)
dec    = section_decision(entries)

full_content = "\n\n".join([header, comp, exp, dec]) + "\n"

# --- Apply 10KB cap (final file size, marker included, MUST be ≤ max_bytes) ---
encoded = full_content.encode("utf-8")
if len(encoded) > max_bytes:
    marker_block = ("\n" + trunc_marker + "\n").encode("utf-8")
    body_budget = max_bytes - len(marker_block)
    # Cut at the last newline within budget so we don't slice mid-token.
    cut = encoded.rfind(b"\n", 0, body_budget)
    if cut <= 0:
        cut = body_budget
    full_content = encoded[:cut].decode("utf-8", errors="ignore") + marker_block.decode("utf-8")

with open(output_path, "w") as f:
    f.write(full_content)

PYEOF
