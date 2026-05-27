# Failure Attribute

`/failure-attribute` localizes the change that introduced a regression by replaying the verification obligations declared in each manifest entry and finding the first one that fails. It reads the N most recent entries from `.claude/evolution/change_manifest.jsonl`, flags entries with no evidence bundle first, then runs each entry's declared verifier commands and reports the primary suspect with a structured JSON output. It belongs to the `traces` plugin, which handles execution telemetry and evidence-grounded failure analysis in Forge Studio.

---

## Install

```bash
/plugin install traces@forge-studio
```

```text
/failure-attribute [N]
```

The optional `N` argument widens the search window beyond the default of 20 most-recent manifest entries.

## Why you need it

When a regression appears — a test that passed last week now fails, behavior changed unexpectedly, a file that was working stopped working — the first question is always "which change caused this?" The answer is not obvious when multiple changes have landed since the last known-good state. Naive approaches like scrolling git log and guessing by date work when the window is small, but their accuracy degrades quickly as the candidate set grows. Research on production attribution accuracy shows naive approaches succeed only 14–53% of the time; the gap closes when structured evidence is available.

`/failure-attribute` closes that gap by using the evidence that the manifest already contains. Every manifest entry should declare `verifier_obligations` — the commands that must pass for that change to be considered safe. The skill replays those commands in reverse chronological order and stops at the first failure. Entries that carry no evidence bundle at all are flagged before any replay, because a change that made no checkable claim is a suspect by default regardless of whether its verifier runs.

## When to use it

- As soon as a regression surfaces and the introducing change is unclear.
- Before deciding on a `/rollback` target — the skill gives you an evidence-grounded candidate rather than a date-based guess.
- When widening the search window because the regression might have been introduced more than 20 commits ago, use the `N` argument.

Do not use it for forward-looking risk analysis — that is `/assess-proposal`, which evaluates whether a proposed change is likely to be safe before it lands. `/failure-attribute` works backward from an observed failure; `/assess-proposal` works forward from a planned change.

## Best practices

- **Act on the `primary_suspect` field, not just the suspects list.** The JSON output contains both, but `primary_suspect` already encodes the ranking: priority 1 (no evidence) before priority 2 (verifier failed). Start your investigation there.
- **When the reason is `no_evidence`, treat the entry as the likely introduction point.** An entry with no evidence bundle made no checkable claim at the time it landed. That is the highest-suspicion signal the skill can surface.
- **When the reason is `verifier_failed`, read `evidence.command` carefully.** Verify that the command's path still exists before accepting the attribution — if a script referenced in `verifier_obligations` was renamed or deleted after the manifest entry was written, the replay will fail on the path, not on the actual regression.
- **Avoid long-running commands in `verifier_obligations`.** The replay enforces a 10-second timeout per command. Integration tests that wait on services will be killed and treated as failures. Keep obligations to short assertions: `test -f`, `python3 -c`, `bash -n`.

## How it improves your workflow

`/failure-attribute` turns regression triage from a memory exercise into a mechanical process. Instead of scanning commit messages and re-reading diffs, you run the skill and get a JSON report naming the entry most likely to be responsible, along with the exact command that failed and the output that explains why. The `files` field on the suspect entry tells you where to look; the `ts` and `id` fields tell you which manifest entry to target for rollback or re-verification. Evidence-grounded attribution is faster, more reliable, and produces a written record of the triage reasoning that you can audit later.

## Related

- [`trace-evolve.md`](trace-evolve.md) — for patterns of repeated failures across sessions; failure-attribute addresses single-regression localization
- [`../evaluator/postmortem.md`](../evaluator/postmortem.md) — the post-sprint retrospective that failure-attribute feeds when a regression closed a sprint with a red outcome
- [Architecture](../../architecture.md) — where execution traces and evidence-grounded attribution fit in the 8-component harness model
