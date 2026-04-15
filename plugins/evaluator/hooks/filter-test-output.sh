#!/usr/bin/env bash
# PostToolUse(Bash): Backpressure for test runner output.
# Detects test commands, replaces verbose passing output with summary.
# Passes through failure output (truncated to actionable content).
# Rationale (HumanLayer, 2026): 4000+ lines of passing tests causes hallucination.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // empty' 2>/dev/null)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_result.stdout // empty' 2>/dev/null)

# Only process test runner commands
case "$COMMAND" in
  *pest*|*phpunit*|*jest*|*vitest*|*pytest*|*"go test"*|*mocha*|*"npm test"*|*"yarn test"*|*"pnpm test"*)
    ;;
  *)
    exit 0
    ;;
esac

# Count output lines
LINE_COUNT=$(echo "$OUTPUT" | wc -l)

# Only filter if output is large (>50 lines)
if [ "$LINE_COUNT" -lt 50 ]; then
  exit 0
fi

if [ "$EXIT_CODE" = "0" ]; then
  # Success: extract summary line if available, otherwise report line count
  SUMMARY=$(echo "$OUTPUT" | grep -iE '(pass|ok|success|tests?:)' | tail -1)
  if [ -n "$SUMMARY" ]; then
    echo "Tests passed. Summary: ${SUMMARY} (${LINE_COUNT} lines of output suppressed for context efficiency)"
  else
    echo "Tests passed (exit 0). ${LINE_COUNT} lines of output suppressed for context efficiency."
  fi
else
  # Failure: show first failure + summary, suppress passing output
  FAILURE_START=$(echo "$OUTPUT" | grep -inE '(FAIL|ERROR|FAILED|AssertionError|Exception|×|✗)' | head -1 | cut -d: -f1)
  if [ -n "$FAILURE_START" ]; then
    # Show 20 lines around first failure
    START=$((FAILURE_START > 5 ? FAILURE_START - 5 : 1))
    echo "Test failure detected (${LINE_COUNT} total lines, showing first failure):"
    echo "$OUTPUT" | sed -n "${START},$((START + 20))p"
    # Also show summary line if present
    SUMMARY=$(echo "$OUTPUT" | tail -5)
    echo "---"
    echo "$SUMMARY"
  fi
  # If we can't find the failure pattern, don't filter — let full output through
fi

exit 0
