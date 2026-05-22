#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: parse-tasks.sh <plan-path>" >&2
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "parse-tasks.sh: file not found: $1" >&2
    exit 1
fi

# Canonical plan format (single source of truth, also enforced by planner.md):
#   ### Tasks
#   #### T1 short description
#   #### T2-postpaid short description
#   #### T5a short description
#
# Section heading must be exactly `### Tasks` (3-hash). Task headings must be
# `#### T<digit>[<suffix>]` (4-hash, ID begins with T+digit, optional alnum/dash
# suffix). Any other format is silently skipped by the awk pass — the warning
# below names the file so callers can repair the plan.
output=$(awk '/^### Tasks/{intasks=1; next} /^### /{intasks=0} intasks && /^#### T[0-9]+/{ gsub(/^#### /,""); sub(/[[:space:]].*$/,""); print }' "$1")

# Distinguish "no Tasks section at all" (valid single-task plan → exit 0, empty output)
# from "Tasks section present but malformed" (exit 1 — orchestrator must hard-stop).
has_tasks_heading=$(grep -cE '^(### Tasks|## Tasks)[[:space:]]*$' "$1" || true)
has_t_headings=$(grep -cE '^(### T[0-9]|#### T[0-9])' "$1" || true)

if [ -z "$output" ]; then
    if [ "$has_tasks_heading" = "0" ] && [ "$has_t_headings" = "0" ]; then
        # Single-task plan — no Tasks structure expected.
        exit 0
    fi
    echo "parse-tasks.sh: malformed plan — no '#### T<n>' tasks found under '### Tasks' (3-hash) section in $1" >&2
    echo "parse-tasks.sh: canonical format is '### Tasks' (3-hash) + '#### T<n>' (4-hash). See plugins/agents/agents/planner.md §'Canonical plan file structure'." >&2
    exit 1
fi

printf '%s\n' "$output"
