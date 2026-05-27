#!/usr/bin/env bash
# Compute seven harness-level dimensions from existing Forge Studio artifacts.
# Output: Markdown table to stdout + .claude/metrics/<YYYY-MM-DD>.json
# Usage: score.sh [manifest-path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

MANIFEST_PATH="${1:-$REPO_ROOT/.claude/evolution/change_manifest.jsonl}"
TRACES_DIR="$REPO_ROOT/.claude/traces"
BELIEF_LOG="$REPO_ROOT/.claude/state/belief.jsonl"
MEMORY_TOPICS_DIR="$REPO_ROOT/.claude/memory/topics"
METRICS_DIR="$REPO_ROOT/.claude/metrics"
TODAY="$(date +%Y-%m-%d)"

# --------------------------------------------------------------------------
# Helper: safe_pct numerator denominator
# --------------------------------------------------------------------------
safe_pct() {
  local num="$1" den="$2"
  if [ "$den" -eq 0 ]; then
    echo "n/a"
  else
    python3 -c "print(f'{round(100*${num}/${den})}%')"
  fi
}

# --------------------------------------------------------------------------
# Delegate all manifest parsing to Python to avoid shell interpolation bugs.
# manifest_stats <manifest_path> writes TAB-separated output:
#   line 1: <total_entries>
#   line 2: <verified_count>   (non-empty checks_run)
#   line 3: <with_handle_count> (non-empty rollback_handle)
# --------------------------------------------------------------------------
manifest_stats() {
  python3 - "$1" <<'PYEOF'
import sys, json

path = sys.argv[1]
total = 0
verified = 0
with_handle = 0

try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            total += 1
            try:
                entry = json.loads(line)
            except Exception:
                continue

            # verified: evidence_bundle must be a dict with a non-empty checks_run list
            eb = entry.get("evidence_bundle")
            if (eb is not None
                    and isinstance(eb, dict)
                    and isinstance(eb.get("checks_run"), list)
                    and len(eb["checks_run"]) > 0):
                verified += 1

            # replayable: rollback_handle must be a non-empty string
            h = entry.get("rollback_handle", "")
            if h and str(h).strip():
                with_handle += 1

except Exception:
    pass

print(total)
print(verified)
print(with_handle)
PYEOF
}

# --------------------------------------------------------------------------
# belief_stats <belief_log> writes:
#   line 1: <score_percent_string>  e.g. "97%" or "n/a"
#   line 2: <notes_string>
# --------------------------------------------------------------------------
belief_stats() {
  python3 - "$1" <<'PYEOF'
import sys, json

log_path = sys.argv[1]
pre = {}
drifts = 0
edits = 0

try:
    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            op   = entry.get("op", "")
            path = entry.get("path", "")
            sha  = entry.get("sha256", "")
            if op == "pre":
                pre[path] = sha
                edits += 1
            elif op == "post":
                # Drift: pre and post hashes are identical — the snapshot recorded
                # no change, suggesting the edit didn't land or was a no-op stale write.
                if path in pre and pre[path] == sha:
                    drifts += 1
except Exception:
    print("n/a")
    print("belief log unreadable")
    sys.exit(0)

if edits == 0:
    print("n/a")
    print("belief log present but no edit pairs")
    sys.exit(0)

score = round((1 - drifts / edits) * 100)
print(f"{score}%")
print(f"{drifts} drift(s) in {edits} edit calls")
PYEOF
}

# --------------------------------------------------------------------------
# memory_hygiene_stats <topics_dir> <window_days> writes:
#   line 1: <score_percent_string>  e.g. "80%" or "n/a"
#   line 2: <notes_string>
# A topic file is "fresh" if its "Last verified:" date is within window_days
# of today. Files that lack the field are counted as stale.
# --------------------------------------------------------------------------
memory_hygiene_stats() {
  python3 - "$1" "$2" <<'PYEOF'
import sys, os, re, datetime

topics_dir = sys.argv[1]
window_days = int(sys.argv[2])
today = datetime.date.today()
cutoff = today - datetime.timedelta(days=window_days)

total = 0
fresh = 0

try:
    files = [f for f in os.listdir(topics_dir) if f.endswith(".md")]
except Exception:
    print("n/a")
    print("topics directory unreadable")
    sys.exit(0)

if not files:
    print("n/a")
    print("no topic files found")
    sys.exit(0)

date_re = re.compile(r"Last verified:\s*(\d{4}-\d{2}-\d{2})")
for fname in files:
    fpath = os.path.join(topics_dir, fname)
    total += 1
    try:
        with open(fpath) as fh:
            content = fh.read()
        m = date_re.search(content)
        if m:
            verified_date = datetime.date.fromisoformat(m.group(1))
            if verified_date >= cutoff:
                fresh += 1
    except Exception:
        pass  # unreadable file counts as stale

score = round(100 * fresh / total)
print(f"{score}%")
print(f"{fresh} / {total} topics verified within {window_days} days")
PYEOF
}

