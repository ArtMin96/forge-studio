#!/usr/bin/env bash
# score.sh — lexical reasoning-tilt analysis for JSONL trace files.
# Scans "command" and "output_preview" fields (bash events) — the primary
# free-text content available in forge-studio traces; no raw reasoning field exists.
#
# Usage: bash scripts/score.sh [path-to-trace.jsonl]
# Without an argument, uses the most recent file in ~/.claude/traces/.

TRACE_FILE="${1:-}"

if [[ -z "$TRACE_FILE" ]]; then
  TRACE_FILE=$(stat -c '%Y %n' "$HOME/.claude/traces"/*.jsonl 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [[ -z "$TRACE_FILE" || ! -f "$TRACE_FILE" ]]; then
  echo "No trace files found." >&2
  exit 0
fi

VOCAB="$(dirname "$0")/vocab.tsv"

python3 - "$TRACE_FILE" "$VOCAB" <<'PYEOF'
import sys
import json
import re

trace_path = sys.argv[1]
vocab_path = sys.argv[2]

# Load vocabulary
forward_tokens = []
history_tokens = []
with open(vocab_path) as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('\t', 1)
        if len(parts) != 2:
            continue
        cls, token = parts[0].strip(), parts[1].strip()
        if cls == 'forward':
            forward_tokens.append(token)
        elif cls == 'history':
            history_tokens.append(token)

def count_matches(text, tokens):
    total = 0
    for tok in tokens:
        # whole-word, case-insensitive match; handle multi-word phrases too
        pattern = r'(?<!\w)' + re.escape(tok) + r'(?!\w)' if ' ' not in tok \
                  else re.escape(tok)
        total += len(re.findall(pattern, text, re.IGNORECASE))
    return total

forward_total = 0
history_total = 0

with open(trace_path) as fh:
    for raw in fh:
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if entry.get('type') != 'bash':
            continue
        text = ' '.join(filter(None, [
            entry.get('command', ''),
            entry.get('output_preview', ''),
        ]))
        forward_total += count_matches(text, forward_tokens)
        history_total += count_matches(text, history_tokens)

total = forward_total + history_total
session = trace_path

print(f"Trace: {session}")
print(f"Forward tokens: {forward_total}")
print(f"History tokens: {history_total}")

if total == 0:
    print("Forward ratio: n/a (insufficient signal)")
else:
    ratio = forward_total / total
    print(f"Forward ratio: {forward_total}/{total} = {ratio:.2f}")
    if ratio >= 0.60:
        tilt = "tilt:forward"
    elif ratio >= 0.40:
        tilt = "tilt:balanced"
    else:
        tilt = "tilt:history  [cursed-regime: paper threshold ≈ 0.340, flag at < 0.40]"
    print(tilt)
PYEOF
