# Federated Fan-Out

`/federated-fan-out` applies the same operation to 2–5 independent sibling repositories in parallel. You provide a repos file (one absolute path per line) and a prompt file describing the task; the skill spawns one subagent per repository, captures per-repo results in a shared workspace ledger, and prints a summary table when all agents finish. It belongs to the `cross-repo` plugin, which provides cross-repository coordination and discovery skills for Forge Studio's agentic harness.

---

## Install

```bash
/plugin install cross-repo@forge-studio
```

```bash
python3 plugins/cross-repo/skills/federated-fan-out/scripts/run.py \
  --repos /path/to/repos.txt \
  --prompt /path/to/prompt.txt \
  --run-id my-run-id
```

`--repos` is a file with up to 5 absolute repo paths, one per line. `--prompt` is the task description passed verbatim to each subagent. `--run-id` names the workspace under `~/.forge-cross-repo/`.

## Why you need it

Applying the same change across multiple repositories manually is error-prone and slow: you open each repo, run the operation, check the result, and try to hold the per-repo status in your head. If a repo fails mid-batch, the partial state is hard to reason about. `/federated-fan-out` makes the operation atomic at the batch level: each repo gets a dedicated subagent, every phase (start, complete, failed) is appended to an append-only ledger, and the results land in a structured workspace that `/aggregate-results` can summarize in one command.

The ≤5 repo limit is deliberate. Five parallel subagents produce a reviewable batch; more than that is difficult to audit and easy to misread when results diverge.

## When to use it

- Syncing a convention change (CLAUDE.md template, lint config, CI workflow) across a family of related repositories.
- Applying a patch or fix that has already been validated in one repo to all siblings.
- Running an audit prompt across multiple codebases and collecting the outputs for comparison.

Do not use it for comparing patterns between repos — use [`/sync-discovery`](sync-discovery.md) instead, which searches for a specific regex across two repos and classifies matches. Do not use it to collate results from an already-completed run — use [`/aggregate-results`](aggregate-results.md) for that.

## Best practices

- **Validate repo paths before running.** Each path in the repos file must be an absolute path to an existing git directory. A missing path causes that repo's result to land as `status: failed`; the skill exits non-zero if any repo fails.
- **Keep prompts self-contained.** Each subagent starts a fresh `claude -p` session with no warm context from the calling session. The prompt file must contain everything the subagent needs to complete the task independently.
- **Use `--mock` during iteration.** The `--mock` flag skips real subagent invocations and produces deterministic stub results. Use it to verify the workspace structure and ledger format before committing to a real run.
- **Run `/aggregate-results` after completion.** The summary table printed at the end of a fan-out run is a convenience view. For a full verdict matrix with de-duplicated summaries and `aggregated.json`, run `/aggregate-results <run-id>` as the skill's checklist recommends.
- **Keep the run-id unique.** Reusing a run-id overwrites the previous workspace. Use a datestamped name (for example, `sync-2026-05-27`) to keep runs auditable.

## How it improves your workflow

`/federated-fan-out` turns a multi-repo batch operation from a manual loop into a single structured invocation. The ledger tracks every phase, so partial failures are visible and recoverable rather than silent. The workspace layout — one directory per repo under `~/.forge-cross-repo/<run-id>/` — gives downstream tools like `/aggregate-results` a stable, predictable input to work from. The result is that cross-repo operations become repeatable and auditable rather than ad-hoc.

## Related

- [`aggregate-results.md`](aggregate-results.md) — collates the per-repo result.json files after a fan-out run into a verdict matrix
- [`sync-discovery.md`](sync-discovery.md) — compare a pattern across two repos before deciding whether to fan out a fix
- [`../agents/fan-out.md`](../agents/fan-out.md) — the single-repo fan-out skill; use this for batching across files within one repo
- [Architecture](../../architecture.md) — multi-agent decomposition in the 8-component harness model
