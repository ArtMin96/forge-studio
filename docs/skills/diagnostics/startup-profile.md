# Startup Profile

`/startup-profile` reads the JSONL timing log written by `plugins/diagnostics/lib/time-hook.sh` and summarizes how long each plugin's SessionStart hooks take to run. It reports per-plugin median and p95 durations, per-session totals, a cold-versus-warm split, and a list of any hooks that exited non-zero. The result is a concrete table showing which plugin's bootstrap is dominating session-open latency and whether you are within the HARNESS_SPEC warm-session budget. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/startup-profile
LAST=10 /startup-profile
```

No arguments are required. Override the session window with the `LAST=N` environment variable; the default is the last 20 sessions.

## Why you need it

SessionStart hook latency is invisible until it is painful. You add a new plugin, it registers a SessionStart hook that calls an external tool, and sessions that used to open in under a second now pause for three. Without instrumentation, the only way to catch this is noticing the slowness yourself — which typically happens after several sessions have already paid the cost. `/startup-profile` makes the latency visible before users notice it, because the timing log captures every wrapped hook invocation with millisecond precision.

The HARNESS_SPEC defines concrete budgets: warm sessions should have a total SessionStart duration under 2,000 ms (ceiling 5,000 ms) and each individual hook should complete in under 300 ms. These are not aspirational guidelines — they exist because slow session startup degrades the experience for every session that follows a code change or plugin addition. The profile report shows you exactly which hook is over budget and which plugin it belongs to, so the fix target is never ambiguous.

## When to use it

- When session startup feels slow after adding a new plugin or hook, to confirm whether the new hook is the source.
- Before a release, to verify cold-start latency has not regressed since the last measurement.
- After modifying a SessionStart hook, to confirm it stays within the per-hook 300 ms warm budget.
- When investigating non-zero exit codes in recent sessions that might indicate a hook is silently failing on startup.

Do not use it for measuring per-tool latency mid-session — that belongs to `/token-audit`. `/startup-profile` covers only SessionStart hooks; it has no visibility into what happens after the session is open.

## Best practices

- **Check the log path first if the report is empty.** The skill reads from `$FORGE_STUDIO_TIMING_LOG`, which defaults to `~/.local/share/forge-studio/startup.jsonl`. If the wrapper has not run yet — for example on a fresh checkout — the file does not exist and the report will say so. Open one new session with the diagnostics plugin installed, then re-run.
- **Use `LAST=N` to narrow or widen the analysis window.** A window of 5 sessions gives a tight recent snapshot; a window of 50 gives a broader trend. Use narrow windows after a specific change and wide windows for trend analysis.
- **Treat any cold session as a separate population.** Cold sessions — those with any hook over 5,000 ms — typically involve first-run package installation or cache warming, which is unbounded by design. The report splits them out so a single cold session does not inflate your warm-session median.
- **Single-row groups report `--` for p95.** When a plugin has run in only one session, there is insufficient data to compute a percentile. This is expected on fresh installs; wait for more sessions before reading p95 as meaningful.
- **Fix over-budget hooks in the hook script, not by removing the plugin.** When a hook exceeds the 300 ms per-hook warm budget, the fix is in the hook itself: wrap external installs behind first-run markers, defer non-critical work to a heavier deferred hook, or split the hot path from the expensive initialization.

## How it improves your workflow

`/startup-profile` closes the feedback loop on session bootstrap performance. Without it, a slow SessionStart hook is discovered by feel rather than measurement, and the fix is guesswork. With it, you have a table of median and p95 durations per plugin that makes the bottleneck immediately obvious. Running it after each plugin addition or SessionStart hook modification takes less than a second and gives you evidence — not intuition — that the warm-session budget is still met. Over time the timing log also accumulates trend data, so you can see whether session startup is gradually drifting upward across sprints before it becomes a noticeable problem.

## Related

- [`/entropy-scan`](entropy-scan.md) — Check 4 validates hook executability; startup-profile measures hook performance
- [`/validate-marketplace`](validate-marketplace.md) — Check 9 validates bash syntax of all hook scripts before they run
- [`/rest-audit`](rest-audit.md) — Efficiency axis measures CLAUDE.md size and memory pressure; startup-profile covers session-open latency
- [Architecture](../../architecture.md) — where execution traces and harness observability fit in the 8-component model
