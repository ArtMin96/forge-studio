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

# Collect input files in order: archive (chronological) then live manifest.
INPUT_FILES=()
if [[ "$INCLUDE_ARCHIVE" -eq 1 ]]; then
  archive_dir=".claude/evolution/archive"
  if [[ -d "$archive_dir" ]]; then
    # Sort archive files chronologically by name (basename contains iso-date+epoch).
    while IFS= read -r -d '' f; do
      INPUT_FILES+=("$f")
    done < <(find "$archive_dir" -maxdepth 1 -name "change_manifest*.jsonl" -print0 | sort -z)
  fi
fi

if [[ -f "$MANIFEST" ]]; then
  INPUT_FILES+=("$MANIFEST")
fi

if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
  printf '# Manifest Analysis\n\n_No entries._\n'
  exit 0
fi

# Concatenate all input files into one stream; pass path list via env to Python.
export MA_FILES
MA_FILES=$(printf '%s\n' "${INPUT_FILES[@]}")

python3 <<'PYEOF'
import json, os, sys, collections

# Read file list from env.
file_list = [f for f in os.environ.get("MA_FILES", "").splitlines() if f.strip()]

entries = []
for path in file_list:
    try:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except (json.JSONDecodeError, ValueError):
                    pass
    except OSError:
        pass

if not entries:
    print("# Manifest Analysis\n\n_No entries._")
    sys.exit(0)

total = len(entries)

# Volume section.
timestamps = sorted(
    e["iso_timestamp"] for e in entries if e.get("iso_timestamp")
)
oldest = timestamps[0] if timestamps else "—"
newest = timestamps[-1] if timestamps else "—"
sessions = sorted({e.get("session_id", "") for e in entries if e.get("session_id")})
session_count = len(sessions)

print("# Manifest Analysis")
print()
print("## Volume")
print()
print(f"| Metric | Value |")
print(f"|--------|-------|")
print(f"| Total entries | {total} |")
print(f"| Oldest | {oldest} |")
print(f"| Newest | {newest} |")
print(f"| Distinct sessions | {session_count} |")
print()

# Failure-pattern frequency (top 10).
fail_counts: collections.Counter = collections.Counter()
for e in entries:
    fp = e.get("failure_pattern", "").strip()
    if fp:
        fail_counts[fp] += 1

print("## Failure-Pattern Frequency")
print()
if fail_counts:
    print("| Rank | Failure pattern | Count |")
    print("|------|----------------|-------|")
    for rank, (pattern, count) in enumerate(
        sorted(fail_counts.items(), key=lambda x: (-x[1], x[0]))[:10], start=1
    ):
        print(f"| {rank} | {pattern} | {count} |")
else:
    print("_No `failure_pattern` values recorded._")
print()

# Risk-task frequency.
risk_counts: collections.Counter = collections.Counter()
for e in entries:
    rt = e.get("risk_tasks", "")
    if isinstance(rt, list):
        tasks = rt
    else:
        tasks = [t.strip() for t in str(rt).split(",") if t.strip()]
    for t in tasks:
        if t:
            risk_counts[t] += 1

print("## Risk-Task Frequency")
print()
if risk_counts:
    print("| Rank | Risk task | Count |")
    print("|------|-----------|-------|")
    for rank, (task, count) in enumerate(
        sorted(risk_counts.items(), key=lambda x: (-x[1], x[0])), start=1
    ):
        print(f"| {rank} | {task} | {count} |")
else:
    print("_No `risk_tasks` values recorded._")
print()

# Constraint-level distribution.
constraint_counts: collections.Counter = collections.Counter()
for e in entries:
    cl = e.get("constraint_level", "").strip()
    key = cl if cl else "(unset)"
    constraint_counts[key] += 1

print("## Constraint-Level Distribution")
print()
print("| Constraint level | Count |")
print("|-----------------|-------|")
for level, count in sorted(constraint_counts.items(), key=lambda x: (-x[1], x[0])):
    print(f"| {level} | {count} |")
print()

# Why-this-component clusters.
why_counts: collections.Counter = collections.Counter()
for e in entries:
    w = e.get("why_this_component", "").strip()
    if w:
        why_counts[w] += 1

print("## Why-This-Component Clusters")
print()
if why_counts:
    print("| Rank | Why this component | Count |")
    print("|------|--------------------|-------|")
    for rank, (why, count) in enumerate(
        sorted(why_counts.items(), key=lambda x: (-x[1], x[0])), start=1
    ):
        print(f"| {rank} | {why} | {count} |")
else:
    print("_No `why_this_component` values recorded._")
print()
PYEOF
