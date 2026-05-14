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

# Extract T<n> task ids from the ### Tasks section, in document order.
# Sets intasks flag at ### Tasks, clears it at the next ### heading,
# and emits the bare id (e.g. T1) for every #### T<n> line found.
awk '/^### Tasks/{intasks=1; next} /^### /{intasks=0} intasks && /^#### T[0-9]+/{ gsub(/^#### /,""); sub(/[[:space:]].*$/,""); print }' "$1"
