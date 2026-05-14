#!/usr/bin/env bash
set -euo pipefail
# score-candidate.sh — score a candidate SKILL.md via bench.py (swap-restore pattern)
#
# Temporarily replaces the target SKILL.md with the candidate, runs bench.py,
# parses the result, then restores the original. The trap on EXIT guarantees
# the original is restored on every normal exit path (including errors).
# A kill -9 leaves a *.autotune-bak.<pid> orphan but does not corrupt the target.
#
# Args: <candidate-skill-md-path> <plugin>:<skill> [--mock]
# Env:  FORGE_AUTO_TUNE_MOCK=1  — equivalent to passing --mock
#
# Stdout: {"candidate_id":"<name>","pass_rate":<float>,"token_cost":<int>}
# Exit:   0 always (errors yield the placeholder JSON so the outer loop can continue)

if [[ $# -lt 2 ]]; then
  echo "Usage: score-candidate.sh <candidate-path> <plugin>:<skill> [--mock]" >&2
  exit 1
fi

CANDIDATE_PATH="$1"
SKILL_ARG="$2"
MOCK_FLAG=""

# Accept --mock as third arg or via env
if [[ "${3:-}" == "--mock" ]] || [[ "${FORGE_AUTO_TUNE_MOCK:-0}" == "1" ]]; then
  MOCK_FLAG="--mock"
fi

PLUGIN="${SKILL_ARG%%:*}"
SKILL="${SKILL_ARG##*:}"

if [[ -z "$PLUGIN" || -z "$SKILL" || "$PLUGIN" == "$SKILL_ARG" ]]; then
  echo "Error: second argument must be <plugin>:<skill>, got: $SKILL_ARG" >&2
  exit 1
fi

if [[ ! -f "$CANDIDATE_PATH" ]]; then
  echo "Error: candidate not found: $CANDIDATE_PATH" >&2
  exit 1
fi

CANDIDATE_ID="$(basename "$CANDIDATE_PATH")"

# ---------------------------------------------------------------------------
# Resolve repo root (score-candidate.sh lives at:
#   plugins/forge-meta/skills/auto-tune-skill/scripts/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

TARGET="$REPO_ROOT/plugins/$PLUGIN/skills/$SKILL/SKILL.md"
BENCH_PY="$REPO_ROOT/plugins/evaluator/skills/run-evals-bench/scripts/bench.py"

if [[ ! -f "$TARGET" ]]; then
  echo "Error: target SKILL.md not found: $TARGET" >&2
  exit 1
fi

if [[ ! -f "$BENCH_PY" ]]; then
  echo "Error: bench.py not found: $BENCH_PY" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Placeholder output (used on mock mode or bench failure)
# ---------------------------------------------------------------------------
placeholder_json() {
  python3 -c "import json; print(json.dumps({'candidate_id': '$CANDIDATE_ID', 'pass_rate': 0.5, 'token_cost': 1000}))"
}

# ---------------------------------------------------------------------------
# Lock, backup, swap, run, restore
# ---------------------------------------------------------------------------
LOCK_FILE="/tmp/forge-autotune-${PLUGIN}-${SKILL}.lock"
BACKUP="${TARGET}.autotune-bak.$$"

# Cleanup function registered as trap — runs on every exit including errors.
cleanup() {
  if [[ -f "$BACKUP" ]]; then
    mv -f "$BACKUP" "$TARGET" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Temporary bench output dir (cleaned up at end).
TMP_OUT="$(mktemp -d /tmp/forge-bench-XXXXXX)"

# Wrap everything that touches the target under a flock so concurrent
# score-candidate.sh calls for the same skill serialize.
(
  flock -x 200

  # Backup original.
  cp "$TARGET" "$BACKUP"

  # Swap in candidate.
  cp "$CANDIDATE_PATH" "$TARGET"

  # Run bench — capture exit code without aborting the script.
  BENCH_EXIT=0
  python3 "$BENCH_PY" --skill "$SKILL" --iterations 1 --out "$TMP_OUT" $MOCK_FLAG 2>/dev/null || BENCH_EXIT=$?

  # Restore is handled by the EXIT trap after this subshell exits.
  # But we restore explicitly here so the flock window is as narrow as possible.
  mv -f "$BACKUP" "$TARGET" 2>/dev/null || true

  # Parse results.
  BENCHMARK_JSON="$TMP_OUT/iteration-1/benchmark.json"

  if [[ "$BENCH_EXIT" -ne 0 ]] || [[ "${MOCK_FLAG}" == "--mock" ]] || [[ ! -f "$BENCHMARK_JSON" ]]; then
    placeholder_json
  else
    python3 - "$BENCHMARK_JSON" "$CANDIDATE_ID" <<'PYEOF'
import json, sys
path, cid = sys.argv[1], sys.argv[2]
data = json.loads(open(path).read())
ws = data.get("with_skill", {})
pass_rate = float(ws.get("pass_rate", 0.5))
token_cost = int(ws.get("tokens", 1000))
print(json.dumps({"candidate_id": cid, "pass_rate": pass_rate, "token_cost": token_cost}))
PYEOF
  fi

) 200>"$LOCK_FILE"

# Cleanup temp bench output.
rm -rf "$TMP_OUT" 2>/dev/null || true
