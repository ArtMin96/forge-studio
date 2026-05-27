# Rollback

`/rollback` reverses a prior self-evolution commit by restoring a versioned snapshot from `.claude/lineage/versions/<slug>/<version>` and appending a rollback entry to the lineage ledger. It belongs to the `workflow` plugin. Because the rollback itself is a ledger entry — not a deletion — the history stays append-only and fully auditable: you can see what was committed, when it was rolled back, and roll forward again if needed.

Before prompting you for a target version, the skill runs failure attribution to suggest the most likely culprit from the change manifest, so you do not have to guess which commit introduced the regression.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/rollback skills/workflow/router-tune v2
```

The first argument is the resource slug (same format as `/commit-proposal`). The optional second argument is the target version to restore; if omitted, the skill defaults to the most recent snapshot.

## Why you need it

Self-evolution commits are made carefully — assessed against four criteria, shown as a diff, approved by you — but they can still introduce regressions. A threshold tweak that looked safe at assessment time may interact with a pattern that was not in the training data. A rule addition may conflict with an existing rule in ways that only show up in production usage. When that happens, you need to undo the commit cleanly: restore the prior resource state, record that the rollback happened, and leave the forward snapshot intact so the rollback itself can be reversed if the evidence turns out to be inconclusive.

`/rollback` does all of this correctly. It snapshots the current state before restoring (so you can re-roll forward), restores the target version, and appends a `rollback` ledger entry that points back to the snapshot. The result is that rolling back is as safe and traceable as rolling forward.

## When to use it

- When a recent `/commit-proposal` introduced a regression and you want to restore the prior resource version.
- When `/lineage-audit` flags a commit as problematic and recommends rollback.
- When you want to return to a known-good version of a rule, skill description, or environment threshold while you investigate the issue further.

Do not use it for arbitrary working-tree changes unrelated to the SEPL lineage — use `git revert` for those. Do not use it to assess whether rollback is needed — that is [`/lineage-audit`](../memory/lineage-audit.md)'s job.

## Best practices

- **Read the attribution suggestion before choosing a target.** The skill runs `attribute.sh` against the change manifest and surfaces a `primary_suspect` if one is found. In most cases this is the version you want. Override it only when you have specific evidence that a different version is the culprit.
- **Roll back one resource at a time.** The skill is deliberately single-resource per call. If a regression spans multiple resources, investigate which one is the actual cause before rolling back both — rolling back two resources at once makes it impossible to isolate which rollback fixed the problem.
- **Check the re-roll-forward path.** The skill reports the command to re-roll forward after a rollback: `Rolled back <slug> v3 → v2. Forward version snapshot saved: /rollback <slug> v3`. Keep that line in mind — if the rollback turns out to have been wrong, restoring v3 is a single command.
- **Do not manually restore from the snapshot directory.** The snapshot files are there to support the rollback operation, not to be manually copied. A manual copy bypasses the ledger entry, leaving the history in an inconsistent state where the live file and the ledger disagree.
- **Treat `v0` carefully.** The original shipped file (before any SEPL commit) is not automatically snapshotted. Rollback to `v0` is not supported through this skill — use git history for pre-evolution state.

## How it improves your workflow

`/rollback` is the safety net that makes self-evolution worth trusting. Without it, every SEPL commit carries irreversible risk — if a threshold tweak degrades routing quality in a pattern that was not visible at assessment time, you would need to manually reconstruct the prior state from memory or git history. With it, reverting a commit is a single command that takes seconds and leaves the full history intact. That guarantee is what makes it reasonable to approve evolution proposals with confidence: you know that if a commit turns out to be wrong, undoing it is clean, fast, and auditable.

## Related

- [`/commit-proposal`](commit-proposal.md) — the commit operator this skill reverses; creates the snapshots this skill restores from
- [`/evolve`](evolve.md) — the top-level SEPL orchestrator; rollback is the recovery path when its commits regress
- [`../evaluator/postmortem.md`](../evaluator/postmortem.md) — use to document what went wrong when a commit regressed before rolling back
- [Architecture](../../architecture.md) — self-evolution and lineage tracking in the 8-component harness model
