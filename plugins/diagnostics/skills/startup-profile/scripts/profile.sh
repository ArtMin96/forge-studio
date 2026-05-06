#!/usr/bin/env bash
set -u

LOG="${FORGE_STUDIO_TIMING_LOG:-$HOME/.local/share/forge-studio/startup.jsonl}"
LAST="${LAST:-20}"
EXCLUDE_UNKNOWN="${EXCLUDE_UNKNOWN:-0}"

if [ ! -f "$LOG" ]; then
  echo "## SessionStart Latency Profile"
  echo
  echo "**Log missing:** $LOG"
  echo "Open one new session, then re-run."
  exit 0
fi

LOG="$LOG" LAST="$LAST" EXCLUDE_UNKNOWN="$EXCLUDE_UNKNOWN" python3 - <<'PY'
import json, os
from collections import defaultdict
from statistics import median

log = os.environ["LOG"]
last = int(os.environ["LAST"])
exclude_unknown = os.environ.get("EXCLUDE_UNKNOWN") == "1"

rows = []
with open(log) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            continue

if exclude_unknown:
    rows = [r for r in rows if r.get("session") != "unknown"]

sessions_seen = []
for r in rows:
    s = r.get("session", "unknown")
    if s not in sessions_seen:
        sessions_seen.append(s)
keep = set(sessions_seen[-last:])
rows = [r for r in rows if r.get("session") in keep]

per_session_total = defaultdict(int)
per_session_max = defaultdict(int)
per_hook = defaultdict(list)
failures = []

for r in rows:
    if r.get("event") != "SessionStart":
        continue
    s = r["session"]
    d = int(r["duration_ms"])
    per_session_total[s] += d
    if d > per_session_max[s]:
        per_session_max[s] = d
    cmd_tail = r.get("cmd", "").split("/")[-1]
    per_hook[(r["plugin"], cmd_tail)].append(d)
    if int(r.get("exit_code", 0)) != 0:
        failures.append(r)

cold = [s for s, m in per_session_max.items() if m > 5000]
warm = [s for s in per_session_max if s not in cold]

def pct(values, p):
    if not values:
        return None
    s = sorted(values)
    idx = int(round((p / 100.0) * (len(s) - 1)))
    return s[idx]

print("## SessionStart Latency Profile")
print()
print(f"**Window:** last {len(per_session_max)} sessions ({len(cold)} cold, {len(warm)} warm)")
print(f"**Log:** {log}")
print()
print("### Per-plugin (SessionStart only)")
print()
print("| Plugin | Hook | Calls | median ms | p95 ms |")
print("|---|---|---|---|---|")
for (plugin, hook), vals in sorted(per_hook.items()):
    med = int(median(vals)) if vals else 0
    p95 = pct(vals, 95) if len(vals) > 1 else "--"
    print(f"| {plugin} | {hook} | {len(vals)} | {med} | {p95} |")
print()
print("### Per-session totals")
warm_totals = [per_session_total[s] for s in warm]
cold_totals = [per_session_total[s] for s in cold]
def fmt_pair(vals):
    if not vals:
        return "no data"
    med = int(median(vals))
    p = pct(vals, 95) if len(vals) > 1 else "--"
    return f"median {med} ms, p95 {p} ms"
print(f"- Warm session: {fmt_pair(warm_totals)}")
print(f"- Cold session: {fmt_pair(cold_totals)}")
print()
print("### Non-zero exits")
if not failures:
    print("none")
else:
    for r in failures:
        print(f"- {r['plugin']}/{r.get('cmd','?').split('/')[-1]} exit={r['exit_code']} at {r['ts']}")
print()
print("### Slowest single hook")
all_pairs = [(d, plugin, hook) for (plugin, hook), vals in per_hook.items() for d in vals]
if all_pairs:
    all_pairs.sort(reverse=True)
    d, plugin, hook = all_pairs[0]
    print(f"{plugin}/{hook} at {d} ms")
else:
    print("no data")
PY
