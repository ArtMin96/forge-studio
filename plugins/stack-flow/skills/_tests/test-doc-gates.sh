#!/usr/bin/env bash
# Contract criterion 6: all Forge Studio doc / count / marketplace gates pass.
#
# This test is EXPECTED TO FAIL until the plugin is registered in the marketplace,
# its doc guides are written, and the README hook count is reconciled.
# run-all.sh runs this last and respects SKIP_DOC_GATES=1 to skip it.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../../../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

_pass() { echo "  PASS: $1"; PASS_COUNT=$((PASS_COUNT+1)); }
_fail() { echo "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

echo "--- test-doc-gates.sh ---"

# ----- Gate 1: count.sh produces a well-formed header line -----
COUNT_OUT=$(bash "$REPO_ROOT/plugins/diagnostics/skills/entropy-scan/scripts/count.sh" "$REPO_ROOT" 2>/dev/null) || {
  _fail "count.sh failed to run"
  echo "test-doc-gates.sh: 0 passed, $FAIL_COUNT failed (expected-red until the plugin is registered)"
  exit 1
}
if printf '%s' "$COUNT_OUT" | grep -qE '^[0-9]+ plugins\. [0-9]+ skills\. [0-9]+ hooks\. [0-9]+ agents\. [0-9]+ behavioral rules\.$'; then
  _pass "count.sh header line is well-formed"
else
  _fail "count.sh header line malformed; got: $COUNT_OUT"
fi

# ----- Gate 2: three README count locations agree -----
HEADER_HOOKS=$(printf '%s' "$COUNT_OUT" | grep -oE '[0-9]+ hooks' | grep -oE '[0-9]+' | head -1)

README="$REPO_ROOT/README.md"

README_LINE5_HOOKS=$(grep -oE '[0-9]+ hooks' "$README" | head -1 | grep -oE '[0-9]+')
ACTIVE_HOOKS_PARA=$(grep 'hook command registrations' "$README" | grep -oE '[0-9]+' | head -1)

if [[ "$HEADER_HOOKS" == "$README_LINE5_HOOKS" ]]; then
  _pass "count.sh hooks == README header hooks ($HEADER_HOOKS)"
else
  _fail "count.sh hooks ($HEADER_HOOKS) != README header hooks ($README_LINE5_HOOKS)"
fi

if [[ "$HEADER_HOOKS" == "$ACTIVE_HOOKS_PARA" ]]; then
  _pass "count.sh hooks == Active Hooks paragraph ($HEADER_HOOKS)"
else
  _fail "count.sh hooks ($HEADER_HOOKS) != Active Hooks paragraph ($ACTIVE_HOOKS_PARA)"
fi

# ----- Gate 3: stack-flow registered in marketplace.json -----
MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
if python3 -c "
import json, sys
d = json.load(open('$MARKETPLACE'))
names = [e['name'] for e in d.get('plugins', d if isinstance(d, list) else [])]
assert 'stack-flow' in names, 'stack-flow not in marketplace'
" 2>/dev/null; then
  _pass "stack-flow registered in marketplace.json"
else
  _fail "stack-flow not registered in marketplace.json (expected until the plugin is registered)"
fi

# ----- Gate 4: plugin.json and marketplace version agree -----
PLUGIN_JSON="$REPO_ROOT/plugins/stack-flow/.claude-plugin/plugin.json"
if [[ -f "$PLUGIN_JSON" ]]; then
  PLUGIN_VER=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])" 2>/dev/null || echo "")
  MKT_VER=$(python3 -c "
import json
d = json.load(open('$MARKETPLACE'))
entries = d if isinstance(d, list) else d.get('plugins', [])
for e in entries:
  if e.get('name') == 'stack-flow':
    print(e.get('version',''))
    break
" 2>/dev/null || echo "")
  if [[ -n "$PLUGIN_VER" && "$PLUGIN_VER" == "$MKT_VER" ]]; then
    _pass "plugin.json version matches marketplace ($PLUGIN_VER)"
  else
    _fail "plugin.json version ($PLUGIN_VER) != marketplace version ($MKT_VER)"
  fi
else
  _fail "plugin.json not found at $PLUGIN_JSON"
fi

# ----- Gate 5: all JSON in the plugin parses -----
ALL_JSON_OK=1
while IFS= read -r jf; do
  if ! python3 -c "import json; json.load(open('$jf'))" 2>/dev/null; then
    _fail "JSON parse failed: $jf"
    ALL_JSON_OK=0
  fi
done < <(find "$REPO_ROOT/plugins/stack-flow" -name '*.json' 2>/dev/null)
if [[ "$ALL_JSON_OK" -eq 1 ]]; then
  _pass "all plugin JSON files parse cleanly"
fi

# ----- Gate 6: hook scripts and skills/_lib scripts are executable -----
ALL_X_OK=1
while IFS= read -r sh; do
  if [[ ! -x "$sh" ]]; then
    _fail "not executable: $sh"
    ALL_X_OK=0
  fi
done < <(find "$REPO_ROOT/plugins/stack-flow/hooks" "$REPO_ROOT/plugins/stack-flow/skills/_lib" \
           -name '*.sh' 2>/dev/null)
if [[ "$ALL_X_OK" -eq 1 ]]; then
  _pass "all hook and _lib scripts are executable"
fi

# ----- Gate 7: each model-facing skill has evals/evals.json -----
ALL_EVALS_OK=1
while IFS= read -r skill_md; do
  skill_dir="$(dirname "$skill_md")"
  evals="$skill_dir/evals/evals.json"
  if [[ ! -f "$evals" ]]; then
    _fail "missing evals.json for skill: $skill_md"
    ALL_EVALS_OK=0
  else
    if ! python3 -c "import json; json.load(open('$evals'))" 2>/dev/null; then
      _fail "evals.json does not parse: $evals"
      ALL_EVALS_OK=0
    fi
  fi
done < <(find "$REPO_ROOT/plugins/stack-flow/skills" -name 'SKILL.md' \
           -not -path '*/_*' 2>/dev/null)
if [[ "$ALL_EVALS_OK" -eq 1 ]]; then
  _pass "all model-facing skills have valid evals/evals.json"
fi

# ----- Gate 8: each skill has a docs/skills/stack-flow/<skill>.md guide -----
ALL_DOCS_OK=1
while IFS= read -r skill_md; do
  skill_name="$(basename "$(dirname "$skill_md")")"
  guide="$REPO_ROOT/docs/skills/stack-flow/${skill_name}.md"
  if [[ ! -f "$guide" ]]; then
    _fail "missing doc guide: $guide"
    ALL_DOCS_OK=0
  fi
done < <(find "$REPO_ROOT/plugins/stack-flow/skills" -name 'SKILL.md' \
           -not -path '*/_*' 2>/dev/null)
if [[ "$ALL_DOCS_OK" -eq 1 ]]; then
  _pass "all skills have docs/skills/stack-flow/<skill>.md guide"
fi

# Summary
echo ""
echo "test-doc-gates.sh: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "  (expected-red until the plugin is registered and counts reconciled; behavioral tests 1-5 are the green gate)"
[[ "$FAIL_COUNT" -eq 0 ]]
