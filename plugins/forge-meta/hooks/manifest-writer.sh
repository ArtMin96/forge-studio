#!/usr/bin/env bash
# SubagentStop hook: collect evidence and append a change_manifest entry.
# Writes an entry only when there is a signal to record — either the agent emitted
# a change_manifest: marker on stdout, or git shows uncommitted files modified in
# the last 30 minutes. Silent otherwise (observability only — never blocks).
# Exit 0 always.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

# Write INPUT to a temp file so Python can read it without shell interpolation hazards.
TMP_INPUT=$(mktemp)
printf '%s' "$INPUT" > "$TMP_INPUT"
trap 'rm -f "$TMP_INPUT"' EXIT

# Extract session_id, agent_type, and tool_result.stdout via Python reading the temp file.
# Claude Code passes session_id in the stdin JSON payload, NOT as $CLAUDE_SESSION_ID env.
# read returns non-zero when python3 produces fewer fields than expected; || true is safe
# because all three vars are defaulted below.
read -r SESSION_FROM_INPUT AGENT_TYPE STDOUT_ENCODED < <(python3 - "$TMP_INPUT" <<'PYEOF'
import sys, json, base64

path = sys.argv[1]
try:
    with open(path) as f:
        d = json.load(f)
    session_id = d.get("session_id", "")
    agent_type = d.get("agent_type", "")
    stdout_raw = d.get("tool_result", {}).get("stdout", "")
    # Base64-encode stdout so it survives the shell read without newline splitting
    encoded = base64.b64encode(stdout_raw.encode()).decode()
    # Empty placeholders so the read picks up three positional fields even when missing
    print(session_id or "_", agent_type or "_", encoded or "_")
except Exception:
    print("_", "_", "_")
PYEOF
) || true
# Convert the "_" placeholder back to empty
[[ "$SESSION_FROM_INPUT" = "_" ]] && SESSION_FROM_INPUT=""
[[ "$AGENT_TYPE" = "_" ]] && AGENT_TYPE=""
[[ "$STDOUT_ENCODED" = "_" ]] && STDOUT_ENCODED=""

# Decode stdout_raw back from base64
STDOUT_RAW=$(python3 -c "import base64,sys; print(base64.b64decode(sys.argv[1]).decode('utf-8','replace'))" "$STDOUT_ENCODED" 2>/dev/null || true)

# Look for a change_manifest: marker line in stdout
MARKER_JSON=""
if [[ -n "$STDOUT_RAW" ]]; then
    MARKER_JSON=$(printf '%s' "$STDOUT_RAW" | grep -m1 '^change_manifest:' | sed 's/^change_manifest:[[:space:]]*//' || true)
fi

# Parse the marker JSON fields if present
MARKER_TYPE=""
MARKER_DESCRIPTION=""
MARKER_FILES=""
MARKER_FAILURE_PATTERN=""
MARKER_PREDICTED_FIXES=""
MARKER_RISK_TASKS=""
MARKER_CONSTRAINT_LEVEL=""
MARKER_WHY=""

if [[ -n "$MARKER_JSON" ]]; then
    # Write marker JSON to a temp file for safe Python parsing
    TMP_MARKER=$(mktemp)
    printf '%s' "$MARKER_JSON" > "$TMP_MARKER"
    trap 'rm -f "$TMP_INPUT" "$TMP_MARKER"' EXIT

    # eval of python3 output: || true prevents set -e from aborting if python3 exits non-zero
    eval "$(python3 - "$TMP_MARKER" <<'PYEOF'
import sys, json, shlex

path = sys.argv[1]
try:
    with open(path) as f:
        d = json.loads(f.read())
    for key, varname in [
        ("type",               "MARKER_TYPE"),
        ("description",        "MARKER_DESCRIPTION"),
        ("files",              "MARKER_FILES"),
        ("failure_pattern",    "MARKER_FAILURE_PATTERN"),
        ("predicted_fixes",    "MARKER_PREDICTED_FIXES"),
        ("risk_tasks",         "MARKER_RISK_TASKS"),
        ("constraint_level",   "MARKER_CONSTRAINT_LEVEL"),
        ("why_this_component", "MARKER_WHY"),
    ]:
        val = d.get(key, "")
        print(f'{varname}={shlex.quote(str(val))}')
except Exception:
    pass
PYEOF
    )" || true
fi

# Collect recently-modified uncommitted files from git (only if .git present)
GIT_FILES=""
if [[ -d ".git" ]]; then
    # First: any unstaged or staged changes
    GIT_FILES=$(git diff --name-only 2>/dev/null | head -20 | tr '\n' ',' | sed 's/,$//' || true)
    # Second: untracked or modified files from git status that were touched in the last 30 min
    if [[ -z "$GIT_FILES" ]]; then
        GIT_FILES=$(git status --short 2>/dev/null \
            | awk '{print $NF}' \
            | xargs -I{} find {} -maxdepth 0 -mmin -30 2>/dev/null \
            | tr '\n' ',' | sed 's/,$//' || true)
    fi
