#!/usr/bin/env bash
set -euo pipefail
# UserPromptSubmit: classify the incoming prompt and nudge toward the right
# orchestration pattern. Shell-first deterministic classifier (zero token cost).
# Optional LLM fallback when WORKFLOW_ROUTER_MODE=hybrid|llm.
#
# Advisory only. Never blocks. Silent on low-signal prompts (conversational,
# clarifying questions, follow-ups) so we don't spam every turn.
#
# Anthropic, "Building Effective Agents": router pattern cuts inference cost ~40%
# with <2% quality loss when routing accuracy >95%. Shell classifier defaults to
# high precision / modest recall: we only emit when confident.

INPUT=$(cat 2>/dev/null || true)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-default}"

if [ -z "$PROMPT" ]; then
  exit 0
fi

MODE="${WORKFLOW_ROUTER_MODE:-shell}"
THRESHOLD="${WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD:-0.75}"
DIRECTIVE_THRESHOLD="${WORKFLOW_ROUTER_DIRECTIVE_THRESHOLD:-0.90}"
DIRECTIVE_MODE="${WORKFLOW_ROUTER_DIRECTIVE_MODE:-on}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
TRACE_DIR="/tmp/claude-router-${SESSION_ID}"
mkdir -p "$TRACE_DIR" 2>/dev/null || true

# Normalize to lowercase for matching, trim very long prompts (we only need
# surface signals — verbs, counts, file extensions).
PROMPT_LC=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]' | head -c 2000)
WORD_COUNT=$(printf '%s' "$PROMPT_LC" | wc -w)

classify_shell() {
  local route="none"
  local reason=""
  local confidence="0"
  local p="$PROMPT_LC"

  has() { printf '%s' "$p" | grep -qE "$1"; }

  # Priority 1: TDD — explicit test-first intent wins over every other signal.
  if has '\b(tdd|red-green|red.green.refactor|test-first|write (a )?(failing )?test|reproduce.{0,20}bug)\b'; then
    route="tdd-loop"
    reason="explicit TDD / test-first language"
    confidence="0.90"

  # Priority 2: Pipeline — building something new.
  # Checked before fan-out because "implement X across modules" is a feature build,
  # not the same-op-many-places pattern fan-out targets.
  elif has '\b(implement|build|design|architect|add (a )?(new )?(feature|module|endpoint|system|page|component|api))\b'; then
    # Word-count alone is not a scope signal — long narrow prompts (e.g. a detailed
    # single-function implementation) were being mis-routed to pipeline. Require an
    # explicit scope marker instead.
    if has '\b(across|multiple|several|entire|whole|end-to-end|throughout)\b'; then
      route="pipeline"
      reason="feature/architecture work with non-trivial scope"
      confidence="0.85"
    else
      route="single-agent"
      reason="implementation verb but narrow scope"
      confidence="0.70"
    fi

  # Priority 3: Pipeline — large refactor. Kept separate so "refactor foo" (narrow)
  # doesn't force the full pipeline.
  elif has '\brefactor\b' && { has '\b(across|multiple|several|entire|whole)\b' || [ "$WORD_COUNT" -ge 40 ]; }; then
    route="pipeline"
    reason="large refactor"
    confidence="0.80"

  # Priority 4: Fan-out — same operation applied independently across many targets.
  # Strict AND across three signals: batch verb + many-targets preposition + target nouns.
  elif has '\b(update|migrate|rename|convert|apply|port|replace)\b' \
    && has '\b(across|in all|to each|for every|in every|in multiple|in several)\b' \
    && has '\b(files?|components?|endpoints?|modules?|tests?|services?|handlers?)\b'; then
    route="fan-out"
    reason="same op across enumerated targets"
    confidence="0.80"

  # Priority 5: Single-agent — narrow verb + short prompt.
  elif has '\b(fix typo|rename|add (a )?log|update (the )?comment|adjust (the )?(format|spacing|indent))\b' \
    || { has '\b(fix|tweak|adjust|update|change)\b' && [ "$WORD_COUNT" -lt 20 ]; }; then
    route="single-agent"
    reason="narrow change, single-file verb"
    confidence="0.85"
  fi

  printf '%s\t%s\t%s' "$route" "$confidence" "$reason"
}

RESULT=$(classify_shell)
ROUTE=$(echo "$RESULT" | cut -f1)
CONFIDENCE=$(echo "$RESULT" | cut -f2)
REASON=$(echo "$RESULT" | cut -f3)

# Persist for trace mining (no PII beyond what the user typed — trace is session-scoped).
TRACE_LINE=$(printf '{"ts":"%s","mode":"%s","route":"%s","confidence":"%s","reason":"%s"}' \
  "$(date -Iseconds)" "$MODE" "$ROUTE" "$CONFIDENCE" "$REASON")
bash "${CLAUDE_PLUGIN_ROOT}/../_lib/jsonl-append.sh" --with-turn-id "$TRACE_DIR/classifications.jsonl" "$TRACE_LINE" <<< "$INPUT"

