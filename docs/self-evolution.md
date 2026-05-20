# Self-Evolution

User-facing guide to Forge Studio's self-improvement loop **and** the wire-level protocol that powers it (ledger schema, snapshot paths, operator semantics). For the architectural invariants see [`HARNESS_SPEC.md`](../HARNESS_SPEC.md) §Self-Evolution Protocol.

## What It Is

A closed loop that lets the harness improve itself over time — and lets you reverse any improvement that turns out to be wrong. Four operators over versioned resources:

```text
propose ─► assess ─► commit ─► (rollback, any time)
```

Every operator writes a line to `.claude/lineage/ledger.jsonl`. The ledger is append-only. Rollbacks are themselves logged. No mutation is silent; no mutation is irreversible.

## Why It Exists

Without auditable version history, "self-improvement" is indistinguishable from drift. Forge Studio had the *sense* half of the loop (traces, `/trace-evolve`) but no *commit* half — proposals evaporated at the end of a session instead of compounding.

The Autogenesis paper (*Autogenesis: A Self-Evolving Agent Protocol*, Wentao Zhang, arXiv:2604.15034, Apr 2026) frames this gap cleanly: separate **what evolves** (the resource substrate) from **how evolution occurs** (the operator loop). Forge Studio adopts the same split.

Related work that shaped the concrete shape of the loop:
- *Generative Agents* — reflection-on-memory pattern; ablation study shows removing reflection degenerates behavior within 48 simulated hours
- *MUSE* — Plan-Execute-**Reflect-Memorize** experience loop
- *Memory in the Age of AI Agents* surveys — three-stage evolution (Storage → Reflection → Experience)

## What Can Evolve

The loop only touches resources in the registry. Anything else is out of reach.

| Kind | Example |
|---|---|
| Behavioral rule | `rules.d/25-brevity.txt` |
| Skill | `skills/workflow/tdd-loop` |
| Hook script | `hooks/workflow/route-prompt.sh` |
| Memory topic | `memory/topics/router-thresholds` |
| Config var | `env/WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` |

Full slug table below in §Resource Registry. Adding a kind requires editing the registry deliberately — the loop cannot grant itself new powers.

## The Four Operators

### propose

A skill drafts a change. Writes a markdown artifact to `.claude/lineage/proposals/<YYMMDD>-<slug>-v<N>.md` with five sections: resource, current, proposed, rationale, impact. **Does not mutate anything.**

Current proposers:
- `/trace-evolve` (traces) — surfaces clusters of failures, one proposal per cluster
- `/router-tune` (workflow) — analyses `/tmp/claude-router-*/classifications.jsonl` for threshold / regex tweaks
- `/remember` (memory) — implicit proposer for `memory/topics/<slug>` updates

### assess

`/assess-proposal` (evaluator) runs in a forked `reviewer` subagent and grades against four criteria:

1. **Single-variable change** — one resource, one dimension
2. **Root cause, not symptom** — does the proposal target the underlying mechanism?
3. **Honest impact** — token / behavior cost estimate holds up to scrutiny
4. **No regression** — no conflict with existing rules / callers / assumptions

Verdict: `pass` / `fail` / `conditional`. Written to `.claude/lineage/verdicts/<basename>.json`. `commit` refuses to run without a preceding `assess: pass`.

### commit

`/commit-proposal` (workflow) applies the change. Always asks for user approval first (except for `env/<VAR>` numeric deltas ≤±20% if `WORKFLOW_EVOLVE_AUTOCOMMIT=1`). Before mutating, snapshots the prior contents to `.claude/lineage/versions/<slug>/<prev-version>` so rollback is guaranteed.

Failure modes are safe by construction:
- Snapshot write fails → abort, no ledger entry, no mutation
- File write fails after snapshot → restore from snapshot, abort, no ledger entry

### rollback

`/rollback <slug> [version]` (workflow) reverses a commit. Snapshots the *current* version first (so a subsequent `/rollback` can roll forward), then restores the target. Rollbacks are themselves logged — the ledger is never rewritten, only appended.

