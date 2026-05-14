#!/usr/bin/env bash
set -euo pipefail

MANIFEST=".claude/evolution/change_manifest.jsonl"

if [ ! -f "$MANIFEST" ]; then
  printf '# Evolution History\n\n_No manifest yet._\n'
  exit 0
fi

python3 -c '
import sys, json, collections, signal
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

lines = sys.stdin.read().splitlines()

entries = []
for line in lines:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        entries.append(obj)
    except (json.JSONDecodeError, ValueError):
        pass

total = len(entries)
# Reverse-chrono first (tiebreak on file position descending — later-in-file wins
# on tied timestamps), THEN cap to 200, so a same-second SubagentStop burst keeps
# its freshest entry at the top.
ordered = sorted(enumerate(entries), key=lambda p: (p[1].get("iso_timestamp", ""), p[0]), reverse=True)
entries = [e for _, e in ordered[:200]]

groups = collections.defaultdict(list)
for e in entries:
    ts = e.get("iso_timestamp", "")
    date = ts[:10] if len(ts) >= 10 else "unknown"
    groups[date].append(e)

sorted_dates = sorted(groups.keys(), reverse=True)

print("# Evolution History")
print()
if total > 200:
    print(f"_{total} entries; showing the latest 200._")
else:
    print(f"_{total} manifest entries._")
print()

for date in sorted_dates:
    print(f"## {date}")
    print()
    # groups[date] already preserves the globally-sorted order (newest first,
    # with file-position tiebreak for tied timestamps); no per-day re-sort needed.
    for e in groups[date]:
        ts = e.get("iso_timestamp", "")
        etype = e.get("type", "")
        desc = e.get("description", "")
        print(f"### {ts} — {etype}: {desc}")
        eid = e.get("id", "")
        print(f"- **id**: {eid}")
        agent = e.get("agent_type", "")
        session = e.get("session_id", "")
        print(f"- **agent**: {agent} (session: {session})")
        files = e.get("files", "")
        if files:
            print(f"- **files**: {files}")
        failure = e.get("failure_pattern", "")
        if failure:
            print(f"- **failure_pattern**: {failure}")
        fixes = e.get("predicted_fixes", "")
        if fixes:
            print(f"- **predicted_fixes**: {fixes}")
        risk = e.get("risk_tasks", "")
        if risk:
            print(f"- **risk_tasks**: {risk}")
        constraint = e.get("constraint_level", "")
        if constraint:
            print(f"- **constraint_level**: {constraint}")
        why = e.get("why_this_component", "")
        if why:
            print(f"- **why_this_component**: {why}")
        print()
' < "$MANIFEST"
