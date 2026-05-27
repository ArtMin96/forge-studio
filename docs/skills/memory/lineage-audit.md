# Lineage Audit

`/lineage-audit` is a read-only inspection of the self-evolution ledger at `.claude/lineage/ledger.jsonl`. It runs six structured checks — parse validity, operator values, resource slug formats, commit preconditions, snapshot file presence, and post-reject discipline — and reports findings without touching a single file in the lineage tree. It belongs to the `memory` plugin, which provides Forge Studio's three-tier persistent memory system including the versioned lineage ledger that records every memory update.

---

## Install

```bash
/plugin install memory@forge-studio
```

```text
/lineage-audit
```

No arguments required. The skill reads `.claude/lineage/ledger.jsonl` by default; you can supply a different path if needed.

## Why you need it

The lineage ledger is the record of trust in the harness. Every time `/remember` updates an existing topic, every time `/commit-proposal` or `/rollback` runs, an entry is appended. That append-only record is what makes memory updates auditable and reversible. But the ledger is only as trustworthy as its own internal consistency: an entry that references a snapshot file that does not exist, or a commit that has no preceding assess with a passing verdict, is a gap between what the harness claims it did and what actually happened.

`/lineage-audit` surfaces those gaps before you rely on the ledger as evidence. If you are about to run `/rollback` and need to trust that the snapshots it depends on are on disk, a lineage audit confirms it first. If a session crashed mid-commit and you are not sure whether the ledger is in a consistent state, the audit tells you exactly which invariant was violated and what manual remediation would look like — without applying any fixes itself.

## When to use it

Reach for `/lineage-audit` when:

- You are about to run `/rollback` and want to confirm the ledger and its snapshot files are consistent before proceeding.
- A session ended unexpectedly during a `/commit-proposal` or `/rollback` operation and you need to assess the damage.
- You are conducting a periodic sanity check (monthly is a reasonable cadence for active projects).
- `/entropy-scan` reports a lineage-related finding that you want to investigate in detail.

Do not use it for validating marketplace drift or harness component counts — use [`/entropy-scan`](../diagnostics/entropy-scan.md) or `/validate-marketplace` instead. Those skills inspect the broader harness; `/lineage-audit` only inspects `.claude/lineage/`.

## Best practices

- **Run it before any rollback.** The skill's primary purpose is to give you confidence that the rollback target is reachable. A missing snapshot reported by Check 5 before a rollback is far less disruptive than discovering it mid-operation.
- **Treat `unverified` differently from `violation`.** Check 4 distinguishes between entries where the assess verdict is missing from the ledger inline (unverified — manual inspection required) and entries where the commit sequence is genuinely wrong (violation — a protocol breach). Only violations indicate a broken invariant; unverified entries indicate incomplete evidence that may be resolvable by reading the referenced evidence file.
- **Do not apply fixes from this skill.** The audit reports and recommends — it never writes. Repairing the ledger or restoring a missing snapshot is a deliberate human action. If the audit suggests a fix, carry it out manually or through the appropriate skill, not by re-running lineage-audit with write access.
- **Pair it with `/memory-index` for a full trust audit.** `/lineage-audit` tells you whether the ledger records are internally consistent; `/memory-index` tells you whether the topic files those records point to are still accurate. Together they cover the full trust surface of the memory system.
- **If no ledger exists yet, the audit reports N/A and exits cleanly.** A clean exit with "N/A — no ledger yet" is expected for new projects; it is not an error.

## How it improves your workflow

`/lineage-audit` makes the lineage ledger a reliable source of truth rather than an optimistic one. By running six independent checks — each targeting a specific invariant from the self-evolution protocol — it gives you a structured, falsifiable report rather than a general sense that things look okay. The output format (CLEAN or N violations per check, with line references and remediation suggestions) is designed to be actioned: you know exactly what is wrong, exactly where in the ledger, and what the expected fix looks like. That specificity is what makes the ledger usable as evidence when it matters most — before a rollback, after a crash, during a trust audit.

## Related

- [`/remember`](remember.md) — writes the ledger entries that this skill inspects
- [`/memory-index`](memory-index.md) — audits the topic files that the ledger tracks; pair with lineage-audit for a full trust audit
- [`/entropy-scan`](../diagnostics/entropy-scan.md) — harness-wide drift detection; use instead of lineage-audit for marketplace or component drift
- [Architecture](../../architecture.md) — where lineage and the self-evolution protocol fit in the 8-component harness model
