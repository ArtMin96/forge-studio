#!/usr/bin/env bash
# Regression-test gate for self-evolution proposals.
#
# Usage: regression-gate.sh <proposal-path>
#
# Proposal filename pattern: <plugin>-<skill>-<timestamp>.md
#   e.g.  evaluator-assess-proposal-20260516T120000Z.md
#
# Environment:
#   EVALUATOR_REGRESSION_MIN  — minimum acceptable pass rate for the proposed
#                               skill version (default: 0.8). The proposal passes
#                               the gate only when it meets or exceeds this threshold
#                               AND does not regress below the current pass rate.
#   EVALUATOR_REGRESSION_MOCK — set to 1 to skip live /run-evals-bench invocations
#                               and synthesize pass rates from file content. Intended
#                               for smoke tests where claude -p is unavailable.
#
# Swap-run-restore invariant: the original SKILL.md is backed up before the proposal
# is swapped in. The EXIT trap restores the backup on any exit path — including
# signals — so the original is never permanently displaced by a failed run.
# Lock file: .claude/.regression-gate.lock (different from score-candidate.sh which
# uses a skill-scoped lock; this lock serializes gate runs across concurrent callers).

set -euo pipefail

PROPOSAL="${1:-}"

# ── Step 1: validate proposal path ───────────────────────────────────────────
if [ -z "$PROPOSAL" ] || [ ! -r "$PROPOSAL" ]; then
  printf '%s\n' '{"verdict":"refused","reason":"proposal not found"}'
  exit 2
fi

# ── Step 2: parse plugin and skill from basename ──────────────────────────────
# Filename pattern: <plugin>-<skill>-<timestamp>.md
# Skill names contain hyphens (e.g. auto-tune-skill, entropy-scan, feature-list).
# Scan left-to-right: try every hyphen as the plugin/skill boundary until
# plugins/<plugin>/skills/<skill>/SKILL.md exists on disk.
BASENAME="$(basename "$PROPOSAL" .md)"

# Strip trailing timestamp segment: anything matching -[0-9]{8}T[0-9]{6}Z at end
# or a plain numeric suffix like -20260516T120000Z.
STEM="${BASENAME%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z}"
# If no timestamp was stripped, the stem equals the basename.

PLUGIN=""
SKILL=""

# Split on hyphens left-to-right; try every position as the plugin/skill split.
IFS='-' read -ra PARTS <<< "$STEM"
N="${#PARTS[@]}"

for ((i=1; i<N; i++)); do
  # Plugin = parts[0..i-1] joined by '-'
  CANDIDATE_PLUGIN="${PARTS[0]}"
  for ((j=1; j<i; j++)); do
    CANDIDATE_PLUGIN="${CANDIDATE_PLUGIN}-${PARTS[$j]}"
  done
  # Skill = parts[i..N-1] joined by '-'
  CANDIDATE_SKILL="${PARTS[$i]}"
  for ((k=i+1; k<N; k++)); do
    CANDIDATE_SKILL="${CANDIDATE_SKILL}-${PARTS[$k]}"
  done
  if [ -f "plugins/${CANDIDATE_PLUGIN}/skills/${CANDIDATE_SKILL}/SKILL.md" ]; then
    PLUGIN="$CANDIDATE_PLUGIN"
    SKILL="$CANDIDATE_SKILL"
    break
  fi
done

if [ -z "$PLUGIN" ] || [ -z "$SKILL" ]; then
  printf '%s\n' '{"verdict":"refused","reason":"could not resolve plugin/skill from proposal filename"}'
  exit 2
fi

# ── Step 3: resolve SKILL_PATH ───────────────────────────────────────────────
SKILL_PATH="plugins/${PLUGIN}/skills/${SKILL}/SKILL.md"
if [ ! -f "$SKILL_PATH" ]; then
  jq -cn --arg sp "$SKILL_PATH" \
    '{"verdict":"refused","reason":"target SKILL.md not found","skill_path":$sp}'
  exit 2
fi

