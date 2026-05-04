#!/usr/bin/env python3
"""Join SEPL proposal predictions against trace observations. Read-only."""
import json
import os
import re
import sys
from glob import glob
from pathlib import Path


PRED_HEADER = re.compile(r'^##\s+Predicted Impact \(structured\)', re.M)
TOKEN_DELTA_RE = re.compile(r'predicted_token_delta_per_session:\s*([+\-]?\d+)', re.I)
CLUSTERS_RE = re.compile(r'predicted_failure_clusters_resolved:\s*(.+)', re.I)
NEG_RE = re.compile(r'predicted_negative_effects:\s*(.+)', re.I)


def parse_proposal(path):
    text = Path(path).read_text(errors='ignore')
    m = PRED_HEADER.search(text)
    if not m:
        return None
    section = text[m.end():]
    next_h2 = re.search(r'^##\s+', section, re.M)
    if next_h2:
        section = section[:next_h2.start()]
    delta = TOKEN_DELTA_RE.search(section)
    clusters = CLUSTERS_RE.search(section)
    negs = NEG_RE.search(section)
    slug = None
    res_match = re.search(r'^-\s*slug:\s*`?([^\s`]+)`?', text, re.M)
    if res_match:
        slug = res_match.group(1)
    return {
        'path': path,
        'slug': slug,
        'predicted_token_delta_per_session': int(delta.group(1)) if delta else None,
        'predicted_failure_clusters_resolved': (clusters.group(1).strip() if clusters else None),
        'predicted_negative_effects': (negs.group(1).strip() if negs else None),
    }


def committed_slugs(ledger_path):
    slugs = {}
    if not os.path.exists(ledger_path):
        return slugs
    for line in open(ledger_path):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get('operator') == 'commit':
            slugs.setdefault(entry.get('resource'), []).append(entry)
    return slugs


def observed_delta_chars(traces_dir, since_ts):
    if not os.path.isdir(traces_dir):
        return 0, 0
    files = sorted(glob(os.path.join(traces_dir, '*.jsonl')))
    msg_count = 0
    char_count = 0
    for f in files:
        for line in open(f, errors='ignore'):
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = e.get('timestamp', '')
            if since_ts and ts < since_ts:
                continue
            msg_count += 1
            char_count += len(line)
    return msg_count, char_count


def _haystack(entry):
    t = entry.get('type')
    if t == 'file':
        return entry.get('file_path') or ''
    if t == 'bash':
        return (entry.get('command') or '') + ' ' + (entry.get('output_preview') or '')
    return ''


def observed_delta_for_resource(traces_dir, commit_ts, slug):
    """Per-resource pre/post bytes-per-session delta.

    Counts trace entries whose haystack (file_path for file events, command +
    output_preview for bash) contains the slug or its basename. Splits on
    commit_ts and normalizes by distinct trace files (≈ sessions). Returns
    (delta_bytes_per_session, sessions_pre, sessions_post)."""
    if not os.path.isdir(traces_dir) or not slug:
        return 0, 0, 0
    files = sorted(glob(os.path.join(traces_dir, '*.jsonl')))
    slug_basename = os.path.basename(slug)
    pre_bytes = post_bytes = 0
    pre_sessions = set()
    post_sessions = set()
    for f in files:
        for line in open(f, errors='ignore'):
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            haystack = _haystack(e)
            if not haystack:
                continue
            if slug not in haystack and (not slug_basename or slug_basename not in haystack):
                continue
            ts = e.get('timestamp', '')
            if commit_ts and ts < commit_ts:
                pre_bytes += len(line)
                pre_sessions.add(f)
            else:
                post_bytes += len(line)
                post_sessions.add(f)
    pre_per = pre_bytes / max(len(pre_sessions), 1)
    post_per = post_bytes / max(len(post_sessions), 1)
    return int(post_per - pre_per), len(pre_sessions), len(post_sessions)


