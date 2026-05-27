# R.E.S.T. Audit

`/rest-audit` is the outcome-oriented diagnostic surface for Forge Studio. Where `/entropy-scan` checks structural drift — file counts, registration gaps, convention violations — this skill reports against four production-readiness outcomes from the TRAE R.E.S.T. framework: Reliability, Efficiency, Security, and Traceability. Each axis pulls signals from at least two plugins and produces a PASS / WARN / FAIL verdict plus one concrete next step. It belongs to the `diagnostics` plugin, which provides health-checking and quality-gate skills across the harness.

---

## Install

```bash
/plugin install diagnostics@forge-studio
```

```text
/rest-audit
```

No arguments. The skill reads from the ledger, plugin hooks, CLAUDE.md, memory index, and feature registry automatically.

## Why you need it

Structural drift is one kind of problem; outcome drift is another. You can have a harness where all files are registered, all counts match, and all hooks are executable — yet fault recovery is broken because `init.sh` is missing, or security is degraded because the `policy-gateway` plugin fires but never logs any blocks, or traceability is hollow because there are no ledger entries in the last week. These gaps do not show up in file-level checks. They show up in the R.E.S.T. axes, which are explicitly outcome-oriented.

Reliability catches runaway safe-mode events and missing recovery coverage. Efficiency surfaces CLAUDE.md bloat and memory topic overload before they slow sessions down. Security checks whether the enforcement plugins are not just present but actually armed and exercised. Traceability measures whether sessions are producing the trace artifacts that make retrospectives and debugging possible. Each failing check comes with one actionable next step rather than a pile of undifferentiated findings.

## When to use it

- As a periodic health check before releases, alongside `/entropy-scan`.
- When investigating a session regression that seems to span multiple plugins — a missed gate, a token blowout, an unexplained behavior — and you need a cross-cut view to narrow the source.
- After installing or removing a plugin, to confirm the R.E.S.T. axes have not degraded.
- When `/entropy-scan` Check 9a delegates to this skill and you want the full output.

Do not use it for structural drift — mismatches between file counts, README headers, or marketplace registrations belong to [`/entropy-scan`](entropy-scan.md). `/rest-audit` reports outcomes (were the right things happening at runtime?), not file-level mismatches (are the right files in place?). Both audits are worth running before a release; they answer different questions.

## Best practices

- **FAIL on any axis is a release blocker.** The overall verdict is the worst axis, and a FAIL means a measurable production-readiness criterion is not met. Treat it as you would a failing test.
- **Follow the "Next:" step for each axis.** The report emits one concrete remediation pointer per axis — for example, "Run `/policy-audit` to confirm scanners are reaching the working tree." Follow it rather than trying to diagnose the axis manually; the delegated skill has the depth that `/rest-audit` deliberately omits.
- **A WARN on Security with zero policy-block events needs context.** Zero blocks could mean the repo is genuinely clean, or it could mean the matchers are misconfigured. The report notes this ambiguity and points to `/policy-audit` for the follow-up. Do not interpret zero-block as a clean signal without that check.
- **Efficiency axis: CLAUDE.md line count is a proxy for context budget.** A CLAUDE.md over 300 lines FAIL threshold is not arbitrary — it reflects real context-window pressure on sessions that load the file at start. Pair a FAIL here with `/lean-md` to trim without weakening behavioral rules.
- **Traceability requires at least some session history.** A fresh checkout with no ledger entries will show WARN on Traceability axes that depend on the ledger. Run the producing skills — `/progress-log`, `/postmortem`, the traces hooks — to populate the signal before interpreting the audit results.

## How it improves your workflow

`/rest-audit` is the health check that operates at the level of consequences rather than files. Structural drift makes the system messy; outcome drift makes it unreliable. Running both audits on a regular cadence — entropy-scan for the file level, rest-audit for the outcome level — gives you a layered view of harness health that neither audit provides alone. The four-axis structure also makes regression detection straightforward: if Security was PASS last week and is WARN this week, something changed in the policy enforcement path, and the R.E.S.T. report tells you which check degraded and what to do about it.

## Related

- [`/entropy-scan`](entropy-scan.md) — structural drift audit; entropy-scan includes rest-audit as Check 9a
- [`/validate-marketplace`](validate-marketplace.md) — pre-commit correctness check; complements rest-audit's runtime focus
- [`/policies-list`](policies-list.md) — Security axis reads policy-gateway configuration; policies-list shows the full enforcement inventory
- [`/postmortem`](../evaluator/postmortem.md) — Reliability axis reads postmortem coverage; run this after safe-mode exits to improve the ratio
- [`/healthcheck`](../evaluator/healthcheck.md) — session-level health check; rest-audit is the project-level counterpart
- [Architecture](../../architecture.md) — where evaluation and quality gates fit in the 8-component harness model
