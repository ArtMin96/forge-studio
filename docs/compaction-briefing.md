# Compaction Briefing

When Claude Code compacts your session context, most of the working memory is replaced by a summary. Two hooks in the `context-engine` plugin (PreCompact: `forward-briefing.sh`; PostCompact: `post-compact-recovery.sh`) ensure the highest-signal state survives that boundary in a structured YAML form, not as prose narration.

arXiv:2605.18747 §3.2.6 identifies this as the technical gap: bare summaries silently drop failing test names, stack frames, and suspect file references — exactly the data the next turn needs to continue without asking you to reconstruct everything.

---

## What survives compaction

The structured briefing captures four fields:

| Field | Source | What it contains |
|-------|--------|-----------------|
| `open_failures` | `~/.claude/traces/*.jsonl` | Last 5 non-zero-exit tool calls: the command (truncated to 80 chars), a one-line stack preview, and the log file path |
| `recent_edits` | `.claude/state/belief.jsonl` | Last 10 unique file paths touched this session (via Edit or Write) |
| `pending_verifications` | `.claude/evolution/change_manifest.jsonl` | `verifier_obligations` commands from the last 5 manifest entries whose `evidence_bundle.checks_run` is empty — these are the checks that were declared but not yet run |
| `belief_snapshots` | `.claude/state/belief.jsonl` | The most recent sha256 per path — lets the post-compact turn detect belief drift before re-editing a file |

All four fields are always present in the YAML. If no data is available for a field, it emits an empty list (`[]`), not a missing key.

### Example output

```yaml
ts: "2026-05-20T14:32:01Z"
session_id: "abc123"
open_failures:
  - test: "pytest tests/auth/test_middleware.py::test_token_refresh"
    stack_top: "AssertionError: expected 401, got 500 (line 47)"
    suspect_files: []
    log_path: "/home/user/.claude/traces/2026-05-20-abc1.jsonl"
recent_edits:
  - "/app/Http/Middleware/TokenAuth.php"
  - "tests/auth/test_middleware.py"
pending_verifications:
  - "pytest tests/auth/ -x"
belief_snapshots:
  - path: "/app/Http/Middleware/TokenAuth.php"
    sha256: "a3f1b2c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2"
```

The `post-compact-recovery.sh` hook reads this file and re-emits it as structured Markdown at the start of the first post-compact turn, so Claude has the exact paths and commands to resume work.

---

## What is lost

Everything not in those four fields is intentionally excluded. By design, the compaction boundary discards:

- Full conversation history and tool call chains
- Inline reasoning and intermediate conclusions
- The prose summary written by `pre-compact.sh` (scope, plan pointer, git state) — that recovery path continues unchanged via `post-compact.sh`
- Per-turn context about *why* edits were made (the manifest captures what changed; the briefing captures what failed and what to verify next)

This is the right trade-off: context windows are finite, and the briefing targets the minimal viable recovery set.

---

## How to manually trigger a briefing

The hook fires automatically at every compaction. To generate a briefing outside of compaction (for inspection or debugging):

```bash
# From the repo root:
bash plugins/context-engine/hooks/forward-briefing.sh

# The YAML goes to stdout. The hook also writes it to:
# .claude/state/forward-briefing-<session-id>.yaml
# (session-id defaults to "unknown" when CLAUDE_SESSION_ID is unset)

# Inspect the written file:
cat .claude/state/forward-briefing-unknown.yaml

# Validate it parses:
python3 -c "import yaml; d=yaml.safe_load(open('.claude/state/forward-briefing-unknown.yaml')); print(list(d.keys()))"

# Simulate post-compact recovery:
bash plugins/context-engine/hooks/post-compact-recovery.sh
```

The recovery hook looks for `.claude/state/forward-briefing-<CLAUDE_SESSION_ID>.yaml`. If that file does not exist, it exits silently (exit 0) — no error, no output.

---

## When briefing fails

The briefing degrades gracefully when source artifacts are missing:

**No belief.jsonl** (`plugins/context-engine/hooks/belief-snapshot.sh` has not fired yet, or was disabled):
- `recent_edits` → `[]`
- `belief_snapshots` → `[]`
- `open_failures` and `pending_verifications` are unaffected — they draw from different sources.

**No change_manifest.jsonl** (the forge-meta manifest hook has not run):
- `pending_verifications` → `[]`
- The other three fields are unaffected.

**No trace files** (`~/.claude/traces/` is empty or `FORGE_TRACES_ENABLED=0`):
- `open_failures` → `[]`
- The other three fields are unaffected.

**Python 3 not available**:
- The script exits 0 without writing a file. The `post-compact-recovery.sh` hook finds no file and exits silently.

**Corrupt JSONL entries** (partial writes, encoding errors):
- The parser skips unparseable lines and continues. A session with some corrupt entries still produces valid output from the readable lines.

In all degraded cases, the hook exits 0. PreCompact hooks that exit non-zero can block compaction — a briefing failure should never do that.

---

## Relationship to other recovery mechanisms

| Mechanism | What it recovers | When |
|-----------|-----------------|------|
| `pre-compact.sh` / `post-compact.sh` | Scope, plan pointer, git state, task list | Every compaction |
| `forward-briefing.sh` / `post-compact-recovery.sh` | Open failures, recent edits, pending checks, belief sha256s | Every compaction |
| `post-compact-belief-audit.sh` | Belief drift check on the 5 most-recently-edited files | Every compaction (async) |
| `/session-resume` | Full session briefing from progress log + spec + features | Manual invocation |

The structured briefing does not replace any of these — it runs alongside them and adds provenance that prose summaries cannot carry.
