#!/usr/bin/env bash
# PreCompact: advisory only. Nudge the user to run /progress-log so durable state
# survives compaction. We do NOT exit 2 here — context-engine's pre-compact-guard
# already blocks when state would genuinely be lost. Stacking blocks is noise.
# Anthropic principle: graceful degradation over hard fail.

INPUT=$(cat 2>/dev/null || true)
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "auto"' 2>/dev/null)

# Only emit on auto-compact (user-initiated compacts are deliberate).
if [ "$TRIGGER" != "auto" ]; then
  exit 0
fi

# Skip if the progress log was appended in the last 10 minutes.
PROGRESS_FILE="claude-progress.txt"
if [ -f "$PROGRESS_FILE" ]; then
  if find "$PROGRESS_FILE" -mmin -10 2>/dev/null | grep -q .; then
    exit 0
  fi
fi

echo "[workflow] Auto-compaction imminent. Run /progress-log (long-session) now to persist decisions, in-progress work, and gotchas. Otherwise they may be lost on compaction."
exit 0
