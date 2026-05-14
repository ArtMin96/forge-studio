#!/usr/bin/env bash
# rtk-healthcheck.sh — verify the bootstrap left rtk usable.
# Runs after rtk-bootstrap.sh in the same SessionStart group. Always exits 0
# so a failure does not kill session startup, but emits a multi-line warning
# to stderr so a broken integration cannot stay silent.
#
# Opt-out: export FORGE_RTK_DISABLED=1

set -euo pipefail

[ "${FORGE_RTK_DISABLED:-0}" = "1" ] && exit 0

export PATH="$HOME/.local/bin:$PATH"

problems=()

if ! command -v rtk >/dev/null 2>&1; then
  problems+=("- 'rtk' is not on PATH")
fi

if [ ${#problems[@]} -eq 0 ]; then
  if ! rtk --version >/dev/null 2>&1; then
    problems+=("- 'rtk --version' did not return 0 (binary present but unhealthy)")
  fi
fi

if [ ${#problems[@]} -gt 0 ]; then
  {
    echo "rtk-optimizer: integration check FAILED — Bash rewrites will not run this session:"
    for p in "${problems[@]}"; do echo "  $p"; done
    echo "  Remediation:"
    echo "    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
    echo "    rtk init -g --auto-patch"
    echo "  To silence: export FORGE_RTK_DISABLED=1"
  } >&2
fi

exit 0