# ── Step 4: resolve EVALS_PATH ───────────────────────────────────────────────
EVALS_PATH="plugins/${PLUGIN}/skills/${SKILL}/evals/evals.json"
if [ ! -f "$EVALS_PATH" ]; then
  jq -cn --arg p "$PLUGIN" --arg s "$SKILL" \
    '{"plugin":$p,"skill":$s,"verdict":"refused","reason":"evals.json missing"}'
  exit 2
fi

# ── Step 5: threshold ─────────────────────────────────────────────────────────
THRESHOLD="${EVALUATOR_REGRESSION_MIN:-0.8}"

# ── Step 6: acquire exclusive lock ───────────────────────────────────────────
LOCK_DIR=".claude"
mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/.regression-gate.lock"

if ! command -v flock >/dev/null 2>&1; then
  printf '%s\n' '{"verdict":"error","reason":"flock unavailable"}'
  exit 3
fi

exec 9>"$LOCK_FILE"
flock -x 9

# ── Step 7: record checksum before swap ──────────────────────────────────────
MD5_BEFORE="$(md5sum "$SKILL_PATH" | awk '{print $1}')"

# ── Step 8: EXIT trap — restore backup if it exists, release lock, clean up ──
BACKUP="${SKILL_PATH}.regression-bak.$$"
_cleanup() {
  if [ -f "$BACKUP" ]; then
    mv -f "$BACKUP" "$SKILL_PATH" 2>/dev/null || true
  fi
  exec 9>&- 2>/dev/null || true
  rm -f "$BACKUP" 2>/dev/null || true
}
trap _cleanup EXIT INT TERM

# ── Step 9: back up current SKILL.md ─────────────────────────────────────────
cp "$SKILL_PATH" "$BACKUP"

# ── Helper: run bench or mock it ─────────────────────────────────────────────
# Returns JSON with with_skill.pass_rate field.
# In mock mode, returns a fixed pass rate of 0.75 so the full gate logic (swap,
# restore, JSON emit, READY_TO_COMMIT) can be exercised without a live claude -p
# invocation. 0.75 satisfies a 0.5 threshold (happy path) but not 0.9 (regression
# path), covering both test scenarios deterministically.
_bench_pass_rate() {
  if [ "${EVALUATOR_REGRESSION_MOCK:-0}" = "1" ]; then
    printf '%s\n' '{"with_skill":{"pass_rate":0.75}}'
  else
    # Live bench via /run-evals-bench (the SEPL evaluation harness).
    claude -p "Run /run-evals-bench skill=${PLUGIN}:${SKILL}" \
      --output-format json 2>/dev/null \
      | jq -c '{with_skill:{pass_rate:(.with_skill.pass_rate // 0)}}'
  fi
}

# Also need per-eval results for REGRESSED_IDS computation.
# In mock mode, all evals are marked passed (no regression between current and
# proposal). This is correct for the happy-path and regression-path tests, where
# the failure is driven by the threshold check, not per-eval flips.
_bench_eval_results() {
  if [ "${EVALUATOR_REGRESSION_MOCK:-0}" = "1" ]; then
    jq -c '[.evals[] | {id:.id, passed: true}]' "$EVALS_PATH"
  else
    claude -p "Run /run-evals-bench skill=${PLUGIN}:${SKILL} --per-eval" \
      --output-format json 2>/dev/null \
      | jq -c '[.evals[] | {id:.id, passed:.passed}]'
  fi
}

# ── Step 10: current-state bench ─────────────────────────────────────────────
BENCH_CURRENT="$(_bench_pass_rate "$SKILL_PATH")"
P_CURRENT="$(printf '%s' "$BENCH_CURRENT" | jq -r '.with_skill.pass_rate')"
EVAL_RESULTS_CURRENT="$(_bench_eval_results "$SKILL_PATH")"

