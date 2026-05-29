#!/usr/bin/env bash
# Contract criterion 5: stack-graph state persists in ${CLAUDE_PLUGIN_DATA} and
# reflects the live tree.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$TESTS_DIR/../_lib"
STACK_GRAPH="$LIB_DIR/stack-graph.sh"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Setup: tmp dirs.
TMP=$(mktemp -d)
export CLAUDE_PLUGIN_DATA="$TMP/state"
mkdir -p "$CLAUDE_PLUGIN_DATA"

trap 'rm -rf "$TMP" "${FIXTURE_REPO:-}"' EXIT

# Build fixture repo.
FIXTURE_REPO=$(CLAUDE_PLUGIN_DATA="$TMP/state" bash "$TESTS_DIR/mkfixture.sh")

echo "--- test-stack-graph.sh ---"

# ----- Assertion 1: CLAUDE_PLUGIN_DATA is honored -----
# The mkfixture call already wrote state; verify it landed in our tmp dir.
GRAPH_PATH=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" path 2>/dev/null)
if printf '%s' "$GRAPH_PATH" | grep -q "$CLAUDE_PLUGIN_DATA"; then
  _pass "graph path is inside CLAUDE_PLUGIN_DATA"
else
  _fail "graph path should be inside CLAUDE_PLUGIN_DATA; got: $GRAPH_PATH"
fi

# ----- Assertion 2: set/get round-trip -----
A_SHA=$(git -C "$FIXTURE_REPO" rev-parse feat-a)
(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" set round-trip-branch main "$A_SHA" 42)
ENTRY=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" get round-trip-branch 2>/dev/null)

if printf '%s' "$ENTRY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['parent'] == 'main', f\"parent={d['parent']}\"
assert d['parent_sha_at_stack_time'] == sys.argv[1], f\"sha={d['parent_sha_at_stack_time']}\"
assert d['pr_number'] == 42, f\"pr_number={d['pr_number']}\"
" "$A_SHA" 2>/dev/null; then
  _pass "round-trip: set/get preserves parent, sha, pr_number=42"
else
  _fail "round-trip failed; entry: $ENTRY"
fi

# ----- Assertion 3: pr_number is an integer (not a string) -----
PR_TYPE=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" get round-trip-branch \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(type(d['pr_number']).__name__)")
if [[ "$PR_TYPE" == "int" ]]; then
  _pass "pr_number is stored as integer"
else
  _fail "pr_number should be int; got type: $PR_TYPE"
fi

# ----- Assertion 4: null pr_number is stored as JSON null -----
(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" set null-pr-branch main "$A_SHA" null)
NULL_TYPE=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" get null-pr-branch \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['pr_number'] is None)")
if [[ "$NULL_TYPE" == "True" ]]; then
  _pass "null pr_number is stored as JSON null"
else
  _fail "null pr_number should be JSON null; got: $NULL_TYPE"
fi

# ----- Assertion 5: list returns registered branches -----
LISTED=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" list 2>/dev/null)
if printf '%s' "$LISTED" | grep -q "feat-a"; then
  _pass "list includes feat-a"
else
  _fail "list should include feat-a; got: $LISTED"
fi

# ----- Assertion 6: diverged computes live -----
# feat-c is currently 1 commit ahead of feat-b (C commit), with no extra commits
# on feat-b beyond what feat-c knows.
DIV=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" diverged feat-c 2>/dev/null)
if printf '%s' "$DIV" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'merge_base' in d, 'missing merge_base'
assert 'parent_ahead' in d, 'missing parent_ahead'
assert 'branch_ahead' in d, 'missing branch_ahead'
" 2>/dev/null; then
  _pass "diverged output contains merge_base, parent_ahead, branch_ahead"
else
  _fail "diverged output missing fields; got: $DIV"
fi

# ----- Assertion 7: state survives re-invocation (file is re-read) -----
# Write, then read in a sub-shell to verify persistence.
(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" set persist-test main "$A_SHA" 7)
PERSIST=$(cd "$FIXTURE_REPO" && bash "$STACK_GRAPH" get persist-test \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['pr_number'])")
if [[ "$PERSIST" == "7" ]]; then
  _pass "state persists across invocations"
else
  _fail "state not persisted; got pr_number: $PERSIST"
fi

# Summary
echo ""
echo "test-stack-graph.sh: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]]
