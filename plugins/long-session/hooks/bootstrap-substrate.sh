#!/usr/bin/env bash
# SessionStart: idempotently create the .claude/ substrate that long-session,
# evaluator, and agents depend on (.claude/plans/, .claude/gate/, .claude/spec.md,
# .claude/features.json). Without this, after-subagent.sh, /verify, /contract,
# /dispatch, and /feature-list silently no-op on first project use.
#
# Real-repo gate identical to surface-progress.sh — bail on non-project dirs.
# Opt-out: FORGE_LONG_SESSION_BOOTSTRAP=0. Silent unless something is created.

set -u

[ "${FORGE_LONG_SESSION_BOOTSTRAP:-1}" = "0" ] && exit 0

if [ ! -d .git ] && [ ! -f package.json ] && [ ! -f composer.json ] && [ ! -f pyproject.toml ] && [ ! -f Cargo.toml ] && [ ! -f go.mod ]; then
  exit 0
fi

CREATED=()

if [ ! -d .claude/plans ]; then
  mkdir -p .claude/plans 2>/dev/null && CREATED+=(".claude/plans/")
fi

if [ ! -d .claude/gate ]; then
  mkdir -p .claude/gate 2>/dev/null && CREATED+=(".claude/gate/")
fi

if [ ! -f .claude/spec.md ]; then
  : > .claude/spec.md 2>/dev/null && CREATED+=(".claude/spec.md")
fi

if [ ! -f .claude/features.json ]; then
  echo '[]' > .claude/features.json 2>/dev/null && CREATED+=(".claude/features.json")
fi

if [ "${#CREATED[@]}" -gt 0 ]; then
  printf '[long-session] Bootstrapped forge substrate: %s\n' "${CREATED[*]}"
  printf '[long-session] Run /init-sh to scaffold dev-env bootstrap, /feature-list to populate features.json from a plan, /progress-log to start the durable session log.\n'
fi

exit 0
