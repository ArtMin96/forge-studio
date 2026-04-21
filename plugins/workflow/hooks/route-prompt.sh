#!/usr/bin/env bash
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
    if has '\b(across|multiple|several|entire|whole)\b' || [ "$WORD_COUNT" -ge 40 ]; then
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
{
  printf '{"ts":"%s","mode":"%s","route":"%s","confidence":"%s","reason":"%s"}\n' \
    "$(date -Iseconds)" "$MODE" "$ROUTE" "$CONFIDENCE" "$REASON"
} >> "$TRACE_DIR/classifications.jsonl" 2>/dev/null || true

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
    SUGGESTION="Non-trivial feature detected. Consider /dispatch and use the planner → generator → reviewer pipeline (agents plugin). Write a ## Contract section in the plan."
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

printf '[workflow router] route=%s confidence=%s reason=%s\n%s\n' \
  "$ROUTE" "$CONFIDENCE" "$REASON" "$SUGGESTION"

exit 0