Before asking the user which version to target, `/rollback` invokes `/failure-attribute` to suggest an evidence-grounded default. If the attribution finds a `primary_suspect` in the change manifest — either an entry with no evidence bundle or one whose verifier obligations fail today — it presents that entry as the suggested rollback target. The user confirms or overrides; rollback never executes automatically. If the manifest is absent or attribution finds no suspects, the prompt falls back to asking the user directly.

## The Loop In Practice

### Typical session

```console
$ /trace-evolve           # mine last 2 weeks, produce cluster report
$ /evolve trace-evolve    # convert clusters → proposals, assess each, ask to commit
  Proposal 1/3: rules.d/40-defensive-reads.txt v1 → v2
    Trigger: premature-edit cluster (63% of failures per IDE-Bench)
    Impact:  +38 chars/message, ~3 proposals/session regressive
    Verdict: PASS
    Diff:
      +Before calling Edit on a file, confirm a Read in this session.
    Approve commit? (y/N)
  y
    Committed rules.d/40-defensive-reads.txt v1 → v2.
    Rollback: /rollback rules.d/40-defensive-reads.txt v1
  Proposal 2/3: env/WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD v2 → v3
    ...
```

### If it goes wrong

```console
$ /rollback rules.d/40-defensive-reads.txt
  Rolled back rules.d/40-defensive-reads.txt v2 → v1.
  Forward version snapshot saved: /rollback rules.d/40-defensive-reads.txt v2
```

### Inspecting history

```console
$ cat .claude/lineage/ledger.jsonl | jq -c 'select(.resource | startswith("rules.d/"))'
$ ls .claude/lineage/versions/rules.d/40-defensive-reads.txt/
  v1  v2
```

## Reflect-Memorize: The Sibling Loop

The propose→assess→commit loop handles *harness* self-improvement. A second, lighter loop handles *experience* capture: `/reflect` (workflow).

Triggered automatically at the end of `/tdd-loop` Phase 3 when `WORKFLOW_TDD_REFLECT=1`, or manually any time. Writes a three-line insight (worked / surprised / watch) to a memory topic. Deduplicates against existing topics — silent when the insight adds nothing.

Why both loops? Harness evolution needs the full assess + commit ceremony because it changes how the agent behaves for everyone. Reflection is a note to future self — the memory topic is the commit, the topic's version history is the audit trail, and the cost of a bad insight is one stale memory line, not a behavioral regression.

## Guardrails

- **User approval on every commit** of a file resource. No exceptions.
- **Single-variable change rule** enforced at `/assess-proposal`. Multi-resource proposals are split or rejected.
- **Snapshots guaranteed** before mutation. If the snapshot can't be written, the mutation never runs.
- **Append-only ledger**. Corruption detection is O(N) — no state to tamper with.
- **No auto-commit for file resources**. `WORKFLOW_EVOLVE_AUTOCOMMIT` is numeric-env-only, defaults off, and should stay off until the ledger has been battle-tested on your workload.

## Non-Goals

- Not a learning loop in the ML sense — no gradients, no fine-tuning. Evolution is purely textual: rules, skills, hooks, topics, config values.
- Not cross-repo. The ledger lives in `.claude/` in the user's project.
- Not autonomous. The agent proposes; the user approves. Autonomy is behind one opt-in env var and restricted to numeric deltas.
- Not a replacement for git. Git tracks code change history; the ledger tracks harness change history. Different scopes, different tools.

## Related Plugins

| Plugin | Role |
|---|---|
| `traces` | Proposal source — `/trace-evolve` mines failure clusters |
| `evaluator` | Runs the `assess` operator via `/assess-proposal`; `/prediction-audit` joins predictions to traces |
| `workflow` | Owns the `propose` orchestrator, `commit`, `rollback`, reflect skill, router-tune |
| `memory` | Version-aware topic updates (`/remember`) feed the same ledger |
| `diagnostics` | Future: `/entropy-scan` will validate ledger invariants (snapshot existence, propose→assess→commit ordering) |

## Predicted Impact (structured)

Proposals may include an optional `## Predicted Impact (structured)` section with three fields. When present, `/assess-proposal` criterion #3 verifies each field independently; absent fields fall back to the free-form impact check.

