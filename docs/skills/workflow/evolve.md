# Evolve

`/evolve` is the top-level orchestrator for the SEPL (Self-Evolution Protocol Loop) in the `workflow` plugin. It drives the full propose → assess → commit sequence for self-modification of harness resources: it acquires proposals (from `/trace-evolve`, `/router-tune`, or a direct proposal file path), records them in the lineage ledger, dispatches `/assess-proposal` for independent scoring, presents passing proposals to you for approval, and hands approved proposals to `/commit-proposal` to land. The harness never mutates itself without your explicit confirmation at the approval gate.

---

## Install

```bash
/plugin install workflow@forge-studio
```

```text
/evolve router-tune
```

The optional argument is the signal source: `trace-evolve` (default), `router-tune`, or a path to an existing proposal file under `.claude/lineage/proposals/`.

## Why you need it

The behavioral harness that shapes how Claude Code works — routing rules, behavioral rules, skill descriptions, environment thresholds — needs to improve over time as you use it. But ad-hoc edits to those resources are hard to track, easy to get wrong, and impossible to undo cleanly. `/evolve` gives every self-modification a structured lifecycle: proposals are written with rationale, assessed against four structural criteria (single-variable, root-cause, honest-impact, no-regression), shown to you as a diff with an impact summary, and committed only on your explicit `y`. Every step leaves a ledger entry so the complete history is auditable and reversible.

The four-criteria assessment step is what separates this from a simple "propose and apply" pattern. An improvement that changes two things at once, attributes a problem to the wrong cause, overstates its impact, or risks regressions will fail assessment and never reach your approval prompt. That filter catches blind spots that are easy to miss when reviewing proposals manually.

## When to use it

- After `/router-tune` has analyzed classification history and written proposal artifacts — run `/evolve router-tune` to drive them through the assess-commit pipeline.
- After `/trace-evolve` has identified improvement clusters from execution traces — run `/evolve` (default) to process those proposals.
- When you have a manually authored proposal file and want to drive it through the full assessment and commit pipeline instead of applying it by hand.

Do not use it for writing proposals — that is the job of `/router-tune` or `/trace-evolve`. `/evolve` consumes proposals; it does not author them.

## Best practices

- **Do not skip the assessment even for "obvious" proposals.** The four criteria exist to catch structural problems that look obvious in isolation but have non-obvious side effects. A failed assessment is information — it tells you what was wrong with the proposal, which you can then fix and resubmit.
- **Review the diff preview before approving.** Each proposal gets its own approval prompt with the first 20 lines of the diff and an impact estimate. Take the time to read it. The assessment cleared the structural criteria; your review confirms the change is what you actually want.
- **Use `skip-all` to defer, not abandon.** If you get mid-cycle and realize you want to review the remaining proposals later, respond `skip-all` at the approval prompt. The proposals stay in `propose`/`assess` state on disk and can be resumed in a future session.
- **Rejected proposals stay on disk.** A `N` at the approval prompt appends a `reject` ledger entry and moves on — it does not delete the proposal file. Rejected proposals inform future rounds of `/trace-evolve`, which reads them as negative evidence.
- **One proposal per commit.** `/evolve` presents each proposal individually and calls `/commit-proposal` once per approved proposal. This is deliberate: the per-resource commit boundary is what makes `/rollback` precise.

## How it improves your workflow

`/evolve` is the mechanism that turns usage patterns into permanent improvements. Without it, observations like "the router consistently misclassifies refactor prompts" or "the brevity rule is too aggressive" stay as informal notes. With it, those observations become assessed proposals with explicit rationale, scored against consistent criteria, committed with snapshots, and recorded in an append-only ledger. The harness becomes incrementally better over sessions without you needing to manually track what changed and why.

## Related

- [`/router-tune`](router-tune.md) — analyzes router classification history and produces proposal artifacts for this skill to consume
- [`/commit-proposal`](commit-proposal.md) — the commit operator this skill calls after assessment passes and you approve
- [`/rollback`](rollback.md) — reverses any commit this skill produces
- [`../evaluator/assess-proposal.md`](../evaluator/assess-proposal.md) — the assessment step run inside this skill's loop
- [Architecture](../../architecture.md) — self-evolution in the 8-component harness model
