---
name: evolve
description: Run a self-evolution cycle. Consumes a proposal source (trace-evolve output, router-tune output, manual proposal), routes through /assess-proposal, asks for user approval, hands off to /commit-proposal. Never mutates harness files without consent.
when_to_use: Reach for this when `/router-tune` or `/trace-evolve` has produced a proposal artifact ready for the assess-commit pipeline, or when the user wants to run a manual SEPL cycle. Do NOT use to write the proposal itself — those upstream skills (`/router-tune`, `/trace-evolve`, manual draft) generate proposals; `/evolve` orchestrates the propose → assess → commit handoff.
disable-model-invocation: true
effort: high
argument-hint: [signal-source]
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# /evolve — SEPL Orchestrator

Top-level skill for the propose → assess → commit loop. Composes `/trace-evolve` (traces), `/assess-proposal` (evaluator), `/commit-proposal` (this plugin). See `docs/lineage.md` for the protocol.

**Never** writes to harness files directly. This skill orchestrates; mutation happens in `/commit-proposal` after user approval.

## Input

Optional `[signal-source]`:
- `trace-evolve` (default) — invoke `/trace-evolve` and use its proposals
- `router-tune` — invoke `/router-tune` (workflow) for router-specific proposals
- `<path>` — path to an existing proposal file under `.claude/lineage/proposals/`

## Flow

### Step 1 — Acquire proposals

For `trace-evolve`:
- Invoke `/trace-evolve`. It emits a cluster report but does not write ledger entries. Convert each cluster's `Proposed change` section into a standalone proposal artifact at `.claude/lineage/proposals/<YYMMDD>-<slug>-v<N>.md` with the required fields (resource, current, proposed, rationale, impact).

For `router-tune`:
- Invoke `/router-tune`. It writes proposal artifacts directly — skip to step 2.

For a direct path:
- Read the file. Verify it has the five proposal sections. If not, reject and tell the user to fix the artifact.

### Step 2 — Record `propose` entries

For each proposal, append to `.claude/lineage/ledger.jsonl`:

```json
{"ts":"<UTC>","operator":"propose","resource":"<slug>","version":"v<N>","prev":"<current>","trigger":"<signal-source>","evidence":"<artifact-path>","actor":"workflow:/evolve"}
```

### Step 3 — Assess each proposal

For each proposal, invoke `/assess-proposal <artifact-path>`. It runs in a forked `reviewer` subagent (read-only) and writes a verdict JSON + `assess` ledger entry.

### Step 4 — User approval gate

For each proposal where verdict = `pass`, show the user:

```
Proposal <N>/<total>: <slug> <current> → <target>
  Trigger: <trigger>
  Impact:  <estimate from artifact>
  Verdict: PASS (criteria: single-variable, root-cause, honest-impact, no-regression)
  Diff preview (first 20 lines):
    <diff>
  Approve commit? (y/N/skip-all)
```

On `y` → invoke `/commit-proposal <artifact-path>`.
On `N` or empty → append `reject` entry, continue to next proposal.
On `skip-all` → break the loop. Remaining proposals stay in `propose`/`assess` state for later sessions.

For proposals where verdict = `fail` or `conditional`, do NOT present commit approval. Report the verdict reason and move on. Author revises and re-runs.

### Step 5 — Summary report

```
Evolve cycle complete.
  Proposals received:  N
  Assessed pass:       N
  Committed:           N
  Rejected by user:    N
  Failed assessment:   N
  Skipped:             N

Ledger entries: .claude/lineage/ledger.jsonl
Verdicts:       .claude/lineage/verdicts/
Snapshots:      .claude/lineage/versions/
```

## Do NOT

- Do not skip the assess step even for "obviously safe" proposals. The four criteria exist to catch blind spots.
- Do not batch multiple commits in one approval prompt. Each proposal gets its own prompt so the user can reject selectively.
- Do not auto-commit file resources. Auto-commit is reserved for `env/<VAR>` numeric tweaks under `WORKFLOW_EVOLVE_AUTOCOMMIT=1` (see `/commit-proposal`).
- Do not delete rejected proposals. They stay on disk as negative evidence — informs future rounds of `/trace-evolve`.

## Execution Checklist

- [ ] Located the source proposal artifact (path or signal source)
- [ ] Confirmed it has a `resource:` slug, target `version:`, rationale, and proposed content
- [ ] Forked `/assess-proposal` with the proposal path; captured the verdict
- [ ] Verdict is `pass` (else stop, write rejection to ledger, exit)
- [ ] Showed the user the proposal + verdict; received explicit approval
- [ ] Invoked `/commit-proposal` with the approved proposal path
- [ ] Verified ledger has new `commit` entry and snapshot exists under `.claude/lineage/versions/<slug>/`
- [ ] Ran any needed verify step (`/verify` or `/healthcheck`) to confirm the change behaves