| Field | Type | Purpose |
|---|---|---|
| `predicted_token_delta_per_session` | integer (chars) | Net delta per typical session, accounting for re-injection frequency |
| `predicted_failure_clusters_resolved` | list of cluster ids or `none` | Which `/trace-evolve` clusters this proposal addresses |
| `predicted_negative_effects` | list of one-liners or `none` | Honest catalog of small downsides; `none` is acceptable when there really are none |

After commits land, `/prediction-audit` joins the structured predictions against post-commit traces to compute per-resource prediction error. The mechanism mirrors the *paired predictions verified against outcomes* observability principle from *Agentic Harness Engineering* (arXiv:2604.25850). Predictions that are systematically off feed back into `/trace-evolve` for harness-level recalibration.

The structured schema is **opt-in and additive** — pre-existing proposals continue to validate. New proposals are encouraged to include it; runtime tooling (`/evolve`, `/router-tune`, `/remember`) can populate it automatically as it evolves.

## Resource Registry

Everything the self-evolution loop can touch must resolve to a stable slug.

| Resource kind | Slug format | Example |
|---|---|---|
| Behavioral rule | `rules.d/<filename>` | `rules.d/25-brevity.txt` |
| Skill | `skills/<plugin>/<skill-name>` | `skills/workflow/tdd-loop` |
| Hook script | `hooks/<plugin>/<script>` | `hooks/workflow/route-prompt.sh` |
| Memory topic | `memory/topics/<slug>` | `memory/topics/router-thresholds` |
| Config var | `env/<VAR>` | `env/WORKFLOW_ROUTER_CONFIDENCE_THRESHOLD` |

Resources not in this list are outside the loop's reach. Adding a new kind requires a ledger entry of its own (`operator: register-kind`).

## Ledger Format

Path: `.claude/lineage/ledger.jsonl` (append-only, one JSON object per line).

```json
{"ts":"2026-04-20T10:15:00Z","operator":"propose","resource":"rules.d/25-brevity.txt","version":"v3","prev":"v2","trigger":"trace-evolve:cluster-thrashing-0420","evidence":".claude/lineage/proposals/0420-brevity-v3.md","actor":"workflow:/evolve"}
```

| Field | Type | Required | Meaning |
|---|---|---|---|
| `ts` | ISO 8601 UTC | yes | Event timestamp |
| `operator` | `propose \| assess \| commit \| reject \| rollback` | yes | Which SEPL step |
| `resource` | string (slug from table above) | yes | What this entry is about |
| `version` | string (`v<N>` or `vN-assess` etc.) | yes | The version this entry produced |
| `prev` | string | on `commit` and `rollback` | The version being replaced |
| `trigger` | string | recommended | What surfaced the proposal (trace cluster id, user request, etc.) |
| `evidence` | relative path | yes | Artifact supporting the entry (proposal, verdict, diff) |
| `actor` | string | yes | Which skill/hook wrote the entry (`workflow:/evolve`, `evaluator:/assess-proposal`, etc.) |

## Version Snapshots

On `commit`, the **previous** file contents are snapshotted to:

```text
.claude/lineage/versions/<resource-slug>/<prev-version>
```

Example: committing `rules.d/25-brevity.txt` from v2 → v3 writes the old contents to `.claude/lineage/versions/rules.d/25-brevity.txt/v2`.

For `env/<VAR>` resources, the snapshot file contains the prior value plus the path to the settings.json key it was read from (so rollback can restore it without guessing).

## Wire-Level Invariants

