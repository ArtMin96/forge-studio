#!/usr/bin/env bash
# Context Engine: Structured pre-compaction briefing with provenance.
# Emits a YAML document capturing open failures, recent edits, pending
# verifications, and belief snapshots so the post-compact turn starts
# from concrete state rather than prose summaries.
# arXiv:2605.18747 §3.2.6: stack frames and suspect files survive structured
# handoffs; bare prose silently drops the highest-signal items.
# Exit 0 always — PreCompact hooks cannot block compaction.

SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$(pwd)/.claude}/state"
BELIEF_LOG="${STATE_DIR}/belief.jsonl"
OUTPUT_FILE="${STATE_DIR}/forward-briefing-${SESSION_ID}.yaml"

# Resolve change_manifest path.
MANIFEST=""
for candidate in \
  "$(pwd)/.claude/evolution/change_manifest.jsonl" \
  "${HOME}/.claude/evolution/change_manifest.jsonl"; do
  [ -f "$candidate" ] && MANIFEST="$candidate" && break
done

mkdir -p "$STATE_DIR"

python3 /dev/stdin "$SESSION_ID" "$BELIEF_LOG" "${MANIFEST:-}" "$OUTPUT_FILE" << 'PYEOF'
import sys, json, os, glob, datetime

session_id = sys.argv[1]
belief_log = sys.argv[2]
manifest_path = sys.argv[3]   # may be empty string
output_file = sys.argv[4]

ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# ── YAML scalar quoting ───────────────────────────────────────────────────────

def q(s):
    """Quote any string as a valid double-quoted YAML scalar."""
    s = str(s)
    s = s.replace('\\', '\\\\').replace('"', '\\"')
    s = s.replace('\n', ' ').replace('\r', '').replace('\t', ' ')
    return '"' + s + '"'

# ── open_failures ─────────────────────────────────────────────────────────────
def get_open_failures():
    trace_dir = os.path.expanduser('~/.claude/traces')
    failures = []
    try:
        files = sorted(glob.glob(os.path.join(trace_dir, '*.jsonl')), reverse=True)
        for f in files[:3]:
            try:
                for line in open(f, errors='replace'):
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        e = json.loads(line)
                        if e.get('exit_code', 0) not in (0, None) and e.get('type') in ('bash', 'tool'):
                            cmd = e.get('command', e.get('tool_name', 'unknown'))
                            failures.append({
                                'test': str(cmd)[:80],
                                'stack_top': str(e.get('output_preview', ''))[:120],
                                'log_path': f,
                            })
                            if len(failures) >= 5:
                                break
                    except Exception:
                        pass
            except Exception:
                pass
            if len(failures) >= 5:
                break
    except Exception:
        pass
    return failures

# ── recent_edits ──────────────────────────────────────────────────────────────
def get_recent_edits():
    if not os.path.isfile(belief_log):
        return []
    seen = {}
    try:
        for line in open(belief_log, errors='replace'):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
                p = e.get('path', '')
                if p:
                    seen[p] = True
            except Exception:
                pass
    except Exception:
        pass
    return list(seen.keys())[-10:]

# ── pending_verifications ─────────────────────────────────────────────────────
def get_pending_verifications():
    if not manifest_path or not os.path.isfile(manifest_path):
        return []
    pending = []
    try:
        lines = [l.strip() for l in open(manifest_path, errors='replace') if l.strip()]
        for line in lines[-5:]:
            try:
                e = json.loads(line)
                eb = e.get('evidence_bundle') or {}
                cr = eb.get('checks_run') if isinstance(eb, dict) else None
                if not cr:
                    for cmd in (e.get('verifier_obligations') or []):
                        if cmd:
                            pending.append(str(cmd))
            except Exception:
                pass
    except Exception:
        pass
    return pending

# ── belief_snapshots ──────────────────────────────────────────────────────────
def get_belief_snapshots():
    if not os.path.isfile(belief_log):
        return []
    shas = {}
    try:
        for line in open(belief_log, errors='replace'):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
                p = e.get('path', '')
                s = e.get('sha256', '')
                if p and s:
                    shas[p] = s
            except Exception:
                pass
    except Exception:
        pass
    return list(shas.items())[-10:]

# ── assemble YAML ─────────────────────────────────────────────────────────────
failures = get_open_failures()
edits = get_recent_edits()
pending = get_pending_verifications()
snapshots = get_belief_snapshots()

lines = []
lines.append('ts: ' + q(ts))
lines.append('session_id: ' + q(session_id))

if not failures:
    lines.append('open_failures: []')
else:
    lines.append('open_failures:')
    for fa in failures:
        lines.append('  - test: ' + q(fa['test']))
        lines.append('    stack_top: ' + q(fa['stack_top']))
        lines.append('    suspect_files: []')
        lines.append('    log_path: ' + q(fa['log_path']))

if not edits:
    lines.append('recent_edits: []')
else:
    lines.append('recent_edits:')
    for e in edits:
        lines.append('  - ' + q(e))

if not pending:
    lines.append('pending_verifications: []')
else:
    lines.append('pending_verifications:')
    for cmd in pending:
        lines.append('  - ' + q(cmd))

if not snapshots:
    lines.append('belief_snapshots: []')
else:
    lines.append('belief_snapshots:')
    for p, s in snapshots:
        lines.append('  - path: ' + q(p))
        lines.append('    sha256: ' + s)

yaml_content = '\n'.join(lines) + '\n'

try:
    with open(output_file, 'w') as f:
        f.write(yaml_content)
    # Emit the YAML to stdout so PreCompact can surface it to the model.
    sys.stdout.write(yaml_content)
except Exception as e:
    sys.stderr.write('[forward-briefing] write error: ' + str(e) + '\n')
PYEOF

# Status note to stderr so YAML stdout stays clean when redirected.
printf '[pre-compact] structured briefing written: %s\n' "$OUTPUT_FILE" >&2
exit 0
