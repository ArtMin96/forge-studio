#!/usr/bin/env bash
# PreToolUse:Bash — block wrong-branch, detached-HEAD, and bare-force git pushes.
# Deny contract is identical to policy-gateway: emit JSON body, exit 0.
# A non-zero exit would surface as a hook error rather than a policy block.

set -euo pipefail

INPUT=$(cat 2>/dev/null || true)

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || true

# Normalize whitespace (tabs, newlines, repeated spaces) to single spaces so that
# `git\tpush`, `git  push`, and `git\npush` are all detected like `git push` —
# the raw shell happily runs every variant, so the guard must too.
NORMALIZED=$(printf '%s' "$COMMAND" | tr -s '[:space:]' ' ')
NORMALIZED="${NORMALIZED# }"; NORMALIZED="${NORMALIZED% }"

# Cheap reject: no 'git push' substring anywhere → cannot be a push.
case "$NORMALIZED" in
  *"git push"*) : ;;
  *) exit 0 ;;
esac

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# A push combined with shell operators can hide a second, wrong-branch push that
# single-command parsing would miss; fail closed and ask for a standalone push.
case "$NORMALIZED" in
  *"&&"* | *"||"* | *";"* | *"|"* | *"("* | *'`'* | *'$('*)
    deny "stack-flow: a git push combined with shell operators (&&, ||, ;, |, subshell) is not evaluated for safety. Run the push as a standalone command, or use /stack-submit or /stack-restack." ;;
esac

# Require the command itself to be a push, not a quoted mention in some other
# command's arguments (e.g. a commit message). Strip leading VAR=val env
# assignments, then the command must start with 'git push'.
REST="$NORMALIZED"
while [[ "$REST" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
  if [[ "$REST" == *" "* ]]; then REST="${REST#* }"; else REST=""; break; fi
done
case "$REST" in
  "git push" | "git push "*) : ;;
  *) exit 0 ;;
esac

# Detached-HEAD check: git symbolic-ref -q HEAD exits non-zero when HEAD is detached.
# Under set -euo pipefail a non-zero sub-command would abort the script, so we
# capture its exit code explicitly.
CURRENT_BRANCH=""
if git symbolic-ref -q HEAD >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || true
else
  # Not in a git repo or HEAD is detached — two distinct cases.
  if git rev-parse --git-dir >/dev/null 2>&1; then
    # We are in a repo but HEAD is detached: deny.
    deny "stack-flow: HEAD is detached. Check out a branch before pushing. Use /stack-status to see the stack."
  else
    # Not in a git repo at all: this cannot be a stack push; pass through.
    exit 0
  fi
fi

# ----- Flag parsing -----
# Build an argument list from the command string that strips flags so we can
# find the positional remote and branch arguments.  We need to identify:
#   --force / -f         → deny (bare force, not safe)
#   --force-with-lease   → safe, do not deny
#   --force-if-includes  → safe, do not deny
#   -u / --set-upstream  → consume no extra arg (just a flag)
#   --                   → end of options
#
# Strategy: walk the space-split tokens, track flags, collect positional args.

BARE_FORCE=0
DESTRUCTIVE=""
POSITIONAL=()

# Split the command into tokens.  We rely on word-splitting the command string.
# Branch names and remote names cannot contain spaces (git enforces this), so
# this is safe for all real git invocations.
read -ra TOKENS <<< "$REST"

SKIP_NEXT=0
for TOKEN in "${TOKENS[@]}"; do
  if [[ $SKIP_NEXT -eq 1 ]]; then
    SKIP_NEXT=0
    continue
  fi

  case "$TOKEN" in
    git)               continue ;;
    push)              continue ;;
    # Bare force flags: -f and --force but NOT --force-with-lease or --force-if-includes.
    # Use exact match so --force-with-lease does not trip the bare-force check.
    -f | --force)      BARE_FORCE=1 ;;
    # Whole-remote / multi-ref / deletion flags update or drop refs beyond the
    # current branch and can break the stack tree, so they are blocked outright.
    --mirror | --all | --delete | -d) DESTRUCTIVE="$TOKEN" ;;
    --force-with-lease | --force-if-includes) : ;;  # safe — ignore
    # --force-with-lease=... (pinned-SHA form)
    --force-with-lease=*) : ;;
    # Flags that consume the next token (e.g. --receive-pack, --repo, --push-option).
    --receive-pack=* | --repo=* | --push-option=*) : ;;
    --receive-pack | --repo | --push-option) SKIP_NEXT=1 ;;
    # -u and --set-upstream: flag only, no extra positional arg consumed.
    -u | --set-upstream) : ;;
    # Other single-char flags that may be bundled (e.g. -n, -v, -q) — ignore.
    -*)                : ;;
    # Positional: remote or refspec.
    *)                 POSITIONAL+=("$TOKEN") ;;
  esac
done

# Deny whole-remote / multi-ref / deletion pushes before anything else — these
# act beyond the current branch and can wipe or force-update the whole stack.
if [[ -n "$DESTRUCTIVE" ]]; then
  deny "stack-flow: '${DESTRUCTIVE}' force-updates or deletes remote refs beyond the current branch and can break the stack tree. Push one branch at a time with /stack-submit or /stack-restack."
fi

# Deny bare --force / -f before the branch check.  Point Claude at the safe skills.
if [[ $BARE_FORCE -eq 1 ]]; then
  deny "stack-flow: bare --force / -f is blocked. Use /stack-submit or /stack-restack, which issue a safe force-push (--force-with-lease --force-if-includes) instead."
fi

# ----- Branch target check -----
# POSITIONAL[0] = remote (if present), POSITIONAL[1] = refspec (if present).
# Supported refspec forms:
#   <branch>           → pushes current HEAD to <branch> on the remote
#   HEAD:<branch>      → explicit rename-push; <branch> is the destination
#   <local>:<remote>   → general refspec; <remote> is the destination name
#
# No explicit refspec (0 or 1 positional) means "push current branch to its
# tracking remote" — that is always the current branch; pass through.

TARGET_BRANCH=""

if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
  REFSPEC="${POSITIONAL[1]}"
  # Strip a leading '+' (force indicator in refspec).
  REFSPEC="${REFSPEC#+}"

  # An empty source side (':<branch>') deletes <branch> on the remote — another
  # branch in the stack may depend on it, so block this like an explicit --delete.
  if [[ "$REFSPEC" == :* ]]; then
    deny "stack-flow: deleting a remote branch via a ':<branch>' refspec is blocked — it can drop a branch the rest of the stack depends on. Restructure the stack with /stack-reparent, or delete the branch deliberately outside the stack."
  fi

  if [[ "$REFSPEC" == *:* ]]; then
    # <local>:<remote> or HEAD:<remote> — extract the right-hand (destination) side.
    TARGET_BRANCH="${REFSPEC##*:}"
  else
    TARGET_BRANCH="$REFSPEC"
  fi

  # 'HEAD' resolves to the current branch, so 'git push origin HEAD' (and
  # 'HEAD:HEAD') targets the current branch — compare against it, not the literal.
  if [[ "$TARGET_BRANCH" == "HEAD" ]]; then
    TARGET_BRANCH="$CURRENT_BRANCH"
  fi
fi

if [[ -n "$TARGET_BRANCH" && "$TARGET_BRANCH" != "$CURRENT_BRANCH" ]]; then
  deny "stack-flow: push target branch '${TARGET_BRANCH}' does not match the current branch '${CURRENT_BRANCH}'. Check out '${TARGET_BRANCH}' before pushing, or use /stack-submit to push the current stack branch correctly."
fi

exit 0