fi

# Decide whether there is a signal worth recording
HAS_MARKER=0
HAS_GIT_CHANGES=0
[[ -n "$MARKER_JSON" && -n "$MARKER_TYPE" && -n "$MARKER_DESCRIPTION" ]] && HAS_MARKER=1
[[ -n "$GIT_FILES" ]] && HAS_GIT_CHANGES=1

if [[ "$HAS_MARKER" = "0" && "$HAS_GIT_CHANGES" = "0" ]]; then
    exit 0
fi

# Resolve the append-manifest.sh path relative to this hook's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPEND_SCRIPT="${SCRIPT_DIR}/../skills/change-manifest/scripts/append-manifest.sh"

# Build args
ARGS=()

if [[ "$HAS_MARKER" = "1" ]]; then
    ARGS+=(--type "$MARKER_TYPE")
    ARGS+=(--description "$MARKER_DESCRIPTION")
    # Prefer marker files; fall back to git-detected files
    if [[ -n "$MARKER_FILES" ]]; then
        ARGS+=(--files "$MARKER_FILES")
    elif [[ -n "$GIT_FILES" ]]; then
        ARGS+=(--files "$GIT_FILES")
    fi
    [[ -n "$MARKER_FAILURE_PATTERN" ]]  && ARGS+=(--failure-pattern "$MARKER_FAILURE_PATTERN")
    [[ -n "$MARKER_PREDICTED_FIXES" ]]  && ARGS+=(--predicted-fixes "$MARKER_PREDICTED_FIXES")
    [[ -n "$MARKER_RISK_TASKS" ]]       && ARGS+=(--risk-tasks "$MARKER_RISK_TASKS")
    [[ -n "$MARKER_CONSTRAINT_LEVEL" ]] && ARGS+=(--constraint-level "$MARKER_CONSTRAINT_LEVEL")
    [[ -n "$MARKER_WHY" ]]              && ARGS+=(--why-this-component "$MARKER_WHY")
else
    # Git-only signal: record a minimal entry noting which files changed
    ARGS+=(--type "git-change")
    ARGS+=(--description "uncommitted changes detected at subagent stop")
    ARGS+=(--files "$GIT_FILES")
fi

# Export agent_type for the append script's envelope
export CLAUDE_AGENT_TYPE="${AGENT_TYPE:-unknown}"

# Resolve session_id: stdin JSON (canonical per Claude Code hook spec) → env fallback → "unknown".
SESSION_ID="${SESSION_FROM_INPUT:-${CLAUDE_SESSION_ID:-unknown}}"
ARGS+=(--session-id "$SESSION_ID")

# --- Dedup guard: skip the append if this (session_id, git-tree-hash) was already written ---
# Prevents a planner→generator→reviewer chain with one logical change from recording 3 entries.
STATE_FILE=".claude/state/manifest-writer-${SESSION_ID}"

# Compute a tree-hash representing the current working-tree delta vs HEAD.
# Same delta within the same session → same hash → skip.
TREE_HASH=""
if [[ -d ".git" ]]; then
    TREE_HASH=$(git diff HEAD 2>/dev/null | sha256sum 2>/dev/null | cut -c1-12 || true)
fi
# Non-git fallback: hash the GIT_FILES string (captures the file-set signal).
if [[ -z "$TREE_HASH" && -n "$GIT_FILES" ]]; then
    TREE_HASH=$(printf '%s' "$GIT_FILES" | sha256sum 2>/dev/null | cut -c1-12 || true)
fi
# If both fail: TREE_HASH stays empty — dedup is skipped and the entry is always written.

PREV_HASH=""
if [[ -f "$STATE_FILE" ]]; then
    PREV_HASH=$(cat "$STATE_FILE" 2>/dev/null || true)
fi

# FORGE_REMINDER_FORCE=1 bypasses dedup (always write and always update state).
if [[ "${FORGE_REMINDER_FORCE:-0}" != "1" && -n "$TREE_HASH" && "$TREE_HASH" = "$PREV_HASH" ]]; then
    # Same tree-hash as last write in this session: duplicate, skip silently.
    exit 0
fi

bash "$APPEND_SCRIPT" "${ARGS[@]}" 2>/dev/null || true

# Update state file with the current tree-hash so subsequent calls can compare.
if [[ -n "$TREE_HASH" ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '%s' "$TREE_HASH" > "$STATE_FILE"
fi

exit 0
