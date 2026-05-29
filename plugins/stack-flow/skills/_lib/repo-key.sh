#!/usr/bin/env bash
# Prints a stable, per-repo key for use in CLAUDE_PLUGIN_DATA path segments.
# Prefer the remote origin URL (stable across clones of the same repo) over
# the local toplevel path (unstable when the clone is moved or renamed).

set -euo pipefail

url=$(git config --get remote.origin.url 2>/dev/null || true)

if [[ -n "$url" ]]; then
  printf '%s' "$url" | sha1sum | cut -c1-12
else
  # No remote: fall back to the absolute toplevel path so different local
  # repos still get distinct keys, at the cost of clone-portability.
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  printf '%s' "$toplevel" | sha1sum | cut -c1-12
fi