The formal invariants — append-only ledger, matching propose/assess/commit lineage, snapshot existence, slug-registry enforcement, no-go list — live in [`HARNESS_SPEC.md` §Ledger Invariants and §No-Go List](../HARNESS_SPEC.md#ledger-invariants). Authoritative source; check there before changing protocol expectations.

## Change Contracts

arXiv:2605.18747 §5.2.3 argues that a harness mutation should be treated like a code change to a safety-critical runtime. Every proposed edit should carry a *change contract* specifying: which component is modified, which failure mode it targets, what improvement it predicts, which invariants it must preserve, what evaluation can falsify it, and how it can be rolled back.

Forge Studio enforces this end-to-end across three SEPL operators:

| Stage | What happens |
|---|---|
| `/auto-tune-skill` (propose) | Writes a `## Change Contract` YAML block at the top of every proposal file |
| `/assess-proposal` (assess) | Refuses any proposal missing `change_contract:` — quotes the missing field name verbatim in the rejection |
| `/commit-proposal` (commit) | Copies the contract into `evidence_bundle.contract` in the change manifest |

### Contract Fields

```yaml
change_contract:
  component: "<plugin>/<skill-or-hook>"
  failure_mode_targeted: "<observable failure — what the user actually saw>"
  predicted_improvement: "<falsifiable before→after metric>"
  invariants_preserved:
    - "<POLICY.md invariant ref or free-form invariant statement>"
  falsifiable_by: "<literal shell command containing bash/python3/grep/test>"
  rollback_steps:
    - "git revert <sha>"
```

Each field serves a specific audit purpose:

- `component` — anchors attribution: if the change causes a regression, this names where to look.
- `failure_mode_targeted` — prevents cargo-cult proposals that address symptoms rather than root causes.
- `predicted_improvement` — provides the falsifiable claim that `/prediction-audit` checks post-commit.
- `invariants_preserved` — lists what the change must not break; references `plugins/forge-meta/POLICY.md` when applicable, or states a free-form invariant when no policy line matches. Either form is accepted.
- `falsifiable_by` — the literal shell command that produces evidence of improvement. `/assess-proposal` checks that it contains a verb token (`bash`, `python3`, `grep`, `test`, or `jq`) so it's a real command, not prose.
- `rollback_steps` — ordered steps to reverse the change; the first step is typically `git revert <sha>` after commit lands.

### Worked Example: Proposal Lifecycle

**Step 1 — /auto-tune-skill proposes**

`/auto-tune-skill memory:recall` completes three iterations and selects a Pareto-best candidate. It writes `.claude/proposals/memory-recall-20260520T093000Z.md` beginning with:

```
proposal_status: unreviewed
iteration_count: 3
pareto_pass_rate: 0.90
pareto_token_cost: 1200

## Change Contract

change_contract:
  component: "memory/recall"
  failure_mode_targeted: "recall returns stale topic after session restore — evals fail with wrong-context assertions"
  predicted_improvement: "pass_rate rises from 0.60 to ≥0.85 on memory/recall/evals/evals.json"
  invariants_preserved:
    - "POLICY.md: auto-tune-skill never mutates the original SKILL.md"
  falsifiable_by: "bash plugins/forge-meta/skills/auto-tune-skill/scripts/score-candidate.sh .claude/proposals/memory-recall-20260520T093000Z.md memory:recall"
  rollback_steps:
    - "git revert HEAD"
```

**Step 2 — /assess-proposal checks**

`/assess-proposal .claude/proposals/memory-recall-20260520T093000Z.md`:

1. Finds `change_contract:` in the file — contract check passes.
2. Verifies all six fields are present and non-empty; `falsifiable_by` contains `bash` — valid.
3. Runs the four SEPL criteria (single-variable, root-cause, honest-impact, no-regression).
4. Emits verdict `pass` with `evidence_bundle.contract` present.

If the proposal had no `## Change Contract` section, assess-proposal would emit:

```json
{
  "verdict": "fail",
  "blockers": ["change_contract: block missing — required field not found in proposal"]
}
```

**Step 3 — /commit-proposal records**

After user approval, `/commit-proposal` applies the change and writes to `.claude/evolution/change_manifest.jsonl`:

```json
{
  "id": "chg-1748000000-a1b2c3",
  "iso_timestamp": "2026-05-20T09:35:00Z",
  "agent_type": "workflow:/commit-proposal",
  "type": "manifest-entry",
  "description": "commit memory/recall v1 → v2",
  "evidence_bundle": {
    "checks_run": ["sepl-commit"],
    "contract": {
      "component": "memory/recall",
      "failure_mode_targeted": "recall returns stale topic after session restore — evals fail with wrong-context assertions",
      "predicted_improvement": "pass_rate rises from 0.60 to ≥0.85 on memory/recall/evals/evals.json",
      "invariants_preserved": ["POLICY.md: auto-tune-skill never mutates the original SKILL.md"],
      "falsifiable_by": "bash plugins/forge-meta/skills/auto-tune-skill/scripts/score-candidate.sh ...",
      "rollback_steps": ["git revert HEAD"]
    }
  },
  "rollback_handle": "git revert HEAD"
}
```

The contract is now durable in the manifest. Future `/failure-attribute` runs can re-run `falsifiable_by` and compare against the `predicted_improvement` claim to determine whether the change held up.

## Evidence-Bundle Format

Every entry in `.claude/evolution/change_manifest.jsonl` can carry an `evidence_bundle` sub-object. The bundle answers the question: "what did the agent verify before declaring this change done?" Without it, attribution tooling has no signal — it can see that a change landed, but cannot tell whether it was checked. The pattern follows arXiv:2605.18747 §5.2.1, which argues every accepted action should ship with the checks run, the assumptions preserved, the untested regions, and the remaining risks.

### Fields

| Field | Meaning |
|---|---|
| `checks_run` | List of checks that passed at write time (e.g. `json-parse`, `hook-exit-code`). At minimum one entry here shows something was verified. |
| `assumptions_preserved` | Subset of `assumptions` that were actively checked before writing. Crossing off assumptions before commit, not after. |
| `untested_regions` | Areas changed but not tested. Explicit `[]` means fully tested; absent means unknown — treated as suspect by `/failure-attribute`. |
| `remaining_risks` | Risks the agent could not rule out. Surfaced verbatim by `/session-digest` so the next agent can pick them up. |

### Worked example

A generator finishes editing `README.md` to update hook counts. Here is what each field captures:

```json
{
  "id": "chg-1747987210-c1d2e3",
  "iso_timestamp": "2026-05-20T10:05:00Z",
  "session_id": "s-abc",
  "agent_type": "generator",
  "type": "doc-edit",
  "description": "update hook count in README header to match count.sh output",
  "read_set": ["README.md"],
  "write_set": ["README.md"],
  "assumptions": ["count.sh output is stable across concurrent calls"],
  "verifier_obligations": ["bash plugins/diagnostics/skills/entropy-scan/scripts/count.sh ."],
  "rollback_handle": "git revert HEAD",
  "evidence_bundle": {
    "checks_run": ["count.sh-output-matches-header", "json-parse"],
    "assumptions_preserved": ["count.sh output is stable across concurrent calls"],
    "untested_regions": [],
    "remaining_risks": []
  }
}
```

- `read_set: ["README.md"]` — the agent Read the file before editing. Stale-read attribution compares this against the file's sha256 at read time.
- `assumptions` + `assumptions_preserved` — the agent declared one assumption and then verified it before writing. Both lists match, so the assumption was not left hanging.
- `untested_regions: []` — explicit empty list. Signals full coverage of the touched region, not just "forgot to fill this in."
- `remaining_risks: []` — same: explicit empty. `/session-digest` sees no residual risks to surface.

### How `/session-digest` aggregates them

At session end, `digest.sh` scans all entries for this session and:
1. Sums `len(assumptions)` across entries → reports `Total assumptions declared: N`.
2. Collects all non-empty `remaining_risks` lists → lists them verbatim under `Remaining risks`.

This lets the next session's agent start with a clear view of what the previous session left unresolved.

See [`docs/transactional-manifest.md`](transactional-manifest.md) for the full field reference and contributor guidance.

## Pointers

- [Architectural invariant](../HARNESS_SPEC.md) — §Self-Evolution Protocol
- [Lifecycle diagram](../plugins/workflow/LIFECYCLE.md) — §Self-Evolution Loop (SEPL)
- [Autogenesis paper](https://arxiv.org/abs/2604.15034) — source material
- [Transactional manifest guide](transactional-manifest.md) — contributor reference for writing manifest entries
