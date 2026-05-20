# Code as Agent Harness — Forge Studio S8 Capabilities

Reference: arXiv:2605.18747 — the survey that prompted this work.

---

## What the paper says

An agent harness is the code that wraps a model: it decides what tools the model can reach, what state persists across turns, and what counts as "done." The paper (arXiv:2605.18747) argues the harness must satisfy a triad: *executable* — every claimed behavior runs as a command and produces a verifiable exit code; *inspectable* — internal state is visible on disk without access to model weights; *stateful* — durable facts survive context compaction and session boundaries.

The paper's organizing loop is Plan–Execute–Verify (PEV): plan in isolation, execute with the minimum tool grant, verify against a criterion declared before execution started. Five stages of Agentic Harness Engineering (AHE) expand the V step into a cycle: observe (collect traces), diagnose (localize failure), propose (draft a falsifiable change), evaluate (run the criterion), promote (commit with evidence). The diagnose stage (§3.5.2) found production attribution accuracy of 14–53% when engineers had to localize regressions from telemetry alone — the rest of the time they guessed. Six convergence types (§4.3.2) make the "done" declaration falsifiable: correctness-gated, security-gated, performance-gated, score-based, consensus, and implicit. Implicit — "user judgment" — is valid for short tasks but loses falsifiability across multi-session sprints.

Forge Studio's work adopted eight capabilities from this paper. The rest of this doc tells you which one to reach for and when.

---

## Decision table — which skill, when

| Symptom | Reach for | Cost |
|---|---|---|
| Long session compacted; about to edit a file | `/belief-audit` — compares stored sha256 fingerprints against disk | microseconds per file; one sha256 call per path |
| Sprint declared "done" but no machine-checkable exit criterion exists | Add `convergence:` block to the plan, then `/verify` enforces it | one YAML block in the plan file |
| Regression appeared between two sessions; unclear which change introduced it | `/failure-attribute` — walks last 20 manifest entries, re-runs each verifier_obligation | seconds; reads `.claude/evolution/change_manifest.jsonl` |
| Want to know whether harness quality is improving | `/harness-metrics` — six-row scorecard from existing artifacts | sub-second; reads belief log + manifest |
| About to propose a harness change via `/auto-tune-skill` | The proposal must include a `change_contract:` block; `/assess-proposal` refuses if it is absent | one YAML block in the proposal file |
| Multi-file refactor; single reviewer is a bottleneck | Planner enumerates files → `/dispatch` pools one reviewer per file (cap: 5) + aggregator | proportional to file count |
| Session compacted; post-compact context is missing stack frames or failing test names | `forward-briefing.sh` (PreCompact) emits structured YAML; `post-compact-recovery.sh` (PostCompact) re-injects it | ~1 second on PreCompact |
| Manifest entry was written but `evidence_bundle.checks_run` is empty | Set `MANIFEST_CHECKS_RUN` env var before calling the manifest writer; or backfill via `/change-manifest` | one env-var assignment |

Each row's recommended action is wired today. If a symptom doesn't appear here, check the dedicated doc linked in the "Where to read deeper" section below.

---

## Architecture diagram

Where the eight new hooks and skills slot into the existing harness:

```
UserPromptSubmit
  └─ route-prompt.sh → [simple | pipeline | fan-out | tdd-loop]

PreToolUse (Edit|Write)
  └─ belief-snapshot.sh  →  .claude/state/belief.jsonl  {op:"pre", sha256}
  └─ research-gate.sh    →  block edit if read count < 6

[Edit or Write executes]

PostToolUse (Edit|Write)
  └─ belief-verify.sh    →  .claude/state/belief.jsonl  {op:"post", sha256}
  └─ detect-thrashing.sh

/belief-audit            →  diff stored sha256 vs disk → drift report

PreCompact
  └─ forward-briefing.sh →  .claude/state/forward-briefing.yaml
                              open_failures | recent_edits
                              pending_verifications | belief_snapshots

PostCompact
  └─ post-compact-recovery.sh  →  re-injects briefing as first turn

SEPL loop:
  /evolve → /auto-tune-skill (proposal + change_contract)
          → /assess-proposal (refuses if change_contract absent)
          → /commit-proposal (writes contract to manifest evidence_bundle)
          → /rollback        (consults /failure-attribute for suspect entry)

/dispatch (N ≥ 3 files):
  planner output → [reviewer-1 | reviewer-2 | … | reviewer-N] → aggregator
```

---

## Try it

These three commands run against the repo as-is. No fixtures needed.

**1. Belief-state audit** — shows drift between stored sha256 fingerprints and disk state:

```bash
bash plugins/context-engine/skills/belief-audit/scripts/audit.sh
```

Exit 0 means all tracked files match their last recorded fingerprint. Exit 1 means at least one file has drifted — the output table shows which paths and how the hashes differ. If no snapshots exist yet (fresh clone, no edits made), the script reports "no snapshots recorded yet."

**2. Harness metrics scorecard** — six quality dimensions from existing artifacts:

```bash
bash plugins/forge-meta/skills/harness-metrics/scripts/score.sh
```

Prints a six-row Markdown table. Dimensions sourced from `.claude/evolution/change_manifest.jsonl` and `.claude/state/belief.jsonl`. Rows show `n/a` (not `NaN` or a crash) when the source artifact is absent or traces are disabled.

**3. Convergence check** — confirm the plan that shipped this work exits 0:

```bash
bash plugins/workflow/skills/convergence-check/scripts/check.sh .claude/plans/s8-code-as-harness.md
```

Parses the `convergence:` block from the plan, runs the criterion command, and prints whether it is met. Exit 0 means the criterion passed. This is the same check `/verify` runs automatically when it detects a `convergence:` block in the active plan.

---

## Roadmap (not in this release)

Capabilities the paper covers that Forge Studio deferred:

- **HITL approval persistence** (§5.2.5) — blocking approval gates with a durable "approved by" record. Separate sprint; depends on permission tiers being formalized first.
- **Multimodal feedback** (§5.2.6) — vision-model review of rendered output. Not applicable for a text-only shell-and-markdown marketplace.
- **max_iterations enforcement** — the `convergence.max_iterations` field is captured in plan frontmatter but not yet used to abort a stuck agent loop. The field is advisory this release.
- **Belief-audit for non-file state** — network responses, MCP server cache, environment variables. File-system only in this release; session state that doesn't land on disk is outside audit scope.

---

## Where to read deeper

One line per capability. No re-explanation here — follow the link.

| Capability | Deeper doc |
|---|---|
| Belief-state drift | [docs/belief-audit.md](belief-audit.md) |
| Transactional manifest | [docs/transactional-manifest.md](transactional-manifest.md) |
| Convergence criteria | [docs/convergence.md](convergence.md) |
| Harness metrics | [docs/harness-metrics.md](harness-metrics.md) |
| Compaction briefing | [docs/compaction-briefing.md](compaction-briefing.md) |
