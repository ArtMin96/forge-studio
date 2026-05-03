# Self-Evolution

User-facing guide to Forge Studio's self-improvement loop **and** the wire-level protocol that powers it (ledger schema, snapshot paths, operator semantics). For the architectural invariants see [`HARNESS_SPEC.md`](../HARNESS_SPEC.md) §Self-Evolution Protocol.

## What It Is

A closed loop that lets the harness improve itself over time — and lets you reverse any improvement that turns out to be wrong. Four operators over versioned resources:

```
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

## The Loop In Practice

### Typical session

```
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

```
$ /rollback rules.d/40-defensive-reads.txt
  Rolled back rules.d/40-defensive-reads.txt v2 → v1.
  Forward version snapshot saved: /rollback rules.d/40-defensive-reads.txt v2
```

### Inspecting history

```
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
| `evaluator` | Runs the `assess` operator via `/assess-proposal` |
| `workflow` | Owns the `propose` orchestrator, `commit`, `rollback`, reflect skill, router-tune |
| `memory` | Version-aware topic updates (`/remember`) feed the same ledger |
| `diagnostics` | Future: `/entropy-scan` will validate ledger invariants (snapshot existence, propose→assess→commit ordering) |

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

```
.claude/lineage/versions/<resource-slug>/<prev-version>
```

Example: committing `rules.d/25-brevity.txt` from v2 → v3 writes the old contents to `.claude/lineage/versions/rules.d/25-brevity.txt/v2`.

For `env/<VAR>` resources, the snapshot file contains the prior value plus the path to the settings.json key it was read from (so rollback can restore it without guessing).

## Wire-Level Invariants

The formal invariants — append-only ledger, matching propose/assess/commit lineage, snapshot existence, slug-registry enforcement, no-go list — live in [`HARNESS_SPEC.md` §Ledger Invariants and §No-Go List](../HARNESS_SPEC.md#ledger-invariants). Authoritative source; check there before changing protocol expectations.

## Pointers

- [Architectural invariant](../HARNESS_SPEC.md) — §Self-Evolution Protocol
- [Lifecycle diagram](../plugins/workflow/LIFECYCLE.md) — §Self-Evolution Loop (SEPL)
- [Autogenesis paper](https://arxiv.org/abs/2604.15034) — source material
