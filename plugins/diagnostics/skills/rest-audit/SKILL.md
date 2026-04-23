---
name: rest-audit
description: Audit the project against the R.E.S.T. framework (TRAE) — Reliability, Efficiency, Security, Traceability. Reads ledger entries, hook state, and artifact presence across long-session + policy-gateway + context-engine + traces. Single PASS/WARN/FAIL table. Cross-cut meta-surface.
when_to_use: Periodic checkup (like /entropy-scan). Before releases. When investigating a session regression.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# /rest-audit — R.E.S.T. Framework Audit

Outcome-oriented audit surface. Unlike `/entropy-scan` (structural — drift/registration/invariants), this one reports against the four production-readiness outcomes from TRAE's R.E.S.T. framework: Reliability · Efficiency · Security · Traceability.

Every axis pulls from at least two existing plugins so a failure has a concrete remediation path.

## Process

For each axis, collect signals → classify PASS / WARN / FAIL → report one actionable next step.

### Reliability (targets: fault recovery, idempotency, graceful degradation)

| Check | PASS | WARN | FAIL |
|---|---|---|---|
| `claude-progress.txt` exists AND has ≥1 entry | yes | 0 entries | missing |
| `init.sh` exists AND executable | yes | non-exec | missing |
| Ledger has ≥0 `safe-mode-enter` events in last 7 days | 0–1 | 2–3 | ≥4 (runaway) |
| `/postmortem` coverage: ratio of `safe-mode-exit` ledger events followed by a memory entry within 24h | ≥0.8 | 0.5–0.8 | <0.5 |
| `consecutive-failure-guard` present in hooks.json | present | — | missing |

Sources: `.claude/lineage/ledger.jsonl`, `claude-progress.txt`, `init.sh`, `plugins/context-engine/hooks/hooks.json`.

### Efficiency (targets: resource control, per-category budgets, low-latency)

| Check | PASS | WARN | FAIL |
|---|---|---|---|
| CLAUDE.md size (root) | <150 lines | 150–300 | >300 |
| `/token-pipeline` nudge surfaced last session | yes (hook log or user run) | no data | — |
| Memory topic count | <30 | 30–60 | >60 |
| Features.json pending/done ratio (if present) | <1.0 | 1.0–3.0 | >3.0 (backlog blowout) |
| Traces hook wiring present | present | — | missing |

Sources: `CLAUDE.md`, `.claude/memory/MEMORY.md`, `.claude/features.json`, `plugins/traces/hooks/hooks.json`.

### Security (targets: least privilege, I/O filtering, injection defense)

| Check | PASS | WARN | FAIL |
|---|---|---|---|
| `policy-gateway` plugin present | yes | — | missing |
| `block-destructive.sh` + `scan-secrets.sh` both PreToolUse | both | one | neither |
| `rules.d/secrets.txt` exists AND non-empty | yes | empty | missing |
| Ledger `policy-block` events in last 30 days (sign the plugin is armed AND being used) | ≥1 | 0 but plugin present | plugin missing |
| Sensitive files not in working tree (grep matches via `/policy-audit` pass 2) | 0 matches | 1–2 | ≥3 |

Sources: `.claude-plugin/marketplace.json`, `plugins/policy-gateway/`, ledger.

### Traceability (targets: end-to-end trace, explainability, auditability)

| Check | PASS | WARN | FAIL |
|---|---|---|---|
| `traces/hooks/hooks.json` registers ≥3 collectors | ≥3 | 1–2 | 0 |
| Ledger entries in last 7 days | ≥5 | 1–4 | 0 |
| Handoff-equivalent coverage: `claude-progress.txt` entries vs session count (sessions count = `.claude/traces/session-*.jsonl` file count or similar) | ≥0.7 | 0.3–0.7 | <0.3 |
| `/lineage-audit` runs clean (invoke it as part of rest-audit; propagate failures) | clean | warnings | fails |

Sources: `plugins/traces/hooks/hooks.json`, `.claude/lineage/ledger.jsonl`, `.claude/traces/` (if present), call `/lineage-audit`.

## Output

```
R.E.S.T. AUDIT — <UTC>
=============================================

Reliability    [PASS/WARN/FAIL]
  <check>  [status]  <detail>
  Next: <one concrete action>

Efficiency     [PASS/WARN/FAIL]
  <check>  [status]  <detail>
  Next: <one concrete action>

Security       [PASS/WARN/FAIL]
  <check>  [status]  <detail>
  Next: <one concrete action>  (e.g. "Run /policy-audit for deep dive")

Traceability   [PASS/WARN/FAIL]
  <check>  [status]  <detail>
  Next: <one concrete action>  (e.g. "Run /lineage-audit")

Overall: PASS / WARN / FAIL
```

Axis status = worst individual check.
Overall = worst axis.

## Integration

**Reads from everywhere** — this is the meta-surface:
- `.claude/lineage/ledger.jsonl` — safe-mode, policy-block, progress-log, SEPL events
- `claude-progress.txt` — long-session coverage
- `.claude/spec.md`, `.claude/features.json` — living spec / testable reqs
- `.claude/memory/MEMORY.md` — memory bloat signal
- `CLAUDE.md` — efficiency signal
- `plugins/*/hooks/hooks.json` — wiring-presence signals
- `plugins/policy-gateway/rules.d/*.txt` — armed-rules signal

**Delegates to:**
- `/policy-audit` for Security deep dive
- `/lineage-audit` for Traceability deep dive
- `/token-pipeline` for Efficiency remediation planning
- `/postmortem` for Reliability remediation (after safe-mode exits)

**Invoked by:**
- `/entropy-scan` includes this skill as a sub-check
- `/evolve` reads the FAIL list to seed proposals (e.g. if Security axis fails, propose adding a rule to `rules.d/secrets.txt`)

## Failure Modes

- Ledger missing → axes that depend on it report WARN (not FAIL) and suggest running the producing skills at least once.
- `/lineage-audit` not installed → Traceability axis still runs (skips only the sub-call).
- Some signals unknowable without Claude Code instrumentation (e.g. `/postmortem` memory check requires reading memory index) — degrade to best-effort.

## Do NOT

- Do not fix anything. This skill is diagnostic only; remediation belongs to the delegated skills.
- Do not write anything except the report. No ledger writes (the audit itself is not a protocol operator).
