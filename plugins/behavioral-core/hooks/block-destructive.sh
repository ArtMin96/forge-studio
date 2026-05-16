#!/usr/bin/env bash
set -euo pipefail
# Behavioral Core: Block destructive commands.
# Uses JSON permissionDecision output (exit 0) for blocking.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

deny_command() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Layer 5 (runs first): safe-mode flag denies all mutations until cleared.
# Set by context-engine/consecutive-failure-guard.sh at FORGE_SAFE_MODE_THRESHOLD.
# Cleared by /safe-mode off.
if [ -f .claude/safe-mode ]; then
  REASON=$(jq -r '.reason // "unspecified"' .claude/safe-mode 2>/dev/null)
  COUNTER=$(jq -r '.counter // "?"' .claude/safe-mode 2>/dev/null)
  deny_command "safe-mode active (reason: ${REASON}, failures: ${COUNTER}). Diagnose root cause, then run /safe-mode off. Until then all mutations are blocked."
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Layer 1a: rm -rf — deny system paths, allow temp dirs (common test cleanup pattern).
# Strip quotes for path detection so 'rm -rf "/etc/x"' is caught. Scan ALL occurrences
# (compound `rm -rf /tmp/a; rm -rf /etc/b` must catch the second). Handle `--` separator.
RM_SCAN=$(echo "$COMMAND" | tr -d "\"'" | grep -oE 'rm[[:space:]]+-rf([[:space:]]+--)?[[:space:]]+[~/][^[:space:];|&]*' || true)
if [ -n "$RM_SCAN" ]; then
  while IFS= read -r MATCH; do
    if [ -z "$MATCH" ]; then continue; fi
    RM_TARGET=$(echo "$MATCH" | grep -oE '[~/][^[:space:];|&]*$')
    case "$RM_TARGET" in
      /tmp/*|/tmp|/var/tmp/*|/var/tmp|/private/tmp/*|/private/var/tmp/*) ;;
      *) deny_command "Destructive command detected: '${MATCH}'. Ask the user to run it manually if genuinely needed." ;;
    esac
  done <<< "$RM_SCAN"
fi

# Layer 1b: Privilege escalation, device overwrite, filesystem destructors, fork-bomb, secure-erase.
# sudo elevation and chmod world-writable can silently widen attack surface; dd/mkfs destroy
# partition data; the fork-bomb exhausts PIDs; shred overwrites inodes unrecoverably.
# Evaluated before package-removal / git-history patterns so sudo-prefixed compound commands
# (e.g. sudo apt remove) credit the privilege class, not the inner verb.
if echo "$COMMAND" | grep -qEi '(sudo[[:space:]]|chmod[[:space:]]+-[a-zA-Z]*R[a-zA-Z]*[[:space:]]+(777|a\+rwx)|dd[[:space:]]+[^|;&]*of=/dev/|mkfs\.[a-z0-9]+|:\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:|shred[[:space:]])'; then
  MATCHED=$(echo "$COMMAND" | grep -oEi '(sudo[[:space:]]|chmod[[:space:]]+-[a-zA-Z]*R[a-zA-Z]*[[:space:]]+(777|a\+rwx)|dd[[:space:]]+[^|;&]*of=/dev/|mkfs\.[a-z0-9]+|:\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:|shred[[:space:]])' | head -1)
  deny_command "Destructive command detected: '${MATCHED}'. Ask the user to run it manually if genuinely needed."
fi

# Layer 1c: Package removal, history-destructive git, deferred-destructive find, and other verbs.
if echo "$COMMAND" | grep -qEi '(git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D|git[[:space:]]+reflog[[:space:]]+expire[[:space:]]+[^|;&]*--expire=now|git[[:space:]]+gc[[:space:]]+[^|;&]*--prune=now|find[[:space:]]+[^|;&]*-exec[[:space:]]+rm\b|find[[:space:]]+[^|;&]*-delete\b|(apt|apt-get)[[:space:]]+(remove|purge)\b|pip[[:space:]]+uninstall[[:space:]]+-y\b|npm[[:space:]]+uninstall[[:space:]]+-g\b)'; then
  MATCHED=$(echo "$COMMAND" | grep -oEi '(git\s+push\s+--force|git\s+push\s+-f\b|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+|git\s+checkout\s+\.\s*$|git\s+clean\s+-f|git\s+branch\s+-D|git[[:space:]]+reflog[[:space:]]+expire[[:space:]]+[^|;&]*--expire=now|git[[:space:]]+gc[[:space:]]+[^|;&]*--prune=now|find[[:space:]]+[^|;&]*-exec[[:space:]]+rm\b|find[[:space:]]+[^|;&]*-delete\b|(apt|apt-get)[[:space:]]+(remove|purge)\b|pip[[:space:]]+uninstall[[:space:]]+-y\b|npm[[:space:]]+uninstall[[:space:]]+-g\b)' | head -1)
  deny_command "Destructive command detected: '${MATCHED}'. Ask the user to run it manually if genuinely needed."
fi

# Layer 1d: Stdout/append redirect to system-owned paths.
# Allow legitimate redirects under /home and /tmp; only /etc /usr /boot /dev/sd* are deny-listed
# because those paths are root-owned and a stray truncation is unrecoverable without backups.
if echo "$COMMAND" | grep -qE '>>?[[:space:]]*/etc[/[:space:]]|>>?[[:space:]]*/usr[/[:space:]]|>>?[[:space:]]*/boot[/[:space:]]|>>?[[:space:]]*/dev/sd[a-z]|>>?[[:space:]]*/dev/nvme'; then
  MATCHED=$(echo "$COMMAND" | grep -oE '>>?[[:space:]]*/[^[:space:]]+' | head -1)
  deny_command "Truncating redirect to system path detected: '${MATCHED}'. Ask the user to run it manually if genuinely needed."
