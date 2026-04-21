#!/usr/bin/env bash
# LLM fallback classifier. Invoked by route-prompt.sh when mode=llm or
# mode=hybrid + shell confidence is low. Emits tab-separated route<TAB>confidence<TAB>reason
# on stdout, or nothing if unavailable (graceful degradation).
#
# Stays no-op when:
#   - `claude` CLI is not on PATH
#   - ANTHROPIC_API_KEY not set AND no subscription-bound claude login
# This keeps the hybrid mode safe for users without API access.

PROMPT=$(cat 2>/dev/null || true)
MODEL="${WORKFLOW_ROUTER_LLM_MODEL:-claude-haiku-4-5-20251001}"

if [ -z "$PROMPT" ]; then
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  exit 0
fi

SYSTEM_PROMPT='You are a routing classifier. Read the user prompt and output exactly one line:
ROUTE<TAB>CONFIDENCE<TAB>REASON

Where:
- ROUTE is one of: single-agent, pipeline, fan-out, tdd-loop, none
- CONFIDENCE is a decimal 0.0-1.0
- REASON is one short clause (max 80 chars)

Rules:
- single-agent: narrow fix, 1-3 files, clear scope
- pipeline: feature / architecture / refactor with 3+ files
- fan-out: same operation applied independently across many targets
- tdd-loop: explicit test-first intent
- none: conversational, clarifying, non-coding, or too ambiguous
Output nothing else. No preamble, no trailing commentary.'

# Truncate to protect against overly long prompts.
TRUNCATED=$(printf '%s' "$PROMPT" | head -c 4000)

RESPONSE=$(printf '%s' "$TRUNCATED" \
  | claude -p --model "$MODEL" --system "$SYSTEM_PROMPT" --max-turns 1 2>/dev/null \
  | head -1)

# Basic sanity: must contain tab-separated fields and a known route.
if echo "$RESPONSE" | grep -qE '^(single-agent|pipeline|fan-out|tdd-loop|none)'; then
  printf '%s' "$RESPONSE"
fi

exit 0
