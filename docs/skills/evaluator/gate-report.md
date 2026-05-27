# Gate Report

`/gate-report` produces a single consolidated quality summary of everything the hooks have flagged during your current session. It scans for static analysis warnings, migration files missing a `down()` method, debug artifacts left in the diff (`dd()`, `dump()`, `console.log`), newly added TODOs, potential credential leaks, policy-gateway blocks from the lineage ledger, feature-tracking status from `.claude/features.json`, and the pass/fail result from the last `/verify` run. The output ends with a binary `READY TO COMMIT: Yes / No` verdict. It uses Haiku under the hood and is read-only — it re-aggregates what the hooks already caught, not a re-execution of the underlying checks.

It belongs to the `evaluator` plugin, which provides evaluation, verification, and quality-gate skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install evaluator@forge-studio
```

```text
/gate-report
```

No arguments required. The skill reads the current session state automatically.

## Why you need it

Over a long session, warnings accumulate in hooks, the lineage ledger, and tool output — scattered across dozens of turns. By the time you are ready to commit, it is easy to forget that PHPStan emitted two errors three hours ago, or that a `console.log` slipped into the diff at some point, or that a policy block was triggered when a secret was briefly staged. The pre-commit mental checklist fails silently: you cannot recall what you do not remember seeing.

`/gate-report` collapses every warning from the session into one screen. Instead of manually hunting through turns, you get a single view of all outstanding issues with the offending file and line cited. The `READY TO COMMIT` line is the answer to the question you were already asking yourself.

## When to use it

- Right before opening a pull request or running `git commit` at the end of a session.
- After a long session with many small changes, when the mental checklist is unreliable.
- When investigating whether anything failed silently — policy blocks, drift checkpoints, scope-guard denials.
- Before tagging a release or handing off work to another engineer.

Do not use it for running new audits — use `/rules-audit` or `/healthcheck` for that; gate-report only re-aggregates warnings the hooks already emitted.

## Best practices

- **Run `/verify` before `/gate-report`.** Gate-report reads the `/verify` gate file at `.claude/gate/features.json`. If you have not run `/verify` this session, the gate line will read `NOT RUN` rather than a real pass/fail count.
- **Strip debug artifacts before staging.** The report flags `dd()`, `dump()`, and `console.log` in the diff. These are always `READY TO COMMIT: No` blockers — remove them before re-running.
- **Investigate policy blocks, not just counts.** A `policy-block` entry in the ledger means a tool was denied during the session. The report gives you the count; read the ledger entry to understand what was blocked and why.
- **Treat `pending` feature overlap as a warning, not a blocker.** If a pending feature in `.claude/features.json` overlaps with the current diff, it means the feature may be partially implemented. Confirm the feature is intentionally incomplete before committing.

## How it improves your workflow

The value of `/gate-report` is that it makes the pre-commit checklist impossible to skip by accident. Every category of session artifact — warnings, debug cruft, policy events, feature state, and verification results — is checked and reported in one pass. The `READY TO COMMIT` line gives you a defensible answer rather than a feeling, which matters both for your own confidence and for the auditability of the session record.

## Related

- [`verify.md`](verify.md) — the evidence gate that populates `.claude/gate/features.json`; run before gate-report
- [`healthcheck.md`](healthcheck.md) — runs the actual lint/test pipeline; gate-report reads what healthcheck and hooks already emitted
- [`postmortem.md`](postmortem.md) — if gate-report uncovers a bug that reached the diff, postmortem is the follow-up after the fix
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
