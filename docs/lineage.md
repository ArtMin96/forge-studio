# Lineage & Self-Evolution Protocol

> Resource registry + append-only ledger that powers the propose → assess → commit → rollback loop. Inspired by *Autogenesis: A Self-Evolving Agent Protocol* (Wentao Zhang, arXiv:2604.15034, Apr 2026).

## Why

Without auditable version history, "self-improvement" becomes indistinguishable from drift. The Autogenesis paper's core insight: separate **what evolves** (the resource substrate) from **how evolution occurs** (the operator loop). Forge Studio adopts the same split.

- **RSPL** (Resource Substrate Protocol Layer) — typed, versioned handles on the things the agent may mutate: rules, skills, hooks, memory topics, env vars.
- **SEPL** (Self Evolution Protocol Layer) — three operators: `propose`, `assess`, `commit`. Plus `rollback` to reverse a commit. Every operator writes a ledger entry.

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

## Operator Semantics

### propose

Emitted when a skill drafts a change. **Does not mutate the resource.** Evidence path points to a markdown proposal artifact in `.claude/lineage/proposals/` describing:

1. Resource + target version
2. Current value (or diff base)
3. Proposed value (or diff)
4. Rationale (linked to trigger)
5. Expected token/behavior impact

### assess

Emitted after adversarial review of a proposal. Evidence path points to a verdict JSON:

```json
{"verdict":"pass|fail|conditional","criteria":{"single_variable":true,"root_cause":true,"honest_impact":true,"no_regression":true},"rationale":"..."}
```

`commit` refuses to run if the most recent entry for the resource is not an `assess` with `verdict: pass`.

### commit

Emitted after user approval. Applies the proposed change, writes the snapshot, logs the entry. If anything fails partway (snapshot write, file replace), the commit is aborted and no ledger entry is written — the ledger never contains partial commits.

### reject

Emitted when the user declines a proposal or assessment fails. Prevents the same proposal from being re-committed without a new `propose` + `assess` cycle.

### rollback

Emitted when reversing a prior commit. Reads the snapshot from `.claude/lineage/versions/<slug>/<target-version>`, restores it, logs the entry. Rollbacks themselves are logged — history is append-only. Rollbacks can only target versions that have snapshots (i.e. the current version cannot roll back to itself).

## Invariants

- Ledger is append-only. No edit or delete.
- Every `commit` has a matching `propose` and `assess` entry earlier in the ledger, same `resource`, same target `version`.
- Every `commit` and `rollback` has a snapshot file on disk — verified by `/entropy-scan`.
- Slugs from the resource registry table are the only legal values for the `resource` field.

## Interaction with Existing Plugins

| Plugin | Role in the loop |
|---|---|
| `traces` | `/trace-evolve` emits proposal drafts (no ledger write) consumed by `/evolve`. |
| `evaluator` | `/assess-proposal` runs the `assess` operator. |
| `workflow` | `/evolve` orchestrates propose→assess→commit. `/commit-proposal`, `/rollback` run the write operators. `/router-tune`, `/reflect` are signal producers. |
| `memory` | `/remember` becomes version-aware. Topic updates snapshot prior version + write ledger entry. |
| `diagnostics` | `/entropy-scan` gains a check: every `commit` has a snapshot file. |

## Non-Goals

- No attempt to execute arbitrary runtime code from the ledger — proposals are markdown, not scripts.
- No auto-commit. Every `commit` requires explicit user approval. `WORKFLOW_EVOLVE_AUTOCOMMIT` exists as an escape hatch but defaults to `0` and should only ever be enabled after the ledger is battle-tested.
- No cross-repo synchronization. The ledger is local to `.claude/` in the user's project.
