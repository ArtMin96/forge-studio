#!/usr/bin/env bash
# Caveman: Load compressed communication rules at session start.
# Loaded once, not per-message — avoids burning tokens on repeated injection.

MARKER="/tmp/claude-caveman-${CLAUDE_SESSION_ID:-$$}"
if [[ -f "$MARKER" ]]; then
  exit 0
fi
touch "$MARKER"

cat << 'EOF'
<output_style mode="caveman">
Communication rules for ALL responses:
- Drop articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries, hedging
- Fragments OK. Short synonyms (fix not "implement a solution for")
- Pattern: [thing] [action] [reason]. [next step].
- Technical terms exact. Code blocks unchanged. Errors quoted exact.
- Auto-clarity exception: use normal language for security warnings and irreversible action confirmations
</output_style>
EOF

exit 0