fi

# Layer 2: Shell wrapper obfuscation (bash -c '...', sh -c "...")
if echo "$COMMAND" | grep -qE '(bash|sh|zsh)\s+-c\s'; then
  # Each grep attempt may return non-zero (no match); || true prevents -e abort
  INNER=$(echo "$COMMAND" | grep -oP "(?<=-c\s')[^']*" 2>/dev/null || echo "$COMMAND" | grep -oP '(?<=-c\s")[^"]*' 2>/dev/null || echo "$COMMAND" | grep -oP '(?<=-c\s)\S+' 2>/dev/null || true)
  if [ -n "$INNER" ]; then
    if echo "$INNER" | grep -qEi '(rm\s+-r|git\s+push.*(-f|--force)|git\s+reset\s+--hard|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE|git\s+clean|git\s+branch\s+-D|sudo[[:space:]]|chmod[[:space:]]+-[a-zA-Z]*R[a-zA-Z]*[[:space:]]+(777|a\+rwx)|dd[[:space:]]+[^|;&]*of=/dev/|mkfs\.|:\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:|shred[[:space:]]|>>?[[:space:]]*/etc[/[:space:]]|>>?[[:space:]]*/usr[/[:space:]]|>>?[[:space:]]*/boot[/[:space:]]|>>?[[:space:]]*/dev/sd[a-z]|>>?[[:space:]]*/dev/nvme|git[[:space:]]+reflog[[:space:]]+expire|git[[:space:]]+gc[[:space:]]+[^|;&]*--prune=now|find[[:space:]]+[^|;&]*(-exec[[:space:]]+rm|-delete)|(apt|apt-get)[[:space:]]+(remove|purge)|pip[[:space:]]+uninstall[[:space:]]+-y|npm[[:space:]]+uninstall[[:space:]]+-g)'; then
      deny_command "Destructive command hidden in shell wrapper. Ask the user to run it manually if genuinely needed."
    fi
  fi
fi

# Layer 3a: Network-to-shell — curl/wget piped into shell is the classic remote-code-execution pattern.
if echo "$COMMAND" | grep -qE '(curl|wget|fetch)([[:space:]][^|]*)?\|[[:space:]]*(bash|sh|zsh)\b'; then
  deny_command "Network-to-shell pipe detected (curl|wget|fetch → shell). Executes remote untrusted code. Ask the user to run it manually if genuinely needed."
fi

# Layer 3b: Pipe to bare shell with no script argument — equivalent to executing stdin as code.
# Allows: `cat input | bash known-script.sh`. Denies: `cat input | bash`, `... | bash;`, `... | bash &`.
if echo "$COMMAND" | grep -qE '\|[[:space:]]*(bash|sh|zsh)([[:space:]]*$|[[:space:]]*[;&|]|[[:space:]]+-c[[:space:]])'; then
  deny_command "Pipe to bare shell detected (no script argument). Executes piped data as code. Ask the user to run it manually if genuinely needed."
fi

# Layer 4: Flag reordering (rm -r -f /, rm -f -r /)
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-z]*r[a-z]*\s+-[a-z]*f|-[a-z]*f[a-z]*\s+-[a-z]*r)\s+[/~]'; then
  deny_command "Recursive forced deletion detected (reordered flags). Ask the user to run it manually if genuinely needed."
fi

exit 0
