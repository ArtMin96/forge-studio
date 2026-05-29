#!/usr/bin/env bash
# Build a disposable git repo with a main → A → B → C stack.
#
# Each branch has one seeded commit on the prior.  The parent relationships
# are registered in the stack graph so tests can call stack-graph.sh directly.
#
# Caller must set CLAUDE_PLUGIN_DATA before calling this script.
# The repo path is echoed on stdout so the caller can cd into it.
#
# Usage:
#   REPO=$(CLAUDE_PLUGIN_DATA=/some/tmp bash mkfixture.sh)

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$TESTS_DIR/../_lib"

REPO=$(mktemp -d)

# Initialise with main as trunk — do not rely on the system default branch name.
# All git output is redirected to /dev/null so nothing leaks into the echoed
# repo path when this script is called as REPO=$(bash mkfixture.sh).
git -C "$REPO" init -b main >/dev/null
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"
git -C "$REPO" config commit.gpgsign false

# main: seed commit
echo "main seed" > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -q -m "chore: main seed"

# branch A: one commit on main
git -C "$REPO" checkout -q -b feat-a
echo "feat-a work" > "$REPO/feat-a.txt"
git -C "$REPO" add feat-a.txt
git -C "$REPO" commit -q -m "feat: A work"

# branch B: one commit on A
git -C "$REPO" checkout -q -b feat-b
echo "feat-b work" > "$REPO/feat-b.txt"
git -C "$REPO" add feat-b.txt
git -C "$REPO" commit -q -m "feat: B work"

# branch C: one commit on B
git -C "$REPO" checkout -q -b feat-c
echo "feat-c work" > "$REPO/feat-c.txt"
git -C "$REPO" add feat-c.txt
git -C "$REPO" commit -q -m "feat: C work"

# Go back to main so the repo isn't on a feature branch by default.
git -C "$REPO" checkout -q main

# Register stack relationships via stack-graph.sh.
# stack-graph.sh uses $(pwd) when no CLAUDE_PLUGIN_DATA is set, but the
# caller always sets it so the state lands in the caller's tmp dir.
A_SHA=$(git -C "$REPO" rev-parse feat-a)
B_SHA=$(git -C "$REPO" rev-parse feat-b)

(cd "$REPO" && bash "$LIB_DIR/stack-graph.sh" set feat-a main "$(git rev-parse main)" null)
(cd "$REPO" && bash "$LIB_DIR/stack-graph.sh" set feat-b feat-a "$A_SHA" null)
(cd "$REPO" && bash "$LIB_DIR/stack-graph.sh" set feat-c feat-b "$B_SHA" null)

echo "$REPO"
