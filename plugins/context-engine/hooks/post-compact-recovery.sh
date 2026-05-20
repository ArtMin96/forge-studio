#!/usr/bin/env bash
# Context Engine: Post-compaction structured briefing re-injection.
# Reads the YAML produced by forward-briefing.sh and re-emits it as
# a compact, machine-readable Markdown summary so the first turn after
# compaction starts from concrete state (file paths, sha256s, pending
# verifications) rather than prose narration.
# arXiv:2605.18747 §3.2.6: the post-compact turn needs exact data, not vibes.
# Exit 0 always.

SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/state"
BRIEFING="${STATE_DIR}/forward-briefing-${SESSION_ID}.yaml"

# Nothing to recover if no briefing was written.
if [ ! -f "$BRIEFING" ]; then
  exit 0
fi

python3 /dev/stdin "$BRIEFING" << 'PYEOF'
import sys, os

briefing_path = sys.argv[1]

try:
    import yaml
    with open(briefing_path, errors='replace') as f:
        d = yaml.safe_load(f) or {}
except ImportError:
    # yaml not available — emit raw YAML content as a code block.
    print('```yaml')
    print(open(briefing_path, errors='replace').read())
    print('```')
    sys.exit(0)
except Exception as e:
    sys.stderr.write('[post-compact-recovery] parse error: ' + str(e) + '\n')
    sys.exit(0)

lines = []
lines.append('[Post-Compaction Recovery]')
lines.append('')
lines.append('**Structured briefing restored from pre-compact snapshot.**')
lines.append('')

# Recent edits
edits = d.get('recent_edits') or []
if edits:
    lines.append('**Recent edits** (re-read these before touching them):')
    for e in edits:
        lines.append('- `' + str(e) + '`')
    lines.append('')

# Pending verifications
pending = d.get('pending_verifications') or []
if pending:
    lines.append('**Pending verifications** (run before claiming done):')
    for cmd in pending:
        lines.append('- `' + str(cmd) + '`')
    lines.append('')

# Open failures
failures = d.get('open_failures') or []
if failures:
    lines.append('**Open failures** (last known):')
    for fa in failures:
        if not isinstance(fa, dict):
            continue
        lines.append('- test: `' + str(fa.get('test', '?')) + '`')
        st = str(fa.get('stack_top', '')).strip()
        if st:
            lines.append('  stack: ' + st)
        lp = fa.get('log_path', '')
        if lp:
            lines.append('  log: `' + str(lp) + '`')
    lines.append('')

# Belief snapshots
snaps = d.get('belief_snapshots') or []
if snaps:
    lines.append('**Belief snapshots** (sha256 at compaction time):')
    for s in snaps:
        if not isinstance(s, dict):
            continue
        lines.append('- `' + str(s.get('path', '?')) + '` → ' + str(s.get('sha256', '?'))[:16] + '…')
    lines.append('')

ts = d.get('ts', '')
if ts:
    lines.append('_Briefing captured: ' + str(ts) + '_')
lines.append('[/Post-Compaction Recovery]')

print('\n'.join(lines))
PYEOF

exit 0
