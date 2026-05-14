---
name: startup-profile
description: Read the SessionStart timing log written by the diagnostics time-hook wrapper and report per-hook duration plus a cold-vs-warm split across recent sessions. Surfaces which plugin's bootstrap is dominating session-open latency.
when_to_use: Reach for this when session startup feels slow, after adding a new SessionStart hook to verify it stays within budget, or before a release to confirm cold-start has not regressed. Do NOT use for measuring per-tool latency mid-session — use `/token-audit` instead; startup-profile only covers SessionStart hooks.
disable-model-invocation: true
allowed-tools:
  - Read
  - Bash
logical: report shows per-plugin SessionStart ms median + p95 across the last N sessions, plus the slowest single hook
---

# /startup-profile — SessionStart Latency Report

Read the JSONL log produced by `plugins/diagnostics/lib/time-hook.sh` and summarize how long each plugin's SessionStart hooks take to run. Useful for catching regressions before users notice them.

## Source

The wrapper writes one JSON line per wrapped hook invocation to:

```
$FORGE_STUDIO_TIMING_LOG  (default: ~/.local/share/forge-studio/startup.jsonl)
```

Each row is:

```json
{"ts":"2026-05-06T12:17:30Z","session":"abc123","plugin":"behavioral-core","event":"SessionStart","duration_ms":47,"exit_code":0,"cmd":"bash .../output-style-check.sh"}
```

## Instructions

1. Default window is the last 20 sessions. Override with `LAST=N` env var.
2. Group rows by `(plugin, event)`. For each group emit median and p95 ms across rows.
3. Group rows by `session` to compute per-session totals (sum of all `duration_ms` in that session). Report median and p95 of session totals.
4. Cold vs warm: a session is "cold" if any hook in it has `duration_ms > 5000`; otherwise warm. Report counts and median totals separately.
5. Failures: list any rows with non-zero `exit_code`.

## Run

```bash
bash plugins/diagnostics/skills/startup-profile/scripts/profile.sh
```

## Output Format

```markdown
## SessionStart Latency Profile

**Window:** last {N} sessions ({cold} cold, {warm} warm)
**Log:** {path}

### Per-plugin (SessionStart only)
| Plugin | Hook | Calls | median ms | p95 ms |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

### Per-session totals
- Warm session median: {ms}, p95: {ms}
- Cold session median: {ms}, p95: {ms}

### Non-zero exits
{list of failing rows or "none"}

### Slowest single hook
{plugin/script} at {ms} on session {id}
```

## Budget (per `HARNESS_SPEC.md`)

- Warm session total: < 2,000 ms target, < 5,000 ms ceiling
- Cold session total: install time is unbounded by design; report it for visibility
- Per-hook warm: < 300 ms expected; document any exception in the hook script header

When the report breaches a budget, the fix lives in the offending hook script — wrap external installs behind first-run markers, defer non-critical work to background, or split the hook into a hot-path SessionStart + a heavier deferred-task hook.

## Failure Modes

- **Log missing:** `~/.local/share/forge-studio/startup.jsonl` does not exist. The wrapper has not run yet. Open one new session, then re-run.
- **Sessions tagged `unknown`:** `$CLAUDE_SESSION_ID` was not set when the hook ran (e.g. simulated runs). Filter these out by passing `EXCLUDE_UNKNOWN=1`.
- **Single-row groups:** insufficient data for p95. Report `--` instead of a misleading number.
