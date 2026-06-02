#!/usr/bin/env bash
# Contract criterion 1: wrong-branch / detached push is blocked.
# Tests the PreToolUse push guard (guard-push.sh).

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$TESTS_DIR/../../hooks/guard-push.sh"
REPO_ROOT="$(cd "$TESTS_DIR/../../../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Helper: pipe a command JSON to the guard and capture output + exit code.
# The guard is run inside the fixture repo so git symbolic-ref works.
_guard() {
  local cmd="$1"
  local json
  # Build JSON without embedding the string through the shell's variable
  # expansion to avoid quoting fragility.
  json=$(printf '{"tool_input":{"command":"%s"}}' "$cmd")
  (cd "$FIXTURE_REPO" && printf '%s' "$json" | bash "$GUARD") 2>/dev/null || true
}

_guard_raw() {
  local json="$1"
  (cd "$FIXTURE_REPO" && printf '%s' "$json" | bash "$GUARD") 2>/dev/null || true
}

# Setup: tmp dirs.
TMP=$(mktemp -d)
export CLAUDE_PLUGIN_DATA="$TMP/state"
mkdir -p "$CLAUDE_PLUGIN_DATA"

trap 'rm -rf "$TMP"' EXIT

# Build fixture repo.
FIXTURE_REPO=$(CLAUDE_PLUGIN_DATA="$TMP/state" bash "$TESTS_DIR/mkfixture.sh")
trap 'rm -rf "$TMP" "$FIXTURE_REPO"' EXIT

# Helper: configure fake bare remote so push-related tests work.
BARE_REMOTE=$(mktemp -d)
git -C "$BARE_REMOTE" init --bare -b main >/dev/null
git -C "$FIXTURE_REPO" remote add origin "$BARE_REMOTE"
# Initial push to populate the remote (needed for --force-with-lease).
git -C "$FIXTURE_REPO" push -q origin main
git -C "$FIXTURE_REPO" push -q origin feat-a
trap 'rm -rf "$TMP" "$FIXTURE_REPO" "$BARE_REMOTE"' EXIT

echo "--- test-push-guard.sh ---"

# ----- Case 1: non-push command passes through -----
OUT=$(_guard "ls -la")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "non-push command (ls) passes through"
else
  _fail "non-push command (ls) should pass, got deny"
fi

# ----- Case 2: git command that mentions push in an arg (not a push) -----
OUT=$(_guard "echo git push")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "echo 'git push' is not a push command — passes"
else
  _fail "echo 'git push' should pass, got deny"
fi

# ----- Case 3: correct branch (current = main, push to main) → pass -----
git -C "$FIXTURE_REPO" checkout main
OUT=$(_guard "git push origin main")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "correct-branch push (main → main) passes"
else
  _fail "correct-branch push (main → main) should pass, got deny"
fi

# ----- Case 4: wrong-branch push → deny -----
# HEAD is on main, push target is feat-a.
OUT=$(_guard "git push origin feat-a")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "wrong-branch push (main → feat-a) is denied"
else
  _fail "wrong-branch push (main → feat-a) should be denied, got: $OUT"
fi

# ----- Case 5: detached HEAD → deny -----
HEAD_SHA=$(git -C "$FIXTURE_REPO" rev-parse HEAD)
git -C "$FIXTURE_REPO" checkout --detach HEAD
OUT=$(_guard "git push origin main")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "detached-HEAD push is denied"
else
  _fail "detached-HEAD push should be denied, got: $OUT"
fi
git -C "$FIXTURE_REPO" checkout main

# ----- Case 6: bare --force push → deny -----
OUT=$(_guard "git push --force origin main")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "bare --force push is denied"
else
  _fail "bare --force push should be denied, got: $OUT"
fi

# ----- Case 7: -f shorthand → deny -----
OUT=$(_guard "git push -f origin main")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "bare -f push is denied"
else
  _fail "bare -f push should be denied, got: $OUT"
fi

# ----- Case 8: --force-with-lease is safe → pass -----
OUT=$(_guard "git push --force-with-lease --force-if-includes origin main")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "--force-with-lease push (correct branch) passes"
else
  _fail "--force-with-lease push (correct branch) should pass, got: $OUT"
fi

# ----- Case 9: whitespace variant — tab between git and push → deny on wrong branch -----
# JSON strings must not contain raw control characters; a tab in the command is
# JSON-encoded as \t (the two-character escape sequence).  printf \\t produces
# that literal backslash-t in the JSON value, which jq then decodes to a real tab
# before the guard's tr-based normalisation collapses it to a space.
TABBED_JSON=$(printf '{"tool_input":{"command":"git\\tpush origin feat-a"}}')
OUT=$(_guard_raw "$TABBED_JSON")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "git\\tpush (tab-separated) wrong-branch is denied"
else
  _fail "git\\tpush (tab-separated) wrong-branch should be denied, got: $OUT"
fi

# ----- Case 10: chained push (push && push) → deny -----
CHAINED_JSON='{"tool_input":{"command":"git push origin main && git push origin feat-a"}}'
OUT=$(_guard_raw "$CHAINED_JSON")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "chained push (&&) is denied"
else
  _fail "chained push (&&) should be denied, got: $OUT"
fi

# ----- Case 11: no refspec (push current branch to its tracking remote) → pass -----
git -C "$FIXTURE_REPO" checkout main
OUT=$(_guard "git push origin")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "push with only remote, no refspec, passes"
else
  _fail "push with only remote should pass, got: $OUT"
fi

# ----- Case 12: 'git push origin HEAD' (HEAD = current branch) → pass -----
# HEAD resolves to the current branch, so this is a push of the current branch.
git -C "$FIXTURE_REPO" checkout main
OUT=$(_guard "git push origin HEAD")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "push origin HEAD (resolves to current branch) passes"
else
  _fail "push origin HEAD should pass, got: $OUT"
fi

# ----- Case 13: 'git push origin HEAD:main' on main → pass (dest matches) -----
OUT=$(_guard "git push origin HEAD:main")
if ! printf '%s' "$OUT" | grep -q "deny"; then
  _pass "push origin HEAD:main (dest matches current) passes"
else
  _fail "push origin HEAD:main should pass on main, got: $OUT"
fi

# ----- Case 14: --mirror (force-updates/deletes all remote refs) → deny -----
OUT=$(_guard "git push --mirror origin")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "--mirror push is denied"
else
  _fail "--mirror push should be denied, got: $OUT"
fi

# ----- Case 15: --all (pushes every local branch) → deny -----
OUT=$(_guard "git push --all origin")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "--all push is denied"
else
  _fail "--all push should be denied, got: $OUT"
fi

# ----- Case 16: --delete (drops a remote branch) → deny -----
OUT=$(_guard "git push origin --delete feat-a")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "--delete push is denied"
else
  _fail "--delete push should be denied, got: $OUT"
fi

# ----- Case 17: deletion refspec ':<branch>' (drops a remote branch) → deny -----
OUT=$(_guard "git push origin :feat-a")
if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'" 2>/dev/null; then
  _pass "deletion refspec (:feat-a) is denied"
else
  _fail "deletion refspec (:feat-a) should be denied, got: $OUT"
fi

# Summary
echo ""
echo "test-push-guard.sh: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]]
