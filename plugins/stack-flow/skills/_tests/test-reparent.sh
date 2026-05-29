#!/usr/bin/env bash
# Contract criterion 3: squash-merge re-parent drops merged commits and retargets
# the child PR base.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$TESTS_DIR/../_lib"
ONTO_REPARENT="$LIB_DIR/onto-reparent.sh"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Setup: tmp dirs.
TMP=$(mktemp -d)
export CLAUDE_PLUGIN_DATA="$TMP/state"
mkdir -p "$CLAUDE_PLUGIN_DATA"

# Build a fake `gh` shim.
GH_BIN="$TMP/bin"
mkdir -p "$GH_BIN"
GH_CALLS="$TMP/gh-calls.log"

# The shim records invocations and returns enough canned JSON to keep
# onto-reparent.sh happy.  The heredoc is unquoted so $GH_CALLS is
# expanded to its absolute path at write time — the shim does not need
# the env var at runtime.
cat > "$GH_BIN/gh" <<GHEOF
#!/usr/bin/env bash
# Fake gh: record args, return canned output.
echo "\$*" >> "$GH_CALLS"
case "\$*" in
  "pr edit "*)
    exit 0
    ;;
  "pr view "*)
    echo '{"number":99,"headRefOid":"deadbeef1234","baseRefName":"main"}'
    exit 0
    ;;
  "pr list "*)
    echo '[]'
    exit 0
    ;;
  *)
    echo '{}' ; exit 0 ;;
esac
GHEOF
chmod +x "$GH_BIN/gh"
export PATH="$GH_BIN:$PATH"

trap 'rm -rf "$TMP" "${FIXTURE_REPO:-}"' EXIT

# Build fixture repo.
FIXTURE_REPO=$(CLAUDE_PLUGIN_DATA="$TMP/state" bash "$TESTS_DIR/mkfixture.sh")

echo "--- test-reparent.sh ---"

# Simulate squash-merge of feat-a into main:
#   - Record A's current (old) SHA before the squash.
#   - Squash the A commits into a single new commit on main.
OLD_A_SHA=$(git -C "$FIXTURE_REPO" rev-parse feat-a)
MAIN_SHA_BEFORE=$(git -C "$FIXTURE_REPO" rev-parse main)

git -C "$FIXTURE_REPO" checkout main
# Merge --squash then commit = squash-merge.
git -C "$FIXTURE_REPO" merge --squash feat-a
git -C "$FIXTURE_REPO" -c user.email="t@t.com" -c user.name="T" \
  commit -m "feat: squash-merge A into main"
MAIN_SHA_AFTER=$(git -C "$FIXTURE_REPO" rev-parse main)

# feat-b still has old feat-a commits in its history; re-parent it onto new main.
git -C "$FIXTURE_REPO" checkout feat-b

# Run onto-reparent: child=feat-b, new-base=main, old-base-sha=<old A sha>.
(cd "$FIXTURE_REPO" && bash "$ONTO_REPARENT" feat-b main "$OLD_A_SHA") || {
  _fail "onto-reparent.sh exited non-zero"
  echo "test-reparent.sh: 0 passed, $FAIL_COUNT failed"
  exit 1
}

# ----- Assertion 1: feat-b's commits no longer include old A SHA -----
# After re-parent, old A SHA should NOT be in feat-b's history.
if git -C "$FIXTURE_REPO" rev-list feat-b | grep -q "$OLD_A_SHA"; then
  _fail "feat-b still contains old A commits after reparent"
else
  _pass "feat-b no longer contains old A commits"
fi

# ----- Assertion 2: feat-b contains its own commit (feat-b.txt content) -----
if git -C "$FIXTURE_REPO" show feat-b:feat-b.txt >/dev/null 2>&1; then
  _pass "feat-b still contains its own file after reparent"
else
  _fail "feat-b lost its own commit after reparent"
fi

# ----- Assertion 3: gh pr edit was recorded with correct args -----
if grep -q "pr edit feat-b --base main" "$GH_CALLS" 2>/dev/null; then
  _pass "gh pr edit feat-b --base main was called"
else
  _fail "gh pr edit feat-b --base main was not called; log: $(cat "$GH_CALLS" 2>/dev/null)"
fi

# ----- Assertion 4: bogus old-base-sha is rejected by ancestor guard -----
BOGUS_SHA="0000000000000000000000000000000000000000"
EXIT_CODE=0
(cd "$FIXTURE_REPO" && bash "$ONTO_REPARENT" feat-c main "$BOGUS_SHA") 2>/dev/null || EXIT_CODE=$?
if [[ "$EXIT_CODE" -ne 0 ]]; then
  _pass "bogus old-base-sha is rejected (ancestor guard)"
else
  _fail "bogus old-base-sha should be rejected by ancestor guard, but exited 0"
fi

# Summary
echo ""
echo "test-reparent.sh: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]]
