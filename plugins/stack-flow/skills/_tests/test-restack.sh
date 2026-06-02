#!/usr/bin/env bash
# Contract criterion 2: restack propagates a parent commit through a 3-branch stack.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$TESTS_DIR/../_lib"
RESTACK="$LIB_DIR/restack.sh"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Setup: tmp dirs.
TMP=$(mktemp -d)
export CLAUDE_PLUGIN_DATA="$TMP/state"
mkdir -p "$CLAUDE_PLUGIN_DATA"

BARE_REMOTE=$(mktemp -d)

trap 'rm -rf "$TMP" "$BARE_REMOTE" "${FIXTURE_REPO:-}"' EXIT

# Build fixture repo.
FIXTURE_REPO=$(CLAUDE_PLUGIN_DATA="$TMP/state" bash "$TESTS_DIR/mkfixture.sh")

# Set up a bare remote (needed for safe-push inside restack).
git -C "$BARE_REMOTE" init --bare -b main >/dev/null 2>&1
git -C "$FIXTURE_REPO" remote add origin "$BARE_REMOTE"
# Push all branches so --force-with-lease has a remote-tracking ref to compare against.
git -C "$FIXTURE_REPO" push -q origin main
git -C "$FIXTURE_REPO" push -q origin feat-a
git -C "$FIXTURE_REPO" push -q origin feat-b
git -C "$FIXTURE_REPO" push -q origin feat-c

echo "--- test-restack.sh ---"

# Check out feat-a and add a commit so restack has work to do.
git -C "$FIXTURE_REPO" checkout -q feat-a
echo "extra work on A" >> "$FIXTURE_REPO/feat-a.txt"
git -C "$FIXTURE_REPO" add feat-a.txt
git -C "$FIXTURE_REPO" -c user.email="t@t.com" -c user.name="T" \
  commit -q -m "feat: extra A work"

# Update the remote tracking ref for feat-a (needed for --force-with-lease).
git -C "$FIXTURE_REPO" push -q --force-with-lease --force-if-includes origin feat-a

# Now run restack from feat-c down to feat-a.
git -C "$FIXTURE_REPO" checkout -q feat-c
MOVED=$(cd "$FIXTURE_REPO" && bash "$RESTACK" feat-c feat-a 2>/dev/null) || {
  _fail "restack.sh exited non-zero"
  echo "test-restack.sh: 0 passed, $((FAIL_COUNT)) failed"
  exit 1
}

# ----- Assertion 1: stdout lists moved branches -----
if printf '%s' "$MOVED" | grep -q "feat-b"; then
  _pass "restack output includes feat-b"
else
  _fail "restack output should include feat-b; got: $MOVED"
fi
if printf '%s' "$MOVED" | grep -q "feat-c"; then
  _pass "restack output includes feat-c"
else
  _fail "restack output should include feat-c; got: $MOVED"
fi

# ----- Assertion 2: ancestry — A is ancestor of B, B is ancestor of C -----
if git -C "$FIXTURE_REPO" merge-base --is-ancestor feat-a feat-b 2>/dev/null; then
  _pass "feat-a is ancestor of feat-b after restack"
else
  _fail "feat-a should be ancestor of feat-b after restack"
fi
if git -C "$FIXTURE_REPO" merge-base --is-ancestor feat-b feat-c 2>/dev/null; then
  _pass "feat-b is ancestor of feat-c after restack"
else
  _fail "feat-b should be ancestor of feat-c after restack"
fi

# ----- Assertion 3: no-op restack prints empty stdout -----
# Running again when there is nothing to do should produce no output.
git -C "$FIXTURE_REPO" checkout feat-c
NOOP=$(cd "$FIXTURE_REPO" && bash "$RESTACK" feat-c feat-a 2>/dev/null) || true
if [[ -z "$NOOP" ]]; then
  _pass "no-op restack emits empty stdout (regression: no-op-leak)"
else
  _fail "no-op restack should emit empty stdout; got: $NOOP"
fi

# ----- Assertion 4: conflict → restack aborts cleanly and exits non-zero -----
# Build a real rebase conflict: feat-x edits a line that the new base also edits.
_c() { git -C "$FIXTURE_REPO" -c user.email="t@t.com" -c user.name="T" "$@"; }

git -C "$FIXTURE_REPO" checkout -q main
printf 'shared line\n' > "$FIXTURE_REPO/conflict.txt"
_c add conflict.txt; _c commit -q -m "base: add conflict.txt"
BASE_SHA=$(git -C "$FIXTURE_REPO" rev-parse main)

git -C "$FIXTURE_REPO" checkout -q -b feat-x
printf 'feat-x version\n' > "$FIXTURE_REPO/conflict.txt"
_c add conflict.txt; _c commit -q -m "feat-x: edit conflict.txt"
FEATX_PRE=$(git -C "$FIXTURE_REPO" rev-parse feat-x)

# Advance main with a conflicting edit to the same line, then register feat-x
# against the pre-advance base so restack rebases it onto the new main.
git -C "$FIXTURE_REPO" checkout -q main
printf 'main version\n' > "$FIXTURE_REPO/conflict.txt"
_c add conflict.txt; _c commit -q -m "main: conflicting edit"
(cd "$FIXTURE_REPO" && bash "$LIB_DIR/stack-graph.sh" set feat-x main "$BASE_SHA" null)

git -C "$FIXTURE_REPO" checkout -q feat-x
set +e
CONFLICT_ERR=$(cd "$FIXTURE_REPO" && bash "$RESTACK" feat-x main 2>&1 >/dev/null)
CONFLICT_EXIT=$?
set -e

if [[ "$CONFLICT_EXIT" -ne 0 ]]; then
  _pass "restack exits non-zero on conflict"
else
  _fail "restack should exit non-zero on conflict (got exit 0)"
fi

FEATX_POST=$(git -C "$FIXTURE_REPO" rev-parse feat-x)
if (cd "$FIXTURE_REPO" && [ -d "$(git rev-parse --git-path rebase-merge)" ]); then
  RB_INPROGRESS=1
else
  RB_INPROGRESS=0
fi
if [[ "$FEATX_POST" == "$FEATX_PRE" && "$RB_INPROGRESS" -eq 0 && "$CONFLICT_ERR" != *"does not match its pre-rebase tip"* ]]; then
  _pass "conflict abort restored feat-x to its pre-rebase tip, no rebase left in progress"
else
  _fail "conflict abort did not cleanly restore feat-x (post=$FEATX_POST pre=$FEATX_PRE inprogress=$RB_INPROGRESS); err: $CONFLICT_ERR"
fi

# Summary
echo ""
echo "test-restack.sh: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]]