def render_report(rows, skipped, calibration):
    out = ['## Prediction Audit', '']
    out.append(f'Committed proposals scanned: {len(rows) + skipped}')
    out.append(f'Proposals with structured prediction: {len(rows)}')
    out.append('')
    out.append('### Per-resource prediction error')
    out.append('')
    if rows:
        out.append('| Resource | Predicted Δtokens/session | Observed Δbytes/session (post − pre) | Pre/Post sessions | Verdict |')
        out.append('|---|---|---|---|---|')
        for r in rows:
            out.append(
                f"| {r['slug']} | {r['predicted_token_delta_per_session']:+d} | "
                f"{r['observed_chars']:+d} | {r['pre_sessions']}/{r['post_sessions']} | {r['verdict']} |"
            )
    else:
        out.append('_No structured-prediction rows yet — populate `## Predicted Impact (structured)` in proposals._')
    out.append('')
    out.append('### Calibration summary')
    out.append(f"Mean signed error: {calibration.get('mean_signed', 'n/a')}")
    out.append(f"Mean absolute error: {calibration.get('mean_abs', 'n/a')}")
    out.append(f'Proposals with no structured prediction (skipped): {skipped}')
    return '\n'.join(out) + '\n'


def self_test():
    fixture_proposal = '''# Test proposal
## Resource
- slug: `rules.d/test.txt`
## Predicted Impact (structured)
predicted_token_delta_per_session: 100
predicted_failure_clusters_resolved: none
predicted_negative_effects: none
'''
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
        f.write(fixture_proposal)
        fixture_path = f.name
    try:
        parsed = parse_proposal(fixture_path)
        assert parsed is not None, 'fixture should parse'
        assert parsed['slug'] == 'rules.d/test.txt', f"slug={parsed['slug']!r}"
        assert parsed['predicted_token_delta_per_session'] == 100, parsed
        assert parsed['predicted_failure_clusters_resolved'] == 'none'
        assert parsed['predicted_negative_effects'] == 'none'
        print('SELF-TEST PASS: fixture parsed with all fields')
        return 0
    except AssertionError as exc:
        print(f'SELF-TEST FAIL: {exc}')
        return 1
    finally:
        os.unlink(fixture_path)


def main():
    if '--self-test' in sys.argv:
        sys.exit(self_test())
    proposals_dir = '.claude/lineage/proposals'
    ledger_path = '.claude/lineage/ledger.jsonl'
    traces_dir = os.environ.get('FORGE_TRACES_DIR') or os.path.expanduser('~/.claude/traces')
    if not os.path.isdir(proposals_dir):
        print(f'No proposals dir at {proposals_dir} — nothing to audit.')
        return 0
    committed = committed_slugs(ledger_path)
    rows = []
    skipped = 0
    for path in sorted(glob(os.path.join(proposals_dir, '*.md'))):
        parsed = parse_proposal(path)
        if not parsed or parsed['predicted_token_delta_per_session'] is None:
            skipped += 1
            continue
        slug = parsed['slug']
        if slug not in committed:
            skipped += 1
            continue
        commit_entries = committed[slug]
        commit_ts = min(e.get('ts', '') for e in commit_entries)
        predicted = parsed['predicted_token_delta_per_session']
        observed_delta, pre_sessions, post_sessions = observed_delta_for_resource(
            traces_dir, commit_ts, slug)
        if post_sessions == 0:
            verdict = 'insufficient-data'
        elif abs(predicted - observed_delta) <= max(50, abs(predicted) // 4):
            verdict = 'accurate'
        elif abs(predicted) > abs(observed_delta):
            verdict = 'over-estimate'
        else:
            verdict = 'under-estimate'
        rows.append({
            'slug': slug,
            'predicted_token_delta_per_session': predicted,
            'observed_chars': observed_delta,
            'pre_sessions': pre_sessions,
            'post_sessions': post_sessions,
            'verdict': verdict,
        })
    if rows:
        signed = sum(r['observed_chars'] - r['predicted_token_delta_per_session'] for r in rows) / len(rows)
        absol = sum(abs(r['observed_chars'] - r['predicted_token_delta_per_session']) for r in rows) / len(rows)
        calibration = {'mean_signed': f'{signed:+.0f}', 'mean_abs': f'{absol:.0f}'}
    else:
        calibration = {}
    print(render_report(rows, skipped, calibration))
    return 0


if __name__ == '__main__':
    sys.exit(main())
