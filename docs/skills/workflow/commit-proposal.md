# Commit Proposal

`/commit-proposal` is the final operator in the SEPL (Self-Evolution Protocol Loop) — it lands an assessed proposal onto a harness resource by snapshotting the prior version, writing the new content, and appending a commit entry to the immutable lineage ledger. It belongs to the `workflow` plugin, which owns the agentic-workflow router, sprint-contract enforcement, and the self-evolution pipeline.

This skill does not run in isolation. It is always the third step of a three-operator sequence: `/evolve` (or `/router-tune`) generates the proposal, `/assess-proposal` scores it, and `/commit-proposal` lands it — but only after the assessment returns `pass` and you give explicit approval.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/commit-proposal .claude/lineage/proposals/260519-router-threshold-v4.md
```

The argument is the path to the proposal file produced by `/evolve` or `/router-tune`.

## Why you need it

When the harness learns from usage — tightening routing thresholds, updating behavioral rules, adjusting skill descriptions — those mutations need to be traceable, reversible, and gate-controlled. A bare file edit leaves no history, no snapshot to restore from, and no record of what reasoning justified the change. `/commit-proposal` solves all three: it creates a versioned snapshot before writing, records a ledger entry that links the commit back to its proposal artifact, and copies the proposal's `change_contract:` block into the change manifest so future attribution queries can explain why a given resource changed.

The approval gate is not ceremony. Before any file is touched, the skill presents a diff preview and waits for an explicit `y` from you. This is the moment where human judgment enters the loop. The automated assessment cleared the four structural criteria; your approval confirms that you actually want this change shipped right now, against the current state of the repo.

## When to use it

- After `/assess-proposal` has returned a `pass` verdict and you want to land the change.
- When `/evolve` presents the approval prompt and you confirm with `y` — under that flow, `/evolve` calls this skill on your behalf.
- When re-committing a proposal that was deferred from an earlier session (the proposal file is still in `.claude/lineage/proposals/` in `propose` or `assess` state).

Do not use it for undoing a prior commit — use [`/rollback`](rollback.md) instead. Do not use it for plain git commits or arbitrary file edits — this is the SEPL operator that mutates versioned harness resources only.

## Best practices

- **Verify the assessment verdict before invoking.** The skill reads the ledger and refuses to proceed if the most recent entry for the resource is not an `assess` with `verdict: pass`. Do not try to force a commit past a failed assessment; fix the proposal and re-run `/assess-proposal` instead.
- **Read the diff preview carefully.** The skill shows you the first 20 lines of the diff before asking for approval. This is your last chance to catch a proposal that assessed correctly on its four structural criteria but still makes a change you did not intend. Take the thirty seconds.
- **One resource per call.** The skill refuses to batch multiple slugs in a single commit. This is intentional — each commit produces a distinct ledger entry and snapshot so that `/rollback` can target exactly the change that caused a regression.
- **Trust the snapshot.** After a commit, the prior version lives at `.claude/lineage/versions/<slug>/<prev-version>`. You can always return to it via `/rollback`. Do not manually edit the live resource to undo a commit — use the rollback path so the ledger stays coherent.
- **Let `/evolve` orchestrate when possible.** If you are running a full evolution cycle, use `/evolve` rather than calling this skill directly. `/evolve` handles the propose → assess → commit sequence, including the approval prompt, so you get the full cycle with a single command.

## How it improves your workflow

`/commit-proposal` converts a model-generated proposal into a durable, auditable change with a complete paper trail. Without it, self-improvement cycles produce suggestions that either get applied by hand (losing traceability) or forgotten. With it, every mutation of a harness resource — whether a behavioral rule, a SKILL.md description, a hook script, or an environment threshold — is linked to its proposal file, its assessment verdict, and its prior snapshot. That chain is what makes the harness self-improving in a controlled way: changes can be attributed, inspected, and reversed, so the system can safely accumulate learning without fear of silent drift.

## Related

- [`/evolve`](evolve.md) — the top-level orchestrator that calls this skill after assessment passes
- [`/rollback`](rollback.md) — reverses a commit using the snapshot this skill creates
- [`/router-tune`](router-tune.md) — produces the proposal artifacts this skill lands for router tuning
- [`../evaluator/assess-proposal.md`](../evaluator/assess-proposal.md) — the assessment step whose `pass` verdict is this skill's precondition
- [Architecture](../../architecture.md) — self-evolution and the lineage ledger in the 8-component harness model
