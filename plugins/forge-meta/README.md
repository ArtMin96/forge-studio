# forge-meta

**What this is**: forge-meta enforces a structural boundary between Forge Studio's user-facing surface (workflow, agents, evaluator) and its self-evolution loop. The AHE paper (2604.25850 p.5) calls this the *controllability invariant* — a self-evolving harness must not be able to disable its own oversight (verifier, healthcheck, drift-counter). forge-meta holds that line.

## What "self-evolution" means here

Not training the model. The harness writes proposals to mutate its own skills based on observed eval results. Concretely: the mutator reads the current SKILL.md for a target skill together with its matching `evals/evals.json`, proposes a candidate skill body, scores it on pass-rate and token cost, and writes a proposal file you review before anything is applied. The skill `/auto-tune-skill` implements this loop — currently as a stub that emits the baseline proposal; the autonomous mutation + Pareto scoring outer loop is the documented next step.

The evolution artifacts (change ledger, session digests, proposal files) are all append-only or write-new. Nothing in the loop can silently modify existing skills — only a human applying a reviewed proposal does that.

## Skills

| Skill | Command | What it does | When to use |
|-------|---------|-------------|-------------|
| change-manifest | `/change-manifest` | Appends one structured entry to `.claude/evolution/change_manifest.jsonl`. Each entry captures type, description, affected files, failure pattern, predicted fixes, risk tasks, and constraint level (AHE p.20 schema) | When a meaningful change was made and the hook could not auto-detect it; normally fires automatically via `manifest-writer.sh`. Direct invoke: `bash plugins/forge-meta/skills/change-manifest/scripts/append-manifest.sh --type <t> --description <d>` |
| evolution-history | `/evolution-history` | Renders `change_manifest.jsonl` as a reverse-chronological Markdown timeline grouped by date, capped at the last 200 entries. Skips malformed lines silently | After a sprint or series of generator passes when you want a human-readable audit trail of what changed and what agents touched which files |
| session-digest | `/session-digest [--session-id <id>]` | Produces a ≤10KB rollup at `.claude/sessions/<session-id>-digest.md` with three sections: **Component** (which plugins fired), **Experience** (per-task outcomes from the manifest filtered by session), **Decision** (manifest deltas, predicted_fixes / risk_tasks aggregated). Also fires automatically on SessionEnd | After any multi-agent run for a compact summary of the session's evolution-relevant state |
| auto-tune-skill | `/auto-tune-skill <plugin>:<skill-id>` | **Stub.** Produces a baseline proposal at `.claude/proposals/<plugin>-<skill>-<timestamp>.md` from the existing SKILL.md. The autonomous mutation + Pareto scoring outer loop (Meta-Harness Algorithm 1 — iterate skill bodies through pass-rate × token-cost Pareto search) is documented in the skill body as future work. Env: `FORGE_AUTO_TUNE_ITERS` (default 5 iterations, no-op in stub mode) | When a skill's eval pass rate is below target or its `when_to_use` keeps misfiring and you want a starting proposal to review |

## Hooks

| Hook | Event | Matcher | When it fires | What it does |
|------|-------|---------|--------------|-------------|
| `manifest-writer.sh` | `SubagentStop` | (none — fires after every subagent) | After each subagent stops | Auto-appends a change-manifest entry when there is a signal worth recording: either the agent emitted a `change_manifest:` JSON marker on stdout, or `git diff` shows uncommitted changes from the last 30 minutes. Silent when neither condition holds — does not pollute the ledger with empty entries. Dedupes per `(session_id, git-tree-hash)` so a planner→generator→reviewer chain with one logical change records one entry, not three. Override: `FORGE_REMINDER_FORCE=1` bypasses dedup and always appends |
| `session-end-digest.sh` | `SessionEnd` | (none) | At the end of every session | Invokes the `session-digest` skill's `digest.sh` script with the current session ID. Observability only — always exits 0 |
| `pre-edit-guard.sh` | `PreToolUse` | `Edit\|Write` | Before any file edit | The controllability boundary. Fires only when `FORGE_META_EVOLVE=1` is set (the marker that an edit originates from the evolution loop, not a human). When active, parses `POLICY.md` at runtime to build the protected-path list (no hard-coded copy to keep in sync); falls back to a hard-coded list with a stderr warning if `POLICY.md` is unreadable. When `FORGE_META_EVOLVE` is unset, the hook exits 0 silently — humans can edit any path without restriction |

## POLICY.md

The list of protected paths is in [`POLICY.md`](POLICY.md). `pre-edit-guard.sh` parses this file at runtime — adding a path to `POLICY.md` is sufficient; no separate hook edit required. The currently protected paths are:

- `plugins/evaluator/skills/verify/` — the evidence gate
- `plugins/evaluator/skills/healthcheck/` — the health check skill
- `plugins/diagnostics/skills/entropy-scan/scripts/count.sh` — the drift counter
- `CLAUDE.md` — project-level behavioral steering
- `HARNESS_SPEC.md` — harness invariants
- `plugins/forge-meta/POLICY.md` — this file itself

The list is intentionally short. Expanding it requires a human edit — a deliberate friction point.

## How to use it

**View evolution history:**
```
/evolution-history
```

**Get a session rollup:**
```
/session-digest
```
Or just wait — `session-end-digest.sh` fires automatically at session end.

**Manually log a change the hook missed:**
```bash
bash plugins/forge-meta/skills/change-manifest/scripts/append-manifest.sh \
  --type hook-edit \
  --description "added X to doom-loop.sh" \
  --files "plugins/diagnostics/hooks/doom-loop.sh"
```

**Tune a skill (stub mode — produces a baseline proposal):**
```
/auto-tune-skill diagnostics:entropy-scan
```

## Disable

`/plugin disable forge-meta@forge-studio`. Removes the pre-edit guard and evolution-artifact hooks. The evaluation gates in `evaluator` remain active. Evolution artifacts already written to `.claude/evolution/` are not touched.