# --------------------------------------------------------------------------
# 1. trajectory_efficiency
# --------------------------------------------------------------------------
traj_score="n/a"
traj_note="no traces directory"

if [ -d "$TRACES_DIR" ] && ls "$TRACES_DIR"/*.jsonl 2>/dev/null | head -1 > /dev/null; then
  total_tool_calls=$(cat "$TRACES_DIR"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
  if [ -f "$MANIFEST_PATH" ]; then
    accepted=$(grep -c '.' "$MANIFEST_PATH" 2>/dev/null || echo 0)
  else
    accepted=0
  fi
  if [ "$total_tool_calls" -eq 0 ]; then
    traj_score="n/a"
    traj_note="traces present but empty"
  else
    traj_score=$(python3 -c "print(f'{round(100*${accepted}/${total_tool_calls})}%')")
    traj_note="${accepted} accepted / ${total_tool_calls} tool calls"
  fi
fi

# --------------------------------------------------------------------------
# 2. verification_strength + 6. replayability (single manifest pass)
# --------------------------------------------------------------------------
vs_score="n/a"
vs_note="no manifest"
vs_verified=0
vs_total=0
rp_score="n/a"
rp_note="no manifest"
rp_with_handle=0
rp_total=0

if [ -f "$MANIFEST_PATH" ]; then
  readarray -t stats < <(manifest_stats "$MANIFEST_PATH")
  vs_total="${stats[0]:-0}"
  vs_verified="${stats[1]:-0}"
  rp_with_handle="${stats[2]:-0}"
  rp_total="$vs_total"

  if [ "$vs_total" -eq 0 ]; then
    vs_score="n/a"; vs_note="manifest empty"
    rp_score="n/a"; rp_note="manifest empty"
  else
    vs_score=$(safe_pct "$vs_verified" "$vs_total")
    vs_note="${vs_verified} / ${vs_total} entries verified"
    rp_score=$(safe_pct "$rp_with_handle" "$rp_total")
    rp_note="${rp_with_handle} / ${rp_total} entries have rollback_handle"
  fi
fi

# --------------------------------------------------------------------------
# 3. recovery_ability
# --------------------------------------------------------------------------
ra_score="n/a"
ra_note="no verify-failure history"

hook_log="$REPO_ROOT/.claude/state/hook-blocks.jsonl"
if [ -f "$hook_log" ]; then
  failures=$(grep -c '"verify.*fail\|fail.*verify"' "$hook_log" 2>/dev/null || echo 0)
  recoveries=$(grep -c '"verify.*pass\|pass.*verify"' "$hook_log" 2>/dev/null || echo 0)
  if [ "$failures" -gt 0 ]; then
    ra_score=$(safe_pct "$recoveries" "$failures")
    ra_note="${recoveries} recoveries / ${failures} failures"
  fi
fi

# --------------------------------------------------------------------------
# 4. state_consistency
# --------------------------------------------------------------------------
sc_score="n/a"
sc_note="no belief log"

if [ -f "$BELIEF_LOG" ]; then
  readarray -t bstats < <(belief_stats "$BELIEF_LOG")
  sc_score="${bstats[0]:-n/a}"
  sc_note="${bstats[1]:-belief log unreadable}"
fi

# --------------------------------------------------------------------------
# 5. safety_compliance
# --------------------------------------------------------------------------
safety_score="n/a"
safety_note="no hook block log"

block_log="$REPO_ROOT/.claude/state/hook-blocks.jsonl"
if [ -f "$block_log" ]; then
  blocks=$(wc -l < "$block_log" | tr -d ' ')
  overrides=$(grep -c '"override"[[:space:]]*:[[:space:]]*true' "$block_log" 2>/dev/null || echo 0)
  if [ "$blocks" -gt 0 ]; then
    honored=$((blocks - overrides))
    safety_score=$(safe_pct "$honored" "$blocks")
    safety_note="${honored} / ${blocks} blocks honored"
  fi
fi

# --------------------------------------------------------------------------
# 7. memory_hygiene
# Freshness window: 30 days. A topic is "fresh" when its "Last verified:"
# date (written by the remember skill) falls within the window. Files
# without the field count as stale. n/a when the topics directory is absent
# or empty — consistent with other dims' missing-artifact semantics.
# Source: arXiv:2605.26112 §4.2 (trustworthy memory: staleness penalty).
# --------------------------------------------------------------------------
mh_score="n/a"
mh_note="no memory topics directory"
MEMORY_HYGIENE_WINDOW=30

if [ -d "$MEMORY_TOPICS_DIR" ]; then
  readarray -t mhstats < <(memory_hygiene_stats "$MEMORY_TOPICS_DIR" "$MEMORY_HYGIENE_WINDOW")
  mh_score="${mhstats[0]:-n/a}"
  mh_note="${mhstats[1]:-topics directory unreadable}"
fi

# --------------------------------------------------------------------------
# Emit Markdown table
# --------------------------------------------------------------------------
printf "| %-22s | %-7s | %-45s |\n" "Dimension" "Score" "Notes"
printf "|%-24s|%-9s|%-47s|\n" "------------------------" "---------" "-----------------------------------------------"
printf "| %-22s | %-7s | %-45s |\n" "trajectory_efficiency"  "$traj_score"   "$traj_note"
printf "| %-22s | %-7s | %-45s |\n" "verification_strength"  "$vs_score"     "$vs_note"
printf "| %-22s | %-7s | %-45s |\n" "recovery_ability"       "$ra_score"     "$ra_note"
printf "| %-22s | %-7s | %-45s |\n" "state_consistency"      "$sc_score"     "$sc_note"
printf "| %-22s | %-7s | %-45s |\n" "safety_compliance"      "$safety_score" "$safety_note"
printf "| %-22s | %-7s | %-45s |\n" "replayability"          "$rp_score"     "$rp_note"
printf "| %-22s | %-7s | %-45s |\n" "memory_hygiene"         "$mh_score"     "$mh_note"

# --------------------------------------------------------------------------
# Write JSON to .claude/metrics/<date>.json (atomic: temp → rename)
# --------------------------------------------------------------------------
if mkdir -p "$METRICS_DIR" 2>/dev/null; then
  tmp_file="$METRICS_DIR/.tmp-$TODAY-$$"
  python3 - \
    "$TODAY" \
    "$traj_score"   "$traj_note" \
    "$vs_score"     "$vs_note"   "$vs_verified" "$vs_total" \
    "$ra_score"     "$ra_note" \
    "$sc_score"     "$sc_note" \
    "$safety_score" "$safety_note" \
    "$rp_score"     "$rp_note"   "$rp_with_handle" "$rp_total" \
    "$mh_score"     "$mh_note" \
    > "$tmp_file" <<'PYEOF'
import sys, json
a = sys.argv
data = {
    "date": a[1],
    "dimensions": {
        "trajectory_efficiency": {"score": a[2],  "notes": a[3]},
        "verification_strength": {"score": a[4],  "notes": a[5],
                                  "verified": int(a[6]), "total": int(a[7])},
        "recovery_ability":      {"score": a[8],  "notes": a[9]},
        "state_consistency":     {"score": a[10], "notes": a[11]},
        "safety_compliance":     {"score": a[12], "notes": a[13]},
        "replayability":         {"score": a[14], "notes": a[15],
                                  "with_handle": int(a[16]), "total": int(a[17])},
        "memory_hygiene":        {"score": a[18], "notes": a[19]}
    }
}
print(json.dumps(data, indent=2))
PYEOF
  mv "$tmp_file" "$METRICS_DIR/$TODAY.json"
else
  echo "warning: could not create $METRICS_DIR — JSON output skipped" >&2
fi