# Hybrid / LLM escalation when shell is uncertain.
ESCALATE=0
case "$MODE" in
  llm)
    ESCALATE=1
    ;;
  hybrid)
    # bash can't compare floats directly; use awk.
    if [ "$ROUTE" = "none" ] || awk -v c="$CONFIDENCE" -v t="$THRESHOLD" 'BEGIN{exit !(c<t)}'; then
      ESCALATE=1
    fi
    ;;
esac

if [ "$ESCALATE" = "1" ] && [ -x "$PLUGIN_ROOT/hooks/route-prompt-llm.sh" ]; then
  LLM_RESULT=$(printf '%s' "$PROMPT" | bash "$PLUGIN_ROOT/hooks/route-prompt-llm.sh" 2>/dev/null)
  if [ -n "$LLM_RESULT" ]; then
    ROUTE=$(echo "$LLM_RESULT" | cut -f1)
    CONFIDENCE=$(echo "$LLM_RESULT" | cut -f2)
    REASON=$(echo "$LLM_RESULT" | cut -f3)
  fi
fi

# Silent when we don't have a confident recommendation.
if [ "$ROUTE" = "none" ] || [ -z "$ROUTE" ]; then
  exit 0
fi

case "$ROUTE" in
  single-agent)
    SUGGESTION="Narrow change detected. Execute directly; skip the planner→generator→reviewer pipeline."
    ;;
  pipeline)
    SUGGESTION="Non-trivial feature detected. Run /orchestrate pipeline once a plan exists; it iterates each #### T<n> task with its own generator → reviewer → /verify cycle (small, predictable agent-loop surface)."
    ;;
  fan-out)
    SUGGESTION="Parallel-safe batch detected. Consider /fan-out (agents plugin) with 3–5 workers per batch."
    ;;
  tdd-loop)
    SUGGESTION="Test-first intent detected. Consider /tdd-loop — RED→GREEN→REFACTOR gates enforced against a real test runner."
    ;;
  *)
    exit 0
    ;;
esac

# One-shot cap: suppress identical (route, reason, prompt) reminders within a
# session so the same nudge doesn't fire every turn for the same context.
# Scope decision: applied here only. Other hooks are either event-rare
# (pre-compact-handoff, session-bootstrap), rate-gated by their own mechanism
# (turn-gate self-review-nudge), or intentionally fire-every-turn
# (behavioral-anchor — load-bearing steering).
#
# The trace write above is intentionally before this guard so classification
# telemetry is always recorded, even when the reminder is suppressed.
REMINDERS_DIR=".claude/state/reminders"
mkdir -p "$REMINDERS_DIR" 2>/dev/null || true
STATE_FILE="$REMINDERS_DIR/route-prompt-${SESSION_ID}"

PROMPT_MD5=$(printf '%s' "$PROMPT" | md5sum | cut -d' ' -f1)
STATE_HASH=$(printf '%s:%s:%s' "$ROUTE" "$REASON" "$PROMPT_MD5" | md5sum | cut -d' ' -f1)

EXISTING_HASH=""
if [ -f "$STATE_FILE" ]; then
  EXISTING_HASH=$(cat "$STATE_FILE" 2>/dev/null || true)
fi

if [ "$EXISTING_HASH" = "$STATE_HASH" ] && [ "${FORGE_REMINDER_FORCE:-0}" != "1" ]; then
  exit 0
fi

USE_DIRECTIVE=0
if [ "$DIRECTIVE_MODE" = "on" ] && [ "$ROUTE" != "single-agent" ] \
  && awk -v c="$CONFIDENCE" -v t="$DIRECTIVE_THRESHOLD" 'BEGIN{exit !(c>=t)}'; then
  USE_DIRECTIVE=1
fi

if [ "$USE_DIRECTIVE" = "1" ]; then
  case "$ROUTE" in
    pipeline)
      HUMAN="pipeline"
      EXEC="/orchestrate pipeline   # iterates each #### T<n> with planner→generator→reviewer→/verify"
      ;;
    tdd-loop)
      HUMAN="TDD loop"
      EXEC="/tdd-loop   # RED→GREEN→REFACTOR gates against the real test runner"
      ;;
    fan-out)
      HUMAN="fan-out batch"
      EXEC="/fan-out --workers 3-5   # parallel-safe batch across enumerated targets"
      ;;
    *)
      HUMAN="$ROUTE"
      EXEC="/orchestrate $ROUTE"
      ;;
  esac
  printf '[workflow router: directive] route=%s confidence=%s reason=%s\n\nROUTE SELECTED: %s\nEXECUTE: %s\nWHY: %s\n\nIf you have a concrete reason this route is wrong, state it in one sentence and proceed differently. Otherwise execute the route above.\n\nOverride: set WORKFLOW_ROUTER_DIRECTIVE_MODE=off (advisory mode), or run with WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD raised above %s to suppress.\n' \
    "$ROUTE" "$CONFIDENCE" "$REASON" "$HUMAN" "$EXEC" "$REASON" "$CONFIDENCE"
else
  printf '[workflow router] route=%s confidence=%s reason=%s\n%s\n' \
    "$ROUTE" "$CONFIDENCE" "$REASON" "$SUGGESTION"
fi

printf '%s' "$STATE_HASH" > "$STATE_FILE"

exit 0
