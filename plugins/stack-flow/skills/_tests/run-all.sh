#!/usr/bin/env bash
# Run all stack-flow fixture-repo unit tests in order.
# Exits non-zero on the first failure.
#
# Environment:
#   SKIP_DOC_GATES=1   Skip test-doc-gates.sh (expected-red until the plugin is registered).
#                      Use this to validate behavioral tests 1-5 now.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_run_test() {
  local name="$1"
  local script="$TESTS_DIR/$name"
  echo ""
  if bash "$script"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    exit 1
  fi
}

echo "=== stack-flow test suite ==="

_run_test test-push-guard.sh
_run_test test-restack.sh
_run_test test-reparent.sh
_run_test test-pr-body.sh
_run_test test-stack-graph.sh

if [[ "${SKIP_DOC_GATES:-0}" == "1" ]]; then
  echo ""
  echo "SKIP: test-doc-gates.sh (SKIP_DOC_GATES=1; expected-red until the plugin is registered)"
else
  _run_test test-doc-gates.sh
fi

echo ""
echo "=== All tests passed ==="