# ── Step 11: swap proposal into SKILL_PATH (strip proposal header if present) ─
# If the first non-empty line of the proposal starts with "proposal_status:",
# strip the 4-5 line header block (lines up to and including the blank line
# that separates the header from the SKILL.md content).
FIRST_LINE="$(head -1 "$PROPOSAL")"
if [[ "$FIRST_LINE" == proposal_status:* ]]; then
  # Find the line number of the first blank line (end of header block).
  BLANK_LINE="$(grep -n '^[[:space:]]*$' "$PROPOSAL" | head -1 | cut -d: -f1)"
  if [ -n "$BLANK_LINE" ]; then
    tail -n +"$((BLANK_LINE + 1))" "$PROPOSAL" > "$SKILL_PATH"
  else
    cp "$PROPOSAL" "$SKILL_PATH"
  fi
else
  cp "$PROPOSAL" "$SKILL_PATH"
fi

# ── Step 12: proposal-state bench ────────────────────────────────────────────
BENCH_PROPOSAL="$(_bench_pass_rate "$SKILL_PATH")"
P_PROPOSAL="$(printf '%s' "$BENCH_PROPOSAL" | jq -r '.with_skill.pass_rate')"
EVAL_RESULTS_PROPOSAL="$(_bench_eval_results "$SKILL_PATH")"

# ── Step 13: restore original SKILL.md ───────────────────────────────────────
mv "${BACKUP}" "$SKILL_PATH"
# Verify byte-identical restore.
MD5_AFTER="$(md5sum "$SKILL_PATH" | awk '{print $1}')"
if [ "$MD5_BEFORE" != "$MD5_AFTER" ]; then
  jq -cn --arg p "$PLUGIN" --arg s "$SKILL" \
    '{"verdict":"error","reason":"restore failed: md5 mismatch after restore","plugin":$p,"skill":$s}'
  exit 3
fi

# ── Step 14: release lock ─────────────────────────────────────────────────────
exec 9>&-

# ── Step 15: compute regressed eval IDs (up to 3) ────────────────────────────
REGRESSED_IDS="$(jq -cn \
  --argjson cur "$EVAL_RESULTS_CURRENT" \
  --argjson prop "$EVAL_RESULTS_PROPOSAL" \
  '
  [$cur[] | {id:.id, passed:.passed}] as $c |
  [$prop[] | {id:.id, passed:.passed}] as $p |
  [
    $c[] |
    . as $ce |
    ($p[] | select(.id == $ce.id)) as $pe |
    select($ce.passed == true and $pe.passed == false) |
    .id
  ] | .[0:3]
  ')"

# ── Step 16: decision ─────────────────────────────────────────────────────────
# Pass requires: P_PROPOSAL >= P_CURRENT  AND  P_PROPOSAL >= THRESHOLD
VERDICT="$(awk -v pp="$P_PROPOSAL" -v pc="$P_CURRENT" -v thr="$THRESHOLD" \
  'BEGIN { if (pp+0 >= pc+0 && pp+0 >= thr+0) print "pass"; else print "fail" }')"

EXIT_CODE=1
if [ "$VERDICT" = "pass" ]; then
  EXIT_CODE=0
fi

# ── Step 17: emit JSON (compact — one line so callers can head -1 | jq) ───────
jq -cn \
  --arg plugin "$PLUGIN" \
  --arg skill "$SKILL" \
  --argjson p_current "$P_CURRENT" \
  --argjson p_proposal "$P_PROPOSAL" \
  --argjson threshold "$THRESHOLD" \
  --arg verdict "$VERDICT" \
  --argjson regressed_eval_ids "$REGRESSED_IDS" \
  '{plugin:$plugin,skill:$skill,p_current:$p_current,p_proposal:$p_proposal,threshold:$threshold,verdict:$verdict,regressed_eval_ids:$regressed_eval_ids}'

# ── Step 18: READY_TO_COMMIT line on pass ─────────────────────────────────────
if [ "$VERDICT" = "pass" ]; then
  printf 'READY_TO_COMMIT %s:%s p_current=%s p_proposal=%s\n' \
    "$PLUGIN" "$SKILL" "$P_CURRENT" "$P_PROPOSAL"
fi

exit "$EXIT_CODE"
