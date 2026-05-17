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

if [ -z "$output" ]; then
    echo "parse-tasks.sh: no '#### T<n>' tasks found under '### Tasks' (3-hash) section in $1" >&2
    exit 0
fi

printf '%s\n' "$output"
