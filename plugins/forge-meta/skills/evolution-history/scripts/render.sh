#!/usr/bin/env bash
set -euo pipefail

MANIFEST=".claude/evolution/change_manifest.jsonl"
INCLUDE_ARCHIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-archive) INCLUDE_ARCHIVE=1; shift ;;
    *) shift ;;
  esac
done

# Collect input files: archive (chronological) then live manifest.
INPUT_FILES=()
if [[ "$INCLUDE_ARCHIVE" -eq 1 ]]; then
  archive_dir=".claude/evolution/archive"
  if [[ -d "$archive_dir" ]]; then
    while IFS= read -r -d '' f; do
      INPUT_FILES+=("$f")
    done < <(find "$archive_dir" -maxdepth 1 -name "change_manifest*.jsonl" -print0 | sort -z)
  fi
fi
if [[ -f "$MANIFEST" ]]; then
  INPUT_FILES+=("$MANIFEST")
fi

if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
  printf '# Evolution History\n\n_No manifest yet._\n'
  exit 0
fi

# Pass file list via env to Python to avoid shell-quoting issues.
export EH_FILES
EH_FILES=$(printf '%s\n' "${INPUT_FILES[@]}")

python3 -c '
import sys, json, collections, signal, os
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

file_list = [f for f in os.environ.get("EH_FILES", "").splitlines() if f.strip()]

raw_lines = []
for path in file_list:
    try:
        with open(path) as fh:
            raw_lines.extend(fh.readlines())
    except OSError:
        pass

lines = [l.rstrip("\n") for l in raw_lines]

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
        # High-signal evidence-bundle fields — surface when present, skip silently when absent
        sep = "; "
        bundle = e.get("evidence_bundle") or {}
        untested = bundle.get("untested_regions", [])
        if untested:
            regions = untested if isinstance(untested, list) else [untested]
            print("- **untested_regions**: " + sep.join(str(r) for r in regions))
        remaining = bundle.get("remaining_risks", [])
        if remaining:
            risks = remaining if isinstance(remaining, list) else [remaining]
            print("- **remaining_risks**: " + sep.join(str(r) for r in risks))
        print()
'
